from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from backend.aws import analyze_image, upload_image_to_s3
from datetime import datetime
from backend.database import collections
import pymongo
import os
import io
import logging
import json
import numpy as np
from PIL import Image
import base64
import cv2  # Importar OpenCV
from typing import List, Optional

router = APIRouter()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ImagePayload(BaseModel):
    image_base64: str
    id_camara: int

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
    return {"message": "Hola Mundo s3!!"}

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
        np_image = np.frombuffer(jpeg_bytes, np.uint8)  # Convertir a un array de NumPy
        cv_image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)  # Decodificar la imagen

        # Escalar la imagen para aumentar su tamaño
        scale_factor = 1.5  # Escalar la imagen un 50% más grande
        new_width = int(cv_image.shape[1] * scale_factor)
        new_height = int(cv_image.shape[0] * scale_factor)
        resized_image = cv2.resize(cv_image, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
        logger.info(f"Image resized to {new_width}x{new_height}")

        # Crear un kernel de nitidez más agresivo
        kernel = np.array([[0, -1, 0], [-1, 7, -1], [0, -1, 0]])  # Ajustar el kernel para mayor nitidez
        sharpened_image = cv2.filter2D(resized_image, -1, kernel)  # Aplicar el filtro de nitidez
        _, enhanced_image_bytes = cv2.imencode('.jpg', sharpened_image)  # Codificar la imagen mejorada a bytes
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

        # Insertar en MongoDB
        for face in filtered_faces:
            emotions = face['Emotions']
            primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
            document = {
                "id": get_next_sequence_value("persona_id"),  # Obtener un ID único
                "date": datetime.utcnow(),
                "time": datetime.utcnow().strftime("%H:%M:%S"),
                "id_camara": id_camara,
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