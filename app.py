from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import BotoCoreError, ClientError
import os
from datetime import datetime
from database import collections

app = Flask(__name__)

rekognition = boto3.client('rekognition', region_name='us-west-2')  # Cambia 'us-west-2' por tu región

@app.route('/')
def hello_world():
    return 'Hello, Catalina!'

@app.route('/analyze-image', methods=['POST'])
def analyze_image():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    # cambiar después!!!! Es mientras
    id_camara_input = request.form.get('ID_Camara')
    tipo_producto_zona_camara = collections.get("Tipo_Producto_Zona_Camara")
    if id_camara_input:
        camara_document = tipo_producto_zona_camara.find_one({"ID_Camara": int(id_camara_input)})
        if not camara_document:
            return jsonify({'error': f'ID_Camara {id_camara_input} not found in Tipo_Producto_Zona_Camara'}), 404
        id_camara = camara_document["ID_Camara"]
    else:
        id_camara = 1

    fecha = request.form.get('Fecha', datetime.utcnow().strftime('%Y-%m-%d'))  
    hora = request.form.get('Hora', datetime.utcnow().strftime('%H:%M:%S')) 
    image = request.files['image'].read()

    try:
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
            collection = collections.get("Persona_AR")
            document = {
            "Fecha": fecha,
            "Hora": hora,
            "ID_Camara": id_camara,
            "faces": filtered_faces,
            "timestamp": datetime.utcnow()
        }
        collection.insert_one(document)
        collection.insert_one(document)


        return jsonify(filtered_faces)
    

    except (BotoCoreError, ClientError) as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)