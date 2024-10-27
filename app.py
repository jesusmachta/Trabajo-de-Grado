from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import BotoCoreError, ClientError
import os
from datetime import datetime

app = Flask(__name__)

rekognition = boto3.client('rekognition', region_name='us-west-2')  # Cambia 'us-west-2' por tu región

@app.route('/')
def hello_world():
    return 'Hello, Catalina!'

@app.route('/analyze-image', methods=['POST'])
def analyze_image():
    try:
        if 'image' not in request.files:
            app.logger.error("No image file provided")
            return jsonify({'error': 'No image file provided'}), 400

        image = request.files['image'].read()

        if not image:
            app.logger.error("Empty image file provided")
            return jsonify({'error': 'Empty image file provided'}), 400

        response = rekognition.detect_faces(
            Image={'Bytes': image},
            Attributes=['ALL']
        )

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

        return jsonify(result)

    except (BotoCoreError, ClientError) as e:
        app.logger.error(f"Error processing image: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        app.logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal Server Error'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)