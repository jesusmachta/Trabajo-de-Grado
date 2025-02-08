from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks
from backend.aws import analyze_image
from backend.image_enhancement import enhance_image
from datetime import datetime
from backend.database import collections
import pymongo
import os
import io
from fastapi.responses import StreamingResponse, JSONResponse
import logging
import json

router = APIRouter()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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
    app.include_router(router)

@router.get("/")
def hello_world():
    return {"message": "Hello endpoints para cada, World!"}

@router.post("/upload-image/")
async def upload_image_endpoint(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    try:
        # Leer el archivo subido
        image_bytes = await file.read()

        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image file provided")

        # Guardar la imagen en un archivo temporal
        temp_image_path = "temp_image.jpg"
        with open(temp_image_path, "wb") as f:
            f.write(image_bytes)

        # Llamar al siguiente endpoint en segundo plano
        background_tasks.add_task(enhance_image_endpoint, temp_image_path)

        return {"message": "Image uploaded successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def enhance_image_endpoint(image_path: str):
    try:
        # Leer la imagen desde el archivo temporal
        with open(image_path, "rb") as f:
            image_bytes = f.read()

        # Mejorar la imagen
        enhanced_image_bytes = enhance_image(image_bytes)

        # Guardar la imagen mejorada en un archivo temporal
        enhanced_image_path = "enhanced_image.jpg"
        with open(enhanced_image_path, "wb") as f:
            f.write(enhanced_image_bytes)

        # Llamar al siguiente endpoint
        await analyze_image_endpoint(enhanced_image_path)

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def analyze_image_endpoint(image_path: str):
    try:
        # Leer la imagen mejorada desde el archivo temporal
        with open(image_path, "rb") as f:
            enhanced_image_bytes = f.read()

        # Analizar la imagen mejorada con AWS Rekognition
        response = analyze_image(enhanced_image_bytes)

        # Guardar los resultados del análisis en un archivo temporal
        analysis_result_path = "analysis_result.json"
        with open(analysis_result_path, "w") as f:
            json.dump(response, f)

        # Llamar al siguiente endpoint
        await save_to_db_endpoint(analysis_result_path)

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def save_to_db_endpoint(result_path: str):
    try:
        # Leer los resultados del análisis desde el archivo temporal
        with open(result_path, "r") as f:
            response = json.load(f)

        # Filtrando los resultados para solo obtener AgeRange, Gender y Emotions
        filtered_faces = []
        for face_detail in response['FaceDetails']:
            filtered_face = {
                'AgeRange': face_detail.get('AgeRange'),
                'Gender': face_detail.get('Gender'),
                'Emotions': face_detail.get('Emotions')
            }
            filtered_faces.append(filtered_face)

        # Insertar en MongoDB
        for face in filtered_faces:
            emotions = face['Emotions']
            primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
            document = {
                "id": get_next_sequence_value("persona_id"),  # Obtener un ID único
                "date": datetime.utcnow(),
                "time": datetime.utcnow().strftime("%H:%M:%S"),
                "id_camara": 1,  # Asigna el ID de la cámara según tu lógica
                "gender": face['Gender']['Value'],
                "age_range": {
                    "low": face['AgeRange']['Low'],
                    "high": face['AgeRange']['High']
                },
                "emotions": primary_emotion
            }
            logger.info(f"Inserting document into MongoDB: {document}")
            collections['Persona_AR'].insert_one(document)

        return {"message": "Data saved to database successfully."}

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))