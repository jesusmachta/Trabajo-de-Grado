import os
import boto3
from botocore.exceptions import BotoCoreError, ClientError
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logger = logging.getLogger(__name__)

# Use environment variables for AWS credentials
rekognition = boto3.client(
    'rekognition', 
    region_name='us-west-2',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

s3 = boto3.client(
    's3', 
    region_name='us-west-2',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

s3_resource = boto3.resource(
    's3', 
    region_name='us-west-2',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY')
)

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

def upload_image_to_s3(image_bytes, file_name, acl=None):
    """
    Upload an image to S3. The acl parameter is optional.
    For camera images (analysis), don't use ACL.
    For profile pictures, try with ACL but fall back to no ACL if the bucket doesn't support ACLs.
    """
    try:
        logger.info(f"Uploading image to S3 bucket {bucket_name} with key {file_name}")
        
        # Create parameters for put_object
        put_params = {
            'Bucket': bucket_name, 
            'Key': file_name, 
            'Body': image_bytes, 
            'ContentType': 'image/jpeg'
        }
        
        # If ACL is provided, try to use it, but be prepared for it to fail
        if acl:
            try:
                logger.info(f"Attempting to set ACL to {acl}")
                put_params['ACL'] = acl
                s3.put_object(**put_params)
            except Exception as e:
                if 'AccessControlListNotSupported' in str(e):
                    # If ACL is not supported, retry without it
                    logger.warning(f"ACL not supported for bucket, uploading without ACL: {e}")
                    del put_params['ACL']
                    s3.put_object(**put_params)
                else:
                    # Re-raise other exceptions
                    raise
        else:
            # If no ACL specified, just upload normally
            s3.put_object(**put_params)
        
        s3_url = f"https://{bucket_name}.s3.amazonaws.com/{file_name}"
        logger.info(f"Image successfully uploaded to {s3_url}")
        return s3_url
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error uploading to S3: {e}")
        raise Exception(f"Error uploading image to S3: {e}")

def configure_cors_for_s3_bucket():
    """
    Configure CORS settings for the S3 bucket to allow web access from any origin.
    This is required for accessing profile pictures and other assets from the web application.
    """
    cors_configuration = {
        'CORSRules': [
            {
                'AllowedHeaders': ['*'],
                'AllowedMethods': ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'],
                'AllowedOrigins': ['*'],  # For development; narrow this to specific domains in production
                'ExposeHeaders': ['ETag'],
                'MaxAgeSeconds': 3000
            }
        ]
    }
    
    try:
        logger.info(f"Configuring CORS for S3 bucket {bucket_name}")
        s3.put_bucket_cors(Bucket=bucket_name, CORSConfiguration=cors_configuration)
        logger.info(f"CORS configuration applied successfully to bucket {bucket_name}")
        
        # Try to make the bucket public-read via policy, but don't fail if it doesn't work
        try:
            bucket_policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "PublicReadForGetBucketObjects",
                        "Effect": "Allow",
                        "Principal": "*",
                        "Action": "s3:GetObject",
                        "Resource": f"arn:aws:s3:::{bucket_name}/*"
                    }
                ]
            }
            s3.put_bucket_policy(Bucket=bucket_name, Policy=str(bucket_policy).replace("'", '"'))
            logger.info(f"Bucket policy set to allow public read access")
        except Exception as policy_error:
            logger.warning(f"Could not set bucket policy: {policy_error}")
            
        return True
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error configuring CORS for S3: {e}")
        # This is non-fatal, we'll log but not raise an exception
        return False

# Remove the automatic CORS configuration on import to avoid potential issues
# The app.py file will call this function explicitly