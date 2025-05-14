from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
import requests
import json
import logging
import pymongo
from datetime import datetime
from bson import json_util

from backend.auth.dependencies import get_current_user
from backend.database import collections

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Chat models
class ChatMessage(BaseModel):
    text: str
    isUser: bool

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = Field(default_factory=list)

# Gemini API configuration
GEMINI_API_KEY = "AIzaSyAVNc67HMNDH4rjZCi55DteVXOWwp8OZP4"
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

# Create the router
chat_router = APIRouter()

def serialize_docs(docs):
    """Helper to serialize MongoDB documents, handling ObjectId."""
    # Use json_util to handle BSON types like ObjectId
    return json.loads(json_util.dumps(docs))

@chat_router.post("/chat/ai", tags=["Chat"])
async def chat_ai(
    payload: ChatRequest,
    current_user: dict = Depends(get_current_user)
):
    """Handles chat requests, interacts with DB and Gemini."""
    try:
        # 1. Fetch relevant data
        user_email = current_user.get("email")
        docs = list(collections["Persona_AR"].find().sort("date", pymongo.DESCENDING).limit(5))
        serialized_docs = serialize_docs(docs)
        context = f"Recent store activity data:\n{json.dumps(serialized_docs, indent=2)}\n"
        context += f"User info: email={user_email}, name={current_user.get('full_name')}\n"

        # 2. Construct the prompt for Gemini, including history
        system_prompt = """
        # StoreSense AI Assistant

        Eres StoreSense AI, un asistente inteligente especializado para la aplicación StoreSense, un sistema avanzado de análisis de comportamiento de clientes en tiendas físicas.

        ## Sobre StoreSense
        StoreSense utiliza cámaras con análisis facial para recopilar datos demográficos anónimos de los clientes (edad, género) y sus emociones mientras interactúan con diferentes categorías de productos. Esto ayuda a los gerentes de tiendas a entender mejor el comportamiento del consumidor y optimizar la disposición de productos.

        ## Tus capacidades:
        1. Analizar y explicar datos de interacción de clientes con productos
        2. Interpretar estadísticas sobre demografía de clientes (distribución por género y edad)
        3. Explicar patrones emocionales de los clientes frente a distintas categorías
        4. Proporcionar información sobre horas pico de visita
        5. Sugerir estrategias de merchandising basadas en datos
        6. Ayudar con la configuración de cámaras y categorías de productos

        ## Funcionalidades clave de StoreSense:
        - **Análisis demográfico**: Captura información sobre edad y género de los visitantes
        - **Reconocimiento emocional**: Detecta emociones principales (felicidad, tristeza, neutralidad, etc.)
        - **Mapeo de categorías**: Asocia reacciones a categorías específicas de productos
        - **Estadísticas temporales**: Análisis por hora, día, semana y mes
        - **Panel administrativo**: Para gestionar usuarios, cámaras y categorías

        ## Estructura de datos:
        - Persona_AR: Registro de interacciones de clientes (id_camara, categoria_producto, género, edad, emoción)
        - Tipo_Producto_Zona_Camara: Asociación entre cámaras y tipos de productos
        - Tipo_Producto: Clasificación de productos por categoría
        - Estadísticas: Diversos documentos con análisis estadísticos de los datos capturados

        ## Resumen del contexto actual:
        {data_context}

        Utiliza toda esta información para ayudar al usuario con sus consultas. Mantén un tono profesional pero amigable.
        Si te preguntan por datos que no tienes disponibles en el contexto, puedes indicarlo y sugerir qué información sería útil.
        """.format(data_context=context)

        # Use Gemini message format
        gemini_history = []
        # Add system prompt if history is empty or as the first message
        if not payload.history:
             gemini_history.append({"role": "user", "parts": [{"text": system_prompt}]})
             gemini_history.append({"role": "model", "parts": [{"text": "¡Hola! Soy StoreSense AI. ¿En qué puedo ayudarte hoy con los datos de la tienda?"}]})

        # Convert history format
        for msg in payload.history:
            role = "user" if msg.isUser else "model"
            gemini_history.append({"role": role, "parts": [{"text": msg.text}]})

        # Add the new user message
        gemini_history.append({"role": "user", "parts": [{"text": payload.message}]})

        # 3. Call the Gemini API
        api_payload = {
            "contents": gemini_history,
             "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 500,
            }
        }
        
        params = {"key": GEMINI_API_KEY}
        headers = {"Content-Type": "application/json"}

        response = requests.post(GEMINI_API_URL, params=params, headers=headers, json=api_payload)
        response.raise_for_status()

        data = response.json()

        # Extract the reply
        ai_reply = "Lo siento, no pude procesar la respuesta del asistente."
        candidates = data.get("candidates")
        if candidates and isinstance(candidates, list) and len(candidates) > 0:
            content = candidates[0].get("content")
            if content and isinstance(content, dict):
                parts = content.get("parts")
                if parts and isinstance(parts, list) and len(parts) > 0:
                    text = parts[0].get("text")
                    if text and isinstance(text, str):
                        ai_reply = text

        # Check if the response might be blocked due to safety settings
        if not data.get("candidates") and data.get("promptFeedback"):
             block_reason = data["promptFeedback"].get("blockReason")
             if block_reason:
                 ai_reply = f"Mi respuesta fue bloqueada debido a: {block_reason}. Por favor, reformula tu pregunta."
                 logger.warning(f"Gemini response blocked: {block_reason}")
             else:
                 logger.error(f"Gemini response missing candidates, promptFeedback: {data.get('promptFeedback')}")
        # Handle other potential errors
        elif not data.get("candidates") and data.get("error"):
            error_details = data["error"].get("message", "Unknown error")
            ai_reply = f"Error de la API Gemini: {error_details}"
            logger.error(f"Gemini API error: {data['error']}")

        return {"reply": ai_reply.strip()}

    except requests.exceptions.RequestException as e:
        logger.error(f"Error calling Gemini API: {e}")
        status_code = 502
        detail = f"Error communicating with AI service: {e}"
        if e.response is not None:
             status_code = e.response.status_code
             try:
                 error_data = e.response.json()
                 detail = error_data.get('message', str(e))
                 if status_code == 400 and "API key not valid" in detail:
                      detail = "API key de Gemini no válida. Verifica la clave en el backend."
                      logger.error("Invalid Gemini API Key detected.")
             except json.JSONDecodeError:
                 detail = e.response.text
             logger.error(f"Gemini API Request failed: Status {status_code}, Detail: {detail}")
        raise HTTPException(status_code=status_code, detail=detail)

    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Unexpected error in chat_ai: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error in chat AI: {str(e)}") 