from fastapi import HTTPException
import logging
from datetime import datetime
# from backend.aws import upload_image_to_s3

# Configure logging
logger = logging.getLogger(__name__)

def upload_enhanced_image(enhanced_image_bytes: bytes, id_camara: int) -> str:
    """
    Uploads an enhanced image to Amazon S3 storage.
    
    Args:
        enhanced_image_bytes: The processed image bytes to upload
        id_camara: The camera ID to associate with the image
    
    Returns:
        str: The timestamp when the image was uploaded (format: YYYYMMDD_HHMMSS)
    
    Raises:
        HTTPException: If the upload fails
    """
    try:
        logger.info(f"Uploading enhanced image for camera {id_camara} to S3")
        
        # Generate filename with timestamp and camera ID
        current_time = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"{current_time}_{id_camara}.jpeg"
        
        # Upload to S3 - Commented out as requested
        # s3_url = upload_image_to_s3(enhanced_image_bytes, file_name)
        
        # logger.info(f"Image uploaded successfully to S3: {s3_url}")
        
        # Return timestamp for reference
        return current_time
        
    except Exception as e:
        logger.error(f"Error uploading image to S3: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading image to S3: {str(e)}") 