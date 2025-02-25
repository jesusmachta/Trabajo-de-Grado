import boto3
from botocore.exceptions import BotoCoreError, ClientError

rekognition = boto3.client('rekognition', region_name='us-west-2')
s3 = boto3.client('s3', region_name='us-west-2')
bucket_name = 'tesislospomelos'

def analyze_image(image_bytes):
    try:
        response = rekognition.detect_faces(
            Image={'Bytes': image_bytes},
            Attributes=['ALL']
        )
        return response
    except (BotoCoreError, ClientError) as e:
        raise Exception(f"Error processing image: {e}")

def upload_image_to_s3(image_bytes, file_name):
    try:
        s3.put_object(Bucket=bucket_name, Key=file_name, Body=image_bytes, ContentType='image/jpeg')
        return f"https://{bucket_name}.s3.amazonaws.com/{file_name}"
    except (BotoCoreError, ClientError) as e:
        raise Exception(f"Error uploading image to S3: {e}")