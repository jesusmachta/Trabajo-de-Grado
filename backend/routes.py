from flask import request, jsonify
from backend.aws import analyze_image
from backend.image_enhancement import enhance_image
from datetime import datetime
from backend.database import collections
import pymongo
import os

def get_next_sequence_value(sequence_name, app):
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
        app.logger.error(f"Error al obtener el siguiente valor de secuencia: {e}")
        raise

def initialize_routes(app):
    @app.route('/')
    def hello_world():
        return 'Hello, Catalina!'

    @app.route('/analyze-image', methods=['POST'])
    def analyze_image_route():
        try:
            if 'image' not in request.files:
                app.logger.error("No image file provided")
                return jsonify({'error': 'No image file provided'}), 400

            image = request.files['image'].read()

            if not image:
                app.logger.error("Empty image file provided")
                return jsonify({'error': 'Empty image file provided'}), 400

            # Crear el directorio enhanced_images si no existe
            if not os.path.exists("enhanced_images"):
                os.makedirs("enhanced_images")

            # Mejorar la calidad de la imagen
            app.logger.info("Enhancing image quality")
            enhanced_image = enhance_image(image)

            # Guardar la imagen mejorada para inspección
            with open("enhanced_images/enhanced_image.jpg", "wb") as f:
                f.write(enhanced_image)

            # Analizar la imagen mejorada con AWS Rekognition
            app.logger.info("Analyzing enhanced image with AWS Rekognition")
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
                    "id": get_next_sequence_value("persona_id", app),  # Obtener un ID único
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
                app.logger.info(f"Documento insertado en MongoDB: {document}")

            return jsonify(result)

        except Exception as e:
            app.logger.error(f"Unexpected error: {e}")
            return jsonify({'error': 'Internal Server Error'}), 500