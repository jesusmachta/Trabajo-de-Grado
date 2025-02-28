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
import torch
import requests
import base64
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

class ImagePayload(BaseModel):
    image_base64: str
    id_camara: int

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

        # Reordenar las dimensiones de la imagen para que sean [C, H, W]
        img = np.transpose(img, (2, 0, 1))
        logger.info(f"Image transposed to shape {img.shape}")

        # Añadir una dimensión adicional para el batch size
        img = np.expand_dims(img, axis=0)
        logger.info(f"Image expanded to shape {img.shape}")

        # Mejorar la imagen utilizando Real-ESRGAN
        output, _ = upsampler.enhance(img, outscale=4)
        logger.info("Image enhancement completed")

        # Convertir la salida del modelo a un formato manejable por PIL
        output = output.squeeze().transpose(1, 2, 0)
        logger.info(f"Output image shape after squeezing and transposing: {output.shape}")

        # Asegurarse de que los valores estén en el rango [0, 255]
        output = np.clip(output, 0, 255)

        # Convertir la salida del modelo a uint8
        output = output.astype(np.uint8)

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

        # Guardar la imagen en un archivo temporal
        temp_image_path = "temp_image.jpg"
        with open(temp_image_path, "wb") as f:
            f.write(image_bytes)

        logger.info("Image saved to temporary file, calling enhance_image_endpoint")

        # Llamar al siguiente endpoint en segundo plano
        background_tasks.add_task(enhance_image_endpoint, temp_image_path, id_camara)

        return {"message": "Image uploaded successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in upload_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def enhance_image_endpoint(image_path: str, id_camara: int):
    try:
        logger.info("Starting enhance_image_endpoint")
        # Leer la imagen desde el archivo temporal
        with open(image_path, "rb") as f:
            image_bytes = f.read()

        # Mejorar la imagen
        enhanced_image_bytes = enhance_image(image_bytes)
        logger.info(f"Enhanced image size: {len(enhanced_image_bytes)} bytes")

        # Guardar la imagen mejorada en un archivo temporal
        enhanced_image_path = "enhanced_image.jpg"
        with open(enhanced_image_path, "wb") as f:
            f.write(enhanced_image_bytes)

        logger.info("Image enhancement completed, calling analyze_image_endpoint")

        # Subir la imagen mejorada a S3
        current_time = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"{current_time}_{id_camara}.jpeg"
        s3_url = upload_image_to_s3(enhanced_image_bytes, file_name)
        logger.info(f"Image uploaded to S3: {s3_url}")

        # Llamar al siguiente endpoint
        await analyze_image_endpoint(enhanced_image_path, id_camara)
        logger.info("analyze_image_endpoint called successfully")

        return {"message": "Image enhancement completed successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in enhance_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def analyze_image_endpoint(image_path: str, id_camara: int):
    try:
        logger.info("Starting analyze_image_endpoint")

        # Leer la imagen mejorada desde el archivo temporal
        with open(image_path, "rb") as f:
            enhanced_image_bytes = f.read()

        # Analizar la imagen mejorada con AWS Rekognition
        response = analyze_image(enhanced_image_bytes)
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

        # Obtener el id_producto correspondiente al tipo_producto
        tipo_producto_doc = collections['Tipo_Producto'].find_one({"tipo_producto": tipo_producto})
        if not tipo_producto_doc:
            raise HTTPException(status_code=404, detail="Tipo_Producto not found in Tipo_Producto")

        id_producto = tipo_producto_doc['id_producto']

        # Insertar en MongoDB
        for face in filtered_faces:
            emotions = face['Emotions']
            primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
            document = {
                "id": get_next_sequence_value("persona_id"),  # Obtener un ID único
                "date": datetime.utcnow(),
                "time": datetime.utcnow().strftime("%H:%M:%S"),
                "id_camara": id_camara,
                "id_producto": id_producto,  # Agregar id_producto
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