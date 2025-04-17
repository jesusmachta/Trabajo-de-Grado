from backend.statistics.apis.categories_api import get_categories
from backend.statistics.apis.update_category_api import update_category
from backend.statistics.apis.update_category_api import router as update_category_router
# Remove import for cameras_router
# from backend.routes.cameras import router as cameras_router 

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, Path, Body
from pydantic import BaseModel, EmailStr
from backend.aws import analyze_image, upload_image_to_s3
from datetime import datetime, timedelta
from backend.database import collections
import pymongo
import os
import io
import logging
import json
import numpy as np
from PIL import Image
import base64
import cv2
from typing import List, Optional, Dict, Any # Added Dict, Any
from bson import ObjectId # Added ObjectId import
from pytz import timezone
from backend.statistics.peak_hours import get_peak_hours
from backend.statistics.least_busy_hours import get_least_busy_hours
from backend.statistics.most_busy_day import get_most_busy_day
from backend.statistics.least_busy_day import get_least_busy_day
from backend.statistics.least_visited_category import get_least_visited_category
from backend.statistics.most_visited_category import get_most_visited_category
from backend.statistics.emotion_percentage_by_category import get_emotion_percentage_by_category
from backend.statistics.most_frequent_emotions import get_most_frequent_emotions
from backend.statistics.age_distribution import get_age_distribution
from backend.statistics.gender_distribution import get_gender_distribution
from backend.statistics.most_visited_category_historical import get_most_visited_category_historical
from backend.statistics.least_visited_category_historical import get_least_visited_category_historical
from backend.statistics.emotion_comparison import get_emotion_comparison
from backend.statistics.preferred_category_by_gender import get_preferred_category_by_gender
from backend.statistics.top_successful_categories import get_top_successful_categories
from backend.statistics.emotional_differences_by_category import get_emotional_differences_by_category
from backend.statistics.age_gender_distribution_by_category import get_age_gender_distribution_by_category
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
import bcrypt
import jwt
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm


router = APIRouter()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ruta al directorio de archivos estáticos de Flutter web
# Adjusted path to work from within routes.py
FLUTTER_WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend", "build", "web")
# Debug: verificar la existencia del directorio
print(f"FLUTTER_WEB_DIR: {FLUTTER_WEB_DIR}")
print(f"Directory exists: {os.path.exists(FLUTTER_WEB_DIR)}")

# JWT settings
SECRET_KEY = "d5ce1e8ca2d3c30ba1c6bfd87fb14943f7e75dbea2d33ca4cf54de94cb906add"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/login")

class ImagePayload(BaseModel):
    image_base64: str
    id_camara: int

# User models
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = "user"  # default role

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    email: str
    full_name: str
    role: str

def get_next_sequence_value(sequence_name):
    try:
        sequence_document = collections['counters'].find_one_and_update(
            {"_id": sequence_name},
            {"$inc": {"seq": 1}},
            return_document=pymongo.ReturnDocument.AFTER
        )
        if sequence_document is None:
            raise Exception("Sequence document not found")
        return sequence_document["seq"]
    except Exception as e:
        logger.error(f"Error al obtener el siguiente valor de secuencia: {e}")
        raise HTTPException(status_code=500, detail=f"Error al obtener el siguiente valor de secuencia: {e}")

def initialize_routes(app):
    # Incluir rutas API
    app.include_router(router, prefix="/api")
    app.include_router(update_category_router, prefix="/api")
    # Remove including camera router as its routes are now part of the main router
    # app.include_router(cameras_router, prefix="/api", tags=["Cameras"]) 
    
    # Verificar si el directorio de Flutter web existe
    flutter_web_exists = os.path.exists(FLUTTER_WEB_DIR) and os.path.isdir(FLUTTER_WEB_DIR)
    
    # Montar los archivos estáticos solo si existen
    if flutter_web_exists:
        try:
            if os.path.exists(os.path.join(FLUTTER_WEB_DIR, "assets")):
                app.mount("/assets", StaticFiles(directory=os.path.join(FLUTTER_WEB_DIR, "assets")), name="assets")
            
            # Montar todos los archivos estáticos de Flutter
            app.mount("/", StaticFiles(directory=FLUTTER_WEB_DIR, html=True), name="flutter_web")
            
            # No es necesario definir rutas adicionales si los estáticos están montados
        except RuntimeError as e:
            print(f"Error mounting static files: {e}")
            flutter_web_exists = False
    
    # Si no hay archivos estáticos de Flutter, definir las rutas para mostrar la página de API
    if not flutter_web_exists:
        # Ruta principal y dashboard muestran la misma página informativa
        @app.get("/", response_class=HTMLResponse)
        @app.get("/dashboard", response_class=HTMLResponse)
        async def api_info():
            return HTMLResponse(content="""
            <!DOCTYPE html>
            <html>
            <head>
                <title>StoreSense API</title>
                <style>
                    body { font-family: Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
                    h1 { color: #0277BD; text-align: center; }
                    .header { text-align: center; margin-bottom: 30px; }
                    .endpoint { background: #f4f4f4; padding: 15px; margin-bottom: 15px; border-radius: 8px; }
                    code { background: #e0e0e0; padding: 2px 6px; border-radius: 4px; }
                    .api-container { margin-top: 40px; }
                    .status { color: #4CAF50; font-weight: bold; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>StoreSense API Server</h1>
                    <p class="status">✅ API ACTIVA Y FUNCIONANDO</p>
                    <p>La interfaz web de Flutter no está disponible en este entorno. Sin embargo, todos los endpoints de la API están operativos.</p>
                </div>
                
                <div class="api-container">
                    <h2>Endpoints disponibles:</h2>
                    <div class="endpoint">
                        <h3>Documentación de la API</h3>
                        <p>Accede a la documentación completa de la API:</p>
                        <p><a href="/docs"><code>GET /docs</code></a> - Documentación con Swagger UI</p>
                        <p><a href="/redoc"><code>GET /redoc</code></a> - Documentación con ReDoc</p>
                    </div>
                    
                    <div class="endpoint">
                        <h3>Probar conexión</h3>
                        <p><a href="/api/hello"><code>GET /api/hello</code></a></p>
                    </div>
                    
                    <div class="endpoint">
                        <h3>Estadísticas</h3>
                        <p><code>GET /api/statistics/*</code></p>
                        <p>Accede a todos los endpoints de estadísticas disponibles.</p>
                    </div>
                     <div class="endpoint">
                        <h3>Cámaras</h3>
                        <p><code>GET /api/cameras</code></p>
                        <p><code>POST /api/cameras</code></p>
                        <p><code>PUT /api/cameras/{camera_id_mongo}</code></p>
                        <p><code>DELETE /api/cameras/{camera_id_mongo}</code></p>
                    </div>
                </div>
            </body>
            </html>
            """)
    
    # Las otras rutas dinámicas se agregan después de las rutas estáticas

@router.get("/hello")
def hello_world():
    return {"message": "Hola Mundo s3!!"}

@router.get("/statistics/peak-hours/")
def daily_traffic():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_peak_hours()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/categories/")
def categories():
    try: 
        data = get_categories()
        return {"message": "Success", "data": data}
    except Exception as e: 
        return {"message": "Error", "error": str(e)}
    
# @router.get("/categories/update/")
# def update_a_category():
#     try: 
#         data = update_category()
#         return {"message": "Success", "data": data}
#     except Exception as e:
#         return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/least-hours/")
def daily_traffic():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_least_busy_hours()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/busy-days/")
def daily_traffic():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_most_busy_day()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/least-days/")
def daily_traffic():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_least_busy_day()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/least-visited/")
def least_visited_category(period: str, date: Optional[str] = None):
    """
    Endpoint para obtener la categoría de producto menos visitada en un rango de tiempo (día, semana o mes).
    """
    try:
        data = get_least_visited_category(period=period, date=date)
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/least-visited-historical/")
def least_visited_category_historical():
    """
    Endpoint para obtener la categoría de producto menos visitada utilizando todos los datos históricos.
    """
    try:
        data = get_least_visited_category_historical()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/most-visited/")
def most_visited_category(period: str, date: Optional[str] = None):
    """
    Endpoint para obtener la categoría de producto menos visitada en un rango de tiempo (día, semana o mes).
    """
    try:
        data = get_most_visited_category(period=period, date=date)
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/most-visited-historical/")
def most_visited_category_historical():
    """
    Endpoint para obtener la categoría de producto más visitada utilizando todos los datos históricos.
    """
    try:
        data = get_most_visited_category_historical()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/visited-categories-historical/")
def visited_categories_historical():
    """
    Endpoint para obtener las categorías de producto más y menos visitadas utilizando todos los datos históricos.
    """
    try:
        most_visited_data = get_most_visited_category_historical()
        least_visited_data = get_least_visited_category_historical()
        
        combined_data = {
            "most_visited_category": most_visited_data["most_visited_category"],
            "most_visited_count": most_visited_data["count"],
            "least_visited_category": least_visited_data["least_visited_category"],
            "least_visited_count": least_visited_data["count"]
        }
        
        return {"message": "Success", "data": combined_data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/emotion-percentage/")
def emotion_percentage():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_emotion_percentage_by_category()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/most-frequent-emotions/")
def most_frequent_emotions():
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana.
    """
    try:
        data = get_most_frequent_emotions()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/age-distribution/")
def age_distribution(period: str, date: Optional[str] = None, end_date: Optional[str] = None):
    """
    Endpoint para obtener la distribución de visitantes por rango de edad en un período (semana o mes).
    :param period: "week" o "month"
    :param date: Fecha de inicio (opcional, formato YYYY-MM-DD)
    :param end_date: Fecha de fin para período "week" (opcional, formato YYYY-MM-DD)
    """
    try:
        # Llamar a la función con los parámetros proporcionados
        data = get_age_distribution(period=period, date=date, end_date=end_date)
        return {"message": "Success", "data": data}
    except ValueError as ve:
        return {"message": "Error", "error": str(ve)}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/gender-distribution/")
def gender_distribution(period: str, date: Optional[str] = None, end_date: Optional[str] = None):
    """
    Endpoint para obtener la distribución de visitantes por sexo en un período (semana o mes).
    :param period: "week" o "month"
    :param date: Fecha de inicio (opcional, formato YYYY-MM-DD)
    :param end_date: Fecha de fin para período "week" (opcional, formato YYYY-MM-DD)
    """
    try:
        # Llamar a la función con los parámetros proporcionados
        data = get_gender_distribution(period=period, date=date, end_date=end_date)
        return {"message": "Success", "data": data}
    except ValueError as ve:
        return {"message": "Error", "error": str(ve)}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/emotion-comparison/")
def emotion_comparison(period: str = "week", date: Optional[str] = None, end_date: Optional[str] = None, month: Optional[int] = None, year: Optional[int] = None):
    """
    Endpoint para comparar emociones positivas (HAPPY) y negativas (SAD) por día de la semana.
    
    Parameters:
    - period (str): "week" o "month" para definir el período de análisis.
    - date (str): Fecha de inicio en formato YYYY-MM-DD (para period="week").
    - end_date (str): Fecha de fin en formato YYYY-MM-DD (para period="week").
    - month (int): Número del mes (1-12) para análisis mensual (para period="month").
    - year (int): Año para análisis mensual (para period="month").
    """
    try:
        # Log parameter values
        print(f"Emotion comparison endpoint called with: period={period}, date={date}, end_date={end_date}, month={month}, year={year}")
        
        # Llamar a la función para obtener los datos
        data = get_emotion_comparison(period=period, date=date, end_date=end_date, month=month, year=year)
        
        # Check if the result is an error tuple
        if isinstance(data, tuple) and len(data) == 2 and isinstance(data[0], dict) and "error" in data[0]:
            return {"message": "Error", "error": data[0]["error"]}, data[1]
        
        # Return success with data
        return {"message": "Success", "data": data}
    except Exception as e:
        print(f"Exception in emotion_comparison endpoint: {e}")
        import traceback
        traceback.print_exc()
        return {"message": "Error", "error": str(e)}
    
@router.get("/statistics/preferred-category-by-gender/")
def preferred_category_by_gender():
    """
    Endpoint para obtener las categorías de productos preferidas por género (hombres y mujeres).
    """
    try:
        # Llamar a la función para obtener los datos
        data = get_preferred_category_by_gender()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/top-successful-categories/")
def top_successful_categories():
    """
    Endpoint para obtener el top de categorías que generan más emociones positivas (HAPPY).
    """
    try:
        # Llamar a la función para obtener los datos
        data = get_top_successful_categories()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/emotional-differences-by-category/")
def emotional_differences_by_category():
    """
    Endpoint para obtener las emociones predominantes por género en cada categoría de productos.
    """
    try:
        # Llamar a la función para obtener los datos
        data = get_emotional_differences_by_category()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.get("/statistics/age-gender-distribution-by-category/")
def age_gender_distribution_by_category():
    """
    Endpoint para obtener las combinaciones de género y rango de edad más frecuentes por categoría de producto.
    """
    try:
        # Llamar a la función para obtener los datos
        data = get_age_gender_distribution_by_category()
        return {"message": "Success", "data": data}
    except Exception as e:
        return {"message": "Error", "error": str(e)}
    

@router.post("/upload-image/")
async def upload_image_endpoint(background_tasks: BackgroundTasks, payload: ImagePayload):
    try:
        logger.info("Starting upload_image_endpoint")
        # Leer la imagen en formato Base64
        image_base64 = payload.image_base64
        id_camara = payload.id_camara

        if not image_base64:
            raise HTTPException(status_code=400, detail="Empty image file provided")

        # Convertir la imagen de Base64 a bytes
        image_bytes = base64.b64decode(image_base64)

        # Convertir los bytes a formato JPEG
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert("RGB")  # Asegurarse de que esté en formato RGB
        jpeg_buffer = io.BytesIO()
        image.save(jpeg_buffer, format="JPEG")
        jpeg_bytes = jpeg_buffer.getvalue()

        # Mejorar la imagen utilizando OpenCV
        logger.info("Starting image enhancement with OpenCV")
        np_image = np.frombuffer(jpeg_bytes, np.uint8)
        cv_image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
        
        # Convertir BGR a RGB (OpenCV carga imágenes en BGR por defecto)
        cv_image_rgb = cv2.cvtColor(cv_image, cv2.COLOR_BGR2RGB)
        
        # Escalar la imagen (opcional, dependiendo de los requisitos)
        scale_factor = 1.0  # Sin escala para preservar la imagen original
        if scale_factor != 1.0:
            new_width = int(cv_image_rgb.shape[1] * scale_factor)
            new_height = int(cv_image_rgb.shape[0] * scale_factor)
            cv_image_rgb = cv2.resize(cv_image_rgb, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
            logger.info(f"Image resized to {new_width}x{new_height}")
        
        # Separar la imagen en canales L*a*b para preservar el color mientras mejoramos el brillo
        lab_image = cv2.cvtColor(cv_image_rgb, cv2.COLOR_RGB2LAB)
        l_channel, a_channel, b_channel = cv2.split(lab_image)
        
        # Aplicar CLAHE solo al canal L (luminosidad) para mejorar el contraste
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced_l_channel = clahe.apply(l_channel)
        
        # Reducir ruido manteniendo bordes en el canal de luminosidad
        enhanced_l_channel = cv2.bilateralFilter(enhanced_l_channel, 5, 50, 50)
        
        # Ajuste sutil de contraste en el canal L
        alpha = 1.1  # Contraste (1.0 = sin cambio)
        beta = 0     # Brillo (0 = sin cambio)
        enhanced_l_channel = cv2.convertScaleAbs(enhanced_l_channel, alpha=alpha, beta=beta)
        
        # Mejorar nitidez en el canal de luminosidad
        kernel = np.array([[-0.5, -0.5, -0.5], 
                          [-0.5,  5.0, -0.5], 
                          [-0.5, -0.5, -0.5]])
        enhanced_l_channel = cv2.filter2D(enhanced_l_channel, -1, kernel)
        
        # Reconstruir la imagen LAB con los canales de color originales
        enhanced_lab_image = cv2.merge([enhanced_l_channel, a_channel, b_channel])
        
        # Convertir de vuelta a RGB
        enhanced_rgb_image = cv2.cvtColor(enhanced_lab_image, cv2.COLOR_LAB2RGB)
        
        # Convertir a BGR para guardar con OpenCV
        enhanced_bgr_image = cv2.cvtColor(enhanced_rgb_image, cv2.COLOR_RGB2BGR)
        
        # Ajuste final de calidad
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 95]
        _, enhanced_image_bytes = cv2.imencode('.jpg', enhanced_bgr_image, encode_param)
        logger.info("Image enhancement with OpenCV completed")

        # Subir la imagen mejorada a S3
        current_time = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"{current_time}_{id_camara}.jpeg"
        s3_url = upload_image_to_s3(enhanced_image_bytes.tobytes(), file_name)
        logger.info(f"Image uploaded to S3: {s3_url}")

        # Llamar al siguiente endpoint para analizar la imagen
        background_tasks.add_task(analyze_image_endpoint, enhanced_image_bytes.tobytes(), id_camara)

        return {"message": "Image uploaded successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in upload_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def analyze_image_endpoint(image_bytes: bytes, id_camara: int):
    try:
        logger.info("Starting analyze_image_endpoint")

        # Analizar la imagen con AWS Rekognition
        response = analyze_image(image_bytes)
        logger.info("Image analyzed successfully")

        # Guardar los resultados del análisis en un archivo temporal
        analysis_result_path = "analysis_result.json"
        with open(analysis_result_path, "w") as f:
            json.dump(response, f)
        logger.info("Analysis results saved to temporary file")

        logger.info("Image analysis completed, calling save_to_db_endpoint")

        # Llamar al siguiente endpoint
        await save_to_db_endpoint(analysis_result_path, id_camara)
        logger.info("save_to_db_endpoint called successfully")

        return {"message": "Image analysis completed successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in analyze_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def save_to_db_endpoint(result_path: str, id_camara: int):
    try:
        logger.info("Starting save_to_db_endpoint")

        # Leer los resultados del análisis desde el archivo temporal
        with open(result_path, "r") as f:
            response = json.load(f)
        logger.info("Analysis results loaded from temporary file")

        # Filtrando los resultados para solo obtener AgeRange, Gender y Emotions
        filtered_faces = []
        for face_detail in response['FaceDetails']:
            filtered_face = {
                'AgeRange': face_detail.get('AgeRange'),
                'Gender': face_detail.get('Gender'),
                'Emotions': face_detail.get('Emotions')
            }
            filtered_faces.append(filtered_face)

        logger.info(f"Filtered faces: {filtered_faces}")
        
        # Obtener el tipo_producto correspondiente al id_camara
        tipo_producto_zona_camara = collections['Tipo_Producto_Zona_Camara'].find_one({"Id_Camara": id_camara})
        if not tipo_producto_zona_camara:
            raise HTTPException(status_code=404, detail="Id_Camara not found in Tipo_Producto_Zona_Camara")

        tipo_producto = tipo_producto_zona_camara['Tipo_Producto']
        logger.info(f"Found tipo_producto: {tipo_producto}")

        # Obtener el Categoria_Producto correspondiente al tipo_producto
        tipo_producto_doc = collections['Tipo_Producto'].find_one({"Tipo_Producto": tipo_producto})
        if not tipo_producto_doc:
            raise HTTPException(status_code=404, detail="Tipo_Producto not found in Tipo_Producto")

        categoria_producto = tipo_producto_doc['Categoria_Producto']
        logger.info(f"Found categoria_producto: {categoria_producto}")

        # Zona horaria de Venezuela
        venezuela_tz = timezone('America/Caracas')

        # Insertar en MongoDB
        for face in filtered_faces:
            emotions = face['Emotions']
            primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
            
            # Obtener la hora actual en la zona horaria de Venezuela
            now_venezuela = datetime.now(venezuela_tz)
            
            document = {
                "id": get_next_sequence_value("persona_id"),  # Obtener un ID único
                "date": now_venezuela.strftime("%Y-%m-%d"),  # Fecha como cadena en formato YYYY-MM-DD
                "time": now_venezuela.strftime("%H:%M:%S"),  # Hora en formato HH:MM:SS
                "id_camara": id_camara,
                "categoria_producto": categoria_producto,  # Agregar categoria_producto
                "gender": face['Gender']['Value'],
                "age_range": {
                    "low": face['AgeRange']['Low'],
                    "high": face['AgeRange']['High']
                },
                "emotions": primary_emotion
            }
            logger.info(f"Inserting document into MongoDB: {document}")
            collections['Persona_AR'].insert_one(document)

        logger.info("Data saved to database successfully")
        return {"message": "Data saved to database successfully."}

    except Exception as e:
        logger.error(f"Unexpected error in save_to_db_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Helper functions for auth
def hash_password(password: str) -> str:
    """Hash a password for storing."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a stored password against provided password."""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_access_token(data: dict, expires_delta: timedelta = None):
    """Create JWT token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Decode JWT token to get current user."""
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.PyJWTError:
        raise credentials_exception
    
    user = collections['Users'].find_one({"_id": int(user_id)})
    if user is None:
        raise credentials_exception
    
    return user

@router.post("/signup", response_model=Token)
async def signup(user_data: UserCreate):
    """Endpoint for user registration."""
    # Check if user already exists
    if collections['Users'].find_one({"email": user_data.email}) is not None:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new user
    user_id = get_next_sequence_value("user_id")
    hashed_password = hash_password(user_data.password)
    
    # Create user document
    user = {
        "_id": user_id,
        "email": user_data.email,
        "password": hashed_password,
        "full_name": user_data.full_name,
        "role": user_data.role,
        "created_at": datetime.utcnow().isoformat()
    }
    
    # Insert user into database
    collections['Users'].insert_one(user)
    
    # Create and return access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user_id)}, 
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user_id),
        "email": user.get("email"),
        "full_name": user.get("full_name"),
        "role": user.get("role")
    }

@router.post("/login", response_model=Token)
async def login(user_data: UserLogin):
    """Endpoint for user login."""
    # Find user by email
    user = collections['Users'].find_one({"email": user_data.email})
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Verify password
    if not verify_password(user_data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Create and return access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user["_id"])}, 
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user["_id"]),
        "email": user.get("email"),
        "full_name": user.get("full_name"),
        "role": user.get("role")
    }

# User management endpoints
class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None

@router.get("/users", response_model=dict)
async def get_users(current_user: dict = Depends(get_current_user)):
    """Endpoint to get all users. Admin only."""
    # Check if user is admin
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Access forbidden: Admin only")
    
    users = list(collections['Users'].find({}, {"password": 0}))  # Exclude password field
    
    # Convert ObjectId to string for JSON serialization
    for user in users:
        user["_id"] = str(user["_id"])
    
    return {"message": "Success", "data": users}

@router.get("/users/{user_id}", response_model=dict)
async def get_user(user_id: str, current_user: dict = Depends(get_current_user)):
    """Endpoint to get a specific user. Admin or self only."""
    # Check if user is admin or self
    if current_user.get("role") != "admin" and str(current_user.get("_id")) != user_id:
        raise HTTPException(status_code=403, detail="Access forbidden: Admin or self only")
    
    user = collections['Users'].find_one({"_id": int(user_id)}, {"password": 0})
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Convert ObjectId to string for JSON serialization
    user["_id"] = str(user["_id"])
    
    return {"message": "Success", "data": user}

@router.put("/users/{user_id}", response_model=dict)
async def update_user(user_id: str, user_data: UserUpdate, current_user: dict = Depends(get_current_user)):
    """Endpoint to update a user. Admin or self only."""
    # Check if user is admin or self
    if current_user.get("role") != "admin" and str(current_user.get("_id")) != user_id:
        raise HTTPException(status_code=403, detail="Access forbidden: Admin or self only")
    
    # Find user
    user = collections['Users'].find_one({"_id": int(user_id)})
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prepare update data
    update_data = {}
    if user_data.email is not None:
        # Check if email is already taken by another user
        existing_user = collections['Users'].find_one({"email": user_data.email})
        if existing_user is not None and str(existing_user["_id"]) != user_id:
            raise HTTPException(status_code=400, detail="Email already registered")
        update_data["email"] = user_data.email
    
    if user_data.full_name is not None:
        update_data["full_name"] = user_data.full_name
    
    # Only admin can change roles
    if user_data.role is not None:
        if current_user.get("role") != "admin":
            raise HTTPException(status_code=403, detail="Only admin can change roles")
        update_data["role"] = user_data.role
    
    # Update password if provided
    if user_data.password is not None:
        update_data["password"] = hash_password(user_data.password)
    
    # Update user
    if update_data:
        collections['Users'].update_one({"_id": int(user_id)}, {"$set": update_data})
    
    # Get updated user
    updated_user = collections['Users'].find_one({"_id": int(user_id)}, {"password": 0})
    updated_user["_id"] = str(updated_user["_id"])
    
    return {"message": "User updated successfully", "data": updated_user}

@router.delete("/users/{user_id}", response_model=dict)
async def delete_user(user_id: str, current_user: dict = Depends(get_current_user)):
    """Endpoint to delete a user. Admin only."""
    # Check if user is admin
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Access forbidden: Admin only")
    
    # Find user
    user = collections['Users'].find_one({"_id": int(user_id)})
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent deleting self
    if str(current_user.get("_id")) == user_id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    
    # Delete user
    collections['Users'].delete_one({"_id": int(user_id)})
    
    return {"message": "User deleted successfully"}


# --- Camera Routes --- 

# Helper function to serialize MongoDB ObjectId (already defined above, but good practice)
def serialize_doc(doc):
    if doc and '_id' in doc:
        doc['_id'] = str(doc['_id'])
    return doc

@router.get("/cameras", response_model=List[Dict[str, Any]], tags=["Cameras"])
async def get_cameras_with_details():
    """
    Retrieves all cameras from Tipo_Producto_Zona_Camara and joins them
    with their corresponding product category from Tipo_Producto.
    """
    try:
        # Use aggregation pipeline to join collections
        pipeline = [
            {
                '$lookup': {
                    'from': 'Tipo_Producto',
                    'localField': 'Tipo_Producto',
                    'foreignField': 'Tipo_Producto',
                    'as': 'productDetails'
                }
            },
            {
                '$unwind': {
                    'path': '$productDetails',
                    'preserveNullAndEmptyArrays': True # Keep cameras even if no matching product found
                }
            },
            {
                '$project': {
                    '_id': 1,
                    'Id_Camara': 1,
                    'Tipo_Producto_Id': '$Tipo_Producto', # Keep the ID
                    'Categoria_Producto': '$productDetails.Categoria_Producto',
                    'isActive': 1
                }
            }
        ]
        cameras_cursor = collections['Tipo_Producto_Zona_Camara'].aggregate(pipeline)
        cameras_list = [serialize_doc(camera) for camera in cameras_cursor]
        
        # Handle cases where Categoria_Producto might be null if join failed
        for camera in cameras_list:
            if 'Categoria_Producto' not in camera or camera['Categoria_Producto'] is None:
                camera['Categoria_Producto'] = 'Desconocida' # Or some default/indicator

        return cameras_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching cameras: {str(e)}")


@router.post("/cameras", response_model=Dict[str, Any], status_code=201, tags=["Cameras"])
async def create_camera(camera_data: Dict[str, Any] = Body(...)):
    """
    Creates a new camera entry in Tipo_Producto_Zona_Camara.
    Expects a body like: {"Id_Camara": <int>, "Tipo_Producto": <int>, "isActive": <bool>}
    """
    required_fields = ["Id_Camara", "Tipo_Producto", "isActive"]
    if not all(field in camera_data for field in required_fields):
        raise HTTPException(status_code=400, detail="Missing required fields: Id_Camara, Tipo_Producto, isActive")

    try:
        # Optional: Check if camera ID already exists
        existing_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"Id_Camara": camera_data["Id_Camara"]})
        if existing_camera:
             raise HTTPException(status_code=409, detail=f"Camera with Id_Camara {camera_data['Id_Camara']} already exists.")

        # Optional: Check if Tipo_Producto exists
        product_type = collections['Tipo_Producto'].find_one({"Tipo_Producto": camera_data["Tipo_Producto"]})
        if not product_type:
            raise HTTPException(status_code=404, detail=f"Tipo_Producto {camera_data['Tipo_Producto']} not found.")

        insert_result = collections['Tipo_Producto_Zona_Camara'].insert_one(camera_data)
        created_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": insert_result.inserted_id})
        return serialize_doc(created_camera)
    except HTTPException as http_exc:
        raise http_exc # Re-raise specific HTTP exceptions
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating camera: {str(e)}")

@router.put("/cameras/{camera_id_mongo}", response_model=Dict[str, Any], tags=["Cameras"])
async def update_camera_status(
    camera_id_mongo: str = Path(..., title="The MongoDB ObjectId of the camera to update"),
    update_data: Dict[str, Any] = Body(...)
):
    """
    Updates an existing camera's status (isActive field).
    Expects a body like: {"isActive": <bool>}
    """
    if 'isActive' not in update_data or not isinstance(update_data['isActive'], bool):
        raise HTTPException(status_code=400, detail="Invalid request body. 'isActive' (boolean) is required.")

    try:
        object_id = ObjectId(camera_id_mongo)
    except Exception:
         raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")

    try:
        update_result = collections['Tipo_Producto_Zona_Camara'].update_one(
            {"_id": object_id},
            {"$set": {"isActive": update_data['isActive']}}
        )

        if update_result.matched_count == 0:
            raise HTTPException(status_code=404, detail=f"Camera with id {camera_id_mongo} not found.")

        if update_result.modified_count == 0:
             # Return 304 Not Modified or the current document? Let's return the doc.
             pass # It means the value was already set to the desired state

        updated_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": object_id})
        return serialize_doc(updated_camera)

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating camera: {str(e)}")


@router.delete("/cameras/{camera_id_mongo}", status_code=204, tags=["Cameras"])
async def delete_camera(
    camera_id_mongo: str = Path(..., title="The MongoDB ObjectId of the camera to delete")
):
    """
    Deletes a camera entry by its MongoDB ObjectId.
    """
    try:
        object_id = ObjectId(camera_id_mongo)
    except Exception:
         raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")

    try:
        delete_result = collections['Tipo_Producto_Zona_Camara'].delete_one({"_id": object_id})

        if delete_result.deleted_count == 0:
            raise HTTPException(status_code=404, detail=f"Camera with id {camera_id_mongo} not found.")

        return # No content response for successful deletion
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting camera: {str(e)}")