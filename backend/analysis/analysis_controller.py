from fastapi import HTTPException, BackgroundTasks
import logging
from .image_processing import process_image_base64
from .camera_validation import validate_camera
from .image_upload import upload_enhanced_image
from .face_analysis import analyze_image_with_aws
from .analysis_db import save_analysis_to_db

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def handle_image_upload(background_tasks: BackgroundTasks, image_base64: str, id_camara: int, empresa: str):
    """
    Main controller function that orchestrates the entire image upload and analysis process.
    """
    try:
        logger.info("Starting image upload and analysis process")
        
        # Step 1: Validate camera is active
        validate_camera(id_camara, empresa)
        
        # Step 2: Process and enhance image
        enhanced_image_bytes = process_image_base64(image_base64)
        
        # Step 3: Upload enhanced image to S3
        current_time = upload_enhanced_image(enhanced_image_bytes, id_camara)
        
        # Step 4: Schedule background task for image analysis
        background_tasks.add_task(process_image_analysis, enhanced_image_bytes, id_camara, empresa)
        
        return {"message": "Image uploaded successfully, processing started."}
        
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions with their status codes
        logger.error(f"HTTP Exception in handle_image_upload: {http_exc.detail}")
        raise http_exc
    except Exception as e:
        # Log unexpected errors and raise an HTTPException
        logger.error(f"Unexpected error in handle_image_upload: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def process_image_analysis(image_bytes: bytes, id_camara: int, empresa: str):
    """
    Function to handle the image analysis process in the background.
    """
    try:
        # Step 1: Analyze image with AWS Rekognition
        analysis_results = analyze_image_with_aws(image_bytes)
        
        # Step 2: Save analysis results to database
        await save_analysis_to_db(analysis_results, id_camara, empresa)
        
    except Exception as e:
        logger.error(f"Error in background image analysis process: {e}")
        # Log the error but don't raise an exception since this runs in the background 