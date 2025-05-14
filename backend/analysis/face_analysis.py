from fastapi import HTTPException
import logging
import json
from backend.aws import analyze_image

# Configure logging
logger = logging.getLogger(__name__)

def analyze_image_with_aws(image_bytes: bytes) -> dict:
    """
    Analyzes an image using AWS Rekognition to detect faces and extract attributes.
    
    Args:
        image_bytes: The image bytes to analyze
    
    Returns:
        dict: The analysis results from AWS Rekognition
    
    Raises:
        HTTPException: If analysis fails
    """
    try:
        logger.info("Starting image analysis with AWS Rekognition")
        
        # Call AWS Rekognition service
        response = analyze_image(image_bytes)
        logger.info("AWS Rekognition analysis completed successfully")
        
        # Optionally save the results to a temporary file for debugging
        try:
            with open("analysis_result.json", "w") as f:
                json.dump(response, f)
            logger.debug("Analysis results saved to temporary file")
        except Exception as save_err:
            # Non-critical error, just log it
            logger.warning(f"Could not save analysis results to file: {save_err}")
        
        return response
        
    except Exception as e:
        logger.error(f"Error analyzing image with AWS Rekognition: {str(e)}")
        raise HTTPException(status_code=500, 
                           detail=f"Error analyzing image with AWS: {str(e)}") 