from fastapi import APIRouter, UploadFile, File, HTTPException
from backend.aws import analyze_image
from backend.image_enhancement import enhance_image
from datetime import datetime
from backend.database import collections
import pymongo
import os

router = APIRouter()

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
        raise HTTPException(status_code=500, detail=f"Error al obtener el siguiente valor de secuencia: {e}")

def initialize_routes(app):
    app.include_router(router)

@router.get("/")
def hello_world():
    return {"message": "Hello, Catalina!"}

@router.post("/analyze-image")
async def analyze_image_route(image: UploadFile = File(...)):
    try:
        image_bytes = await image.read()

        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image file provided")

        # Crear el directorio enhanced_images si no existe
        if not os.path.exists("enhanced_images"):
            os.makedirs("enhanced_images")

        # Mejorar la calidad de la imagen
        enhanced_image = enhance_image(image_bytes)

        # Guardar la imagen mejorada para inspección
        with open("enhanced_images/enhanced_image.jpg", "wb") as f:
            f.write(enhanced_image)

        # Analizar la imagen mejorada con AWS Rekognition
        response = analyze_image(enhanced_image)

        # Filtrando los resultados para solo obtener AgeRange, Gender y Emotions
        filtered_faces = []
        for face_detail in response['FaceDetails']:
            filtered_face = {
                'AgeRange': face_detail.get('AgeRange'),
                'Gender': face_detail.get('Gender'),
                'Emotions': face_detail.get('Emotions')
            }
            filtered_faces.append(filtered_face)

        # Estructurar la respuesta
        result = {
            'NumberOfFaces': len(filtered_faces),
            'Faces': filtered_faces
        }

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
            collections['Persona_AR'].insert_one(document)

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")