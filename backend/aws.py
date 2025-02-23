import boto3
from botocore.exceptions import BotoCoreError, ClientError

rekognition = boto3.client('rekognition', region_name='us-west-2')  

def analyze_image(image_bytes):
    try:
        response = rekognition.detect_faces(
            Image={'Bytes': image_bytes},
            Attributes=['ALL']
        )
        return response
    except (BotoCoreError, ClientError) as e:
        raise Exception(f"Error processing image: {e}")