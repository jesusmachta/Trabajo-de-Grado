from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from backend.aws import analyze_image, upload_image_to_s3 # Asumiendo que estas funciones existen y funcionan
from datetime import datetime
from backend.database import collections # Asumiendo configuración de DB
import pymongo
# import os # No parece usarse directamente en el endpoint
import io
import logging
import json
import numpy as np
from PIL import Image
import base64
import cv2  # Importar OpenCV
# from typing import List, Optional # No parece usarse directamente en el endpoint

router = APIRouter()

# Configure logging
# Asegúrate de que 'name' esté definido o usa __name__
# logging.basicConfig(level=logging.INFO)
# logger = logging.getLogger(__name__) # Usar __name__ es más estándar
# --- Configuración de Logging Mejorada ---
logger = logging.getLogger(__name__)
if not logger.hasHandlers(): # Evitar añadir handlers múltiples veces si se recarga el módulo
    logger.setLevel(logging.INFO)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
# -----------------------------------------


class ImagePayload(BaseModel):
    image_base64: str
    id_camara: int

def get_next_sequence_value(sequence_name):
    try:
        # Asegúrate de que la colección 'counters' exista y tenga el documento adecuado
        sequence_document = collections['counters'].find_one_and_update(
            {"_id": sequence_name},
            {"$inc": {"seq": 1}},
            upsert=True, # Crea el contador si no existe la primera vez
            return_document=pymongo.ReturnDocument.AFTER
        )
        # No necesitas verificar si es None después de upsert=True, a menos que haya un error grave
        return sequence_document["seq"]
    except Exception as e:
        logger.error(f"Error al obtener el siguiente valor de secuencia '{sequence_name}': {e}")
        # Es mejor no lanzar HTTPException aquí, podría manejarse más arriba o devolver None/valor especial
        # raise HTTPException(status_code=500, detail=f"Error al obtener el siguiente valor de secuencia: {e}")
        # Propuesta: devolver un valor que indique error o propagar la excepción
        raise Exception(f"Error al obtener el siguiente valor de secuencia: {e}") # Propagar para manejo centralizado

def initialize_routes(app):
    app.include_router(router)

@router.get("/")
def hello_world():
    return {"message": "Hola Mundo s3!!"}

@router.post("/upload-image/")
async def upload_image_endpoint(background_tasks: BackgroundTasks, payload: ImagePayload):
    try:
        logger.info("Iniciando upload_image_endpoint")
        image_base64 = payload.image_base64
        id_camara = payload.id_camara

        if not image_base64:
            raise HTTPException(status_code=400, detail="Se proporcionó un archivo de imagen vacío")

        # Convertir la imagen de Base64 a bytes
        try:
            image_bytes = base64.b64decode(image_base64)
        except base64.binascii.Error as e:
            logger.error(f"Error decodificando Base64: {e}")
            raise HTTPException(status_code=400, detail=f"Formato Base64 inválido: {e}")

        # Convertir los bytes a imagen OpenCV (más directo que pasar por PIL y JPEG)
        np_image = np.frombuffer(image_bytes, np.uint8)
        cv_image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)

        if cv_image is None:
            logger.error("No se pudo decodificar la imagen con OpenCV.")
            raise HTTPException(status_code=400, detail="No se pudo decodificar la imagen. Formato inválido o corrupto.")

        logger.info("Imagen decodificada a formato OpenCV.")

        # --- Inicio Mejoramiento de Imagen con OpenCV ---
        logger.info("Iniciando mejoramiento de imagen con OpenCV")

        # 1. (Opcional) Reducción de Ruido
        #    Ajusta 'h' y 'templateWindowSize', 'searchWindowSize' según sea necesario.
        #    Puede ser costoso computacionalmente. Comenta si no es necesario o causa lentitud.
        # denoised_image = cv2.fastNlMeansDenoisingColored(cv_image, None, h=10, hColor=10, templateWindowSize=7, searchWindowSize=21)
        # logger.info("Reducción de ruido aplicada (opcional)")
        # processed_image = denoised_image # Usar la imagen sin ruido para los siguientes pasos
        processed_image = cv_image # Usar la imagen original si se omite la reducción de ruido

        # 2. Convertir a espacio de color LAB
        lab_image = cv2.cvtColor(processed_image, cv2.COLOR_BGR2LAB)
        logger.info("Imagen convertida a espacio de color LAB")

        # 3. Separar canales L, A, B
        l_channel, a_channel, b_channel = cv2.split(lab_image)

        # 4. Aplicar CLAHE al canal L
        #    Ajusta clipLimit (contraste) y tileGridSize (tamaño de la región local)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        cl = clahe.apply(l_channel)
        logger.info("CLAHE aplicado al canal L")

        # 5. Unir los canales de nuevo
        merged_lab = cv2.merge((cl, a_channel, b_channel))

        # 6. Convertir de vuelta a BGR
        enhanced_image_bgr = cv2.cvtColor(merged_lab, cv2.COLOR_LAB2BGR)
        logger.info("Imagen convertida de vuelta a BGR")

        # 7. (Opcional) Aplicar Nitidez (Sharpening)
        #    Puedes ajustar el kernel si necesitas más o menos nitidez.
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        final_image = cv2.filter2D(enhanced_image_bgr, -1, kernel)
        logger.info("Filtro de nitidez aplicado")
        # Si no quieres nitidez, usa: final_image = enhanced_image_bgr

        # 8. (Revisado) Redimensionamiento - Considera si es necesario
        #    Si decides redimensionar, hazlo sobre 'final_image'.
        #    Evalúa si el 'upscaling' es realmente beneficioso para Rekognition.
        # scale_factor = 1.0 # Ejemplo: Sin redimensionamiento
        # if scale_factor != 1.0:
        #     new_width = int(final_image.shape[1] * scale_factor)
        #     new_height = int(final_image.shape[0] * scale_factor)
        #     # Usar INTER_AREA para reducir, INTER_CUBIC/LANCZOS4 para agrandar
        #     interpolation = cv2.INTER_CUBIC if scale_factor > 1.0 else cv2.INTER_AREA
        #     final_image = cv2.resize(final_image, (new_width, new_height), interpolation=interpolation)
        #     logger.info(f"Imagen redimensionada (factor: {scale_factor}) a {new_width}x{new_height}")

        # 9. Codificar la imagen final a bytes JPEG para S3 y Rekognition
        #    Puedes ajustar la calidad del JPEG (0-100, por defecto suele ser 95)
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 90] # Calidad 90
        _, enhanced_image_bytes_buffer = cv2.imencode('.jpg', final_image, encode_param)
        enhanced_image_bytes = enhanced_image_bytes_buffer.tobytes()
        logger.info("Mejoramiento de imagen con OpenCV completado. Imagen codificada a JPEG.")
        # --- Fin Mejoramiento de Imagen ---


        # Subir la imagen mejorada a S3
        current_time = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        # Considerar añadir un identificador único (UUID) por si dos imágenes llegan en el mismo segundo
        file_name = f"{current_time}_{id_camara}.jpeg"
        # Asumo que upload_image_to_s3 espera bytes
        s3_url = upload_image_to_s3(enhanced_image_bytes, file_name)
        logger.info(f"Imagen subida a S3: {s3_url}") # Asegúrate de que s3_url no sea None o maneja el caso

        # Llamar al siguiente endpoint para analizar la imagen
        # Pasar los bytes directamente es más eficiente que leerlos de nuevo
        background_tasks.add_task(analyze_image_endpoint, enhanced_image_bytes, id_camara, s3_url) # Pasar s3_url si es necesario guardarlo

        return {"message": "Imagen recibida y procesando en segundo plano.", "s3_url": s3_url}

    # Captura de excepciones más específicas si es posible
    except HTTPException as http_exc:
        # Re-lanzar excepciones HTTP para que FastAPI las maneje
        raise http_exc
    except Exception as e:
        logger.exception(f"Error inesperado en upload_image_endpoint: {e}") # Usar logger.exception para incluir traceback
        raise HTTPException(status_code=500, detail=f"Error interno del servidor al procesar la imagen: {e}")

# Modificar analyze_image_endpoint para aceptar s3_url si lo necesitas guardar
async def analyze_image_endpoint(image_bytes: bytes, id_camara: int, s3_url: str):
    try:
        logger.info(f"Iniciando analyze_image_endpoint para cámara {id_camara}")

        # Analizar la imagen con AWS Rekognition
        # analyze_image debería tomar bytes como entrada
        response = analyze_image(image_bytes)
        logger.info("Análisis de imagen con Rekognition completado.")

        # No es necesario guardar en archivo temporal, podemos pasar el 'response' directamente
        # analysis_result_path = "analysis_result.json"
        # with open(analysis_result_path, "w") as f:
        #     json.dump(response, f)
        # logger.info("Analysis results saved to temporary file")

        # Llamar al siguiente endpoint pasando el diccionario de respuesta directamente
        # Asegúrate que la estructura de 'response' es la esperada por save_to_db_endpoint
        background_tasks = BackgroundTasks() # Necesitas instanciar BackgroundTasks si lo usas aquí
        background_tasks.add_task(save_to_db_endpoint, response, id_camara, s3_url)
        # Nota: Si analyze_image_endpoint es llamado por background_tasks.add_task desde upload_image_endpoint,
        # no puedes añadir otra tarea en segundo plano de esta forma fácilmente.
        # Sería mejor llamar a save_to_db_endpoint directamente:
        # await save_to_db_endpoint(response, id_camara, s3_url) # Llamada directa async

        logger.info(f"Llamando a save_to_db_endpoint para cámara {id_camara}")
        await save_to_db_endpoint(response, id_camara, s3_url) # Llamada directa recomendada

        # No deberías retornar un mensaje aquí si es una tarea en segundo plano,
        # ya que la petición original ya retornó. Si es llamada directa, está bien.
        # return {"message": "Análisis de imagen completado, guardando en BD."}

    except Exception as e:
        # El manejo de errores en tareas de segundo plano es complejo.
        # El error no se propagará al cliente. Debes loggearlo bien.
        logger.exception(f"Error inesperado en analyze_image_endpoint para cámara {id_camara}: {e}")
        # Considera mecanismos de reintento o notificación si falla una tarea en segundo plano.
        # No puedes lanzar HTTPException aquí si es una tarea en segundo plano.


# Modificar save_to_db_endpoint para aceptar la respuesta de Rekognition (dict) y s3_url
async def save_to_db_endpoint(rekognition_response: dict, id_camara: int, s3_url: str):
    try:
        logger.info(f"Iniciando save_to_db_endpoint para cámara {id_camara}")

        # Ya tenemos la respuesta, no hay que leer de archivo
        # with open(result_path, "r") as f:
        #     response = json.load(f)
        # logger.info("Analysis results loaded from temporary file")
        response = rekognition_response # Usar la respuesta pasada como argumento

        if 'FaceDetails' not in response or not response['FaceDetails']:
             logger.warning(f"No se detectaron caras en la imagen de la cámara {id_camara}. No se guardará nada.")
             return # No hacer nada si no hay caras

        # Filtrando los resultados para solo obtener AgeRange, Gender y Emotions
        filtered_faces = []
        for face_detail in response['FaceDetails']:
            # Añadir verificación de existencia de claves por si acaso
            age_range = face_detail.get('AgeRange', {'Low': None, 'High': None})
            gender = face_detail.get('Gender', {'Value': 'Unknown'})
            emotions = face_detail.get('Emotions', [])

            filtered_face = {
                'AgeRange': age_range,
                'Gender': gender,
                'Emotions': emotions
            }
            filtered_faces.append(filtered_face)

        logger.info(f"Caras filtradas ({len(filtered_faces)}) para cámara {id_camara}")

        # Insertar en MongoDB
        documents_to_insert = []
        current_timestamp = datetime.utcnow() # Usar el mismo timestamp para todos los documentos de esta imagen

        for face in filtered_faces:
            primary_emotion = 'Unknown'
            if face['Emotions']: # Verificar si hay lista de emociones
                # Encontrar la emoción con la mayor confianza
                 primary_emotion_data = max(face['Emotions'], key=lambda x: x.get('Confidence', 0))
                 primary_emotion = primary_emotion_data.get('Type', 'Unknown')


            # Obtener ID único para CADA persona detectada
            try:
                 person_id = get_next_sequence_value("persona_id")
            except Exception as seq_e:
                 logger.error(f"No se pudo obtener ID para persona. Saltando inserción. Error: {seq_e}")
                 continue # Saltar esta cara si no podemos obtener ID

            document = {
                "_id": person_id, # Usar el contador como _id principal es común
                "fecha_registro": current_timestamp, # Guardar objeto datetime completo
                # "time": current_timestamp.strftime("%H:%M:%S"), # Puedes derivarlo de fecha_registro si es necesario
                "id_camara": id_camara,
                "url_imagen": s3_url, # Guardar la URL de la imagen asociada
                "genero": face['Gender'].get('Value', 'Unknown'), # Usar .get con default
                "rango_edad": {
                    "low": face['AgeRange'].get('Low'), # Usar .get
                    "high": face['AgeRange'].get('High') # Usar .get
                },
                "emocion_primaria": primary_emotion,
                "detalles_rekognition": face # Opcional: guardar todos los detalles de esta cara
            }
            documents_to_insert.append(document)
            logger.debug(f"Documento preparado para inserción: {document}") # Log a nivel debug

        if documents_to_insert:
             try:
                 result = collections['Persona_AR'].insert_many(documents_to_insert)
                 logger.info(f"Se insertaron {len(result.inserted_ids)} documentos en MongoDB para cámara {id_camara}.")
             except pymongo.errors.BulkWriteError as bwe:
                 logger.error(f"Error de escritura en lote en MongoDB: {bwe.details}")
             except Exception as db_e:
                 logger.exception(f"Error insertando documentos en MongoDB: {db_e}")
        else:
             logger.info(f"No se prepararon documentos para insertar en MongoDB para cámara {id_camara}.")


        # No puedes retornar un mensaje HTTP si eres llamado desde una tarea en segundo plano
        # return {"message": "Data saved to database successfully."}

    except Exception as e:
        logger.exception(f"Error inesperado en save_to_db_endpoint para cámara {id_camara}: {e}")
        # Manejo de errores para tareas en segundo plano (log, notificar, etc.)