import boto3
from botocore.exceptions import BotoCoreError, ClientError
import logging

# Configure logging
logger = logging.getLogger(__name__)

rekognition = boto3.client('rekognition', region_name='us-west-2')
s3 = boto3.client('s3', region_name='us-west-2')
bucket_name = 'tesislospomelos'

def analyze_image(image_bytes):
    try:
        logger.info("Sending image to AWS Rekognition for analysis")
        response = rekognition.detect_faces(
            Image={'Bytes': image_bytes},
            Attributes=['ALL']
        )
        logger.info(f"Rekognition detected {len(response.get('FaceDetails', []))} faces")
        return response
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error in AWS Rekognition: {e}")
        raise Exception(f"Error processing image: {e}")

def upload_image_to_s3(image_bytes, file_name):
    try:
        logger.info(f"Uploading image to S3 bucket {bucket_name} with key {file_name}")
        s3.put_object(
            Bucket=bucket_name, 
            Key=file_name, 
            Body=image_bytes, 
            ContentType='image/jpeg'
        )
        s3_url = f"https://{bucket_name}.s3.amazonaws.com/{file_name}"
        logger.info(f"Image successfully uploaded to {s3_url}")
        return s3_url
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error uploading to S3: {e}")
        raise Exception(f"Error uploading image to S3: {e}")