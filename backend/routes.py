from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks
from backend.aws import analyze_image
from datetime import datetime
from backend.database import collections
import pymongo
import os
import io
from fastapi.responses import StreamingResponse, JSONResponse
import logging
import json
import numpy as np
from PIL import Image
import torch
import requests
from backend.real_esrgan.rrdbnet_arch import RRDBNet
from backend.real_esrgan.realesrgan import RealESRGANer

router = APIRouter()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Directorio donde se almacenará el modelo
model_dir = "Real-ESRGAN-weights"
model_path = os.path.join(model_dir, "RealESRGAN_x4plus.pth")

# Verificar si el modelo existe, si no, descargarlo
if not os.path.exists(model_path):
    logger.info("Modelo no encontrado. Descargando...")
    os.makedirs(model_dir, exist_ok=True)
    url = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
    r = requests.get(url, allow_redirects=True)
    with open(model_path, 'wb') as f:
        f.write(r.content)
    logger.info("Modelo descargado exitosamente.")

# Configurar el modelo de Real-ESRGAN
model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
netscale = 4

upsampler = RealESRGANer(
    scale=netscale,
    model_path=model_path,
    model=model,
    tile=512,  # prueba para reducir el consumo de memoria
    tile_pad=10,
    pre_pad=0,
    half=False  
)

def enhance_image(image_bytes):
    try:
        logger.info("Starting image enhancement process")

        # Cargar la imagen desde los bytes
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert('RGB')  # Asegurarse de que la imagen esté en formato RGB
        logger.info("Image loaded and converted to RGB")

        # Convertir la imagen a un array de numpy
        img = np.array(image)
        logger.info(f"Image converted to numpy array with shape {img.shape}")

        # Verificar que la imagen tenga 3 canales
        if img.shape[2] != 3:
            raise ValueError(f"Expected image to have 3 channels, but got {img.shape[2]} channels instead")

        # Mejorar la imagen utilizando Real-ESRGAN
        output, _ = upsampler.enhance(img, outscale=4)
        logger.info("Image enhancement completed")

        output_image = Image.fromarray(output)

        # Convertir la imagen mejorada a bytes
        buffer = io.BytesIO()
        output_image.save(buffer, format='JPEG')
        enhanced_image_bytes = buffer.getvalue()
        logger.info("Enhanced image converted to bytes")

        # Liberar memoria
        del image, img, output, output_image, buffer
        torch.cuda.empty_cache()
        logger.info("Memory cleared")

        return enhanced_image_bytes
    except Exception as e:
        logger.error(f"Error enhancing image: {e}")
        raise

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
    return {"message": "Hola Mundo!!"}

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

        logger.info("Starting image enhancement process")
        # Leer la imagen desde el archivo temporal
        with open(image_path, "rb") as f:
            image_bytes = f.read()

        # Mejorar la imagen
        enhanced_image_bytes = enhance_image(image_bytes)

        # Guardar la imagen mejorada en un archivo temporal
        enhanced_image_path = "enhanced_image.jpg"
        with open(enhanced_image_path, "wb") as f:
            f.write(enhanced_image_bytes)

        logger.info("Image enhancement completed, calling analyze_image_endpoint")

        # Llamar al siguiente endpoint
        await analyze_image_endpoint(enhanced_image_path)
        return {"message": "Image enhancement completed successfully, processing started."}

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

        return {"message": "Image analysis completed successfully, processing started."}

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