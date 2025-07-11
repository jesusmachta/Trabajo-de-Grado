from fastapi import HTTPException
import logging
import base64
import io
import numpy as np
from PIL import Image
import cv2

# Configure logging
logger = logging.getLogger(__name__)

def process_image_base64(image_base64: str) -> bytes:
    """
    Processes and enhances an image from base64 encoding.
    
    Args:
        image_base64: Base64 encoded image string
    
    Returns:
        bytes: Enhanced image bytes
    
    Raises:
        HTTPException: If image processing fails
    """
    try:
        logger.info("Starting image processing from base64")
        
        # Validate input
        if not image_base64:
            raise HTTPException(status_code=400, detail="Empty image data provided")
            
        # Convert base64 to bytes
        image_bytes = base64.b64decode(image_base64)
        
        # Convert bytes to PIL image
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert("RGB")  # Ensure RGB format
        
        # Convert to JPEG bytes for OpenCV processing
        jpeg_buffer = io.BytesIO()
        image.save(jpeg_buffer, format="JPEG")
        jpeg_bytes = jpeg_buffer.getvalue()
        
        # Process with OpenCV
        enhanced_image_bytes = enhance_image_with_opencv(jpeg_bytes)
        
        logger.info("Image processing completed successfully")
        return enhanced_image_bytes
        
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        # Log and convert other exceptions to HTTPException
        logger.error(f"Error processing image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")

def enhance_image_with_opencv(image_bytes: bytes) -> bytes:
    """
    Enhances an image using OpenCV techniques.
    
    Args:
        image_bytes: Raw image bytes
    
    Returns:
        bytes: Enhanced image bytes
    """
    logger.info("Starting image enhancement with OpenCV")
    
    # Convert bytes to OpenCV format
    np_image = np.frombuffer(image_bytes, np.uint8)
    cv_image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
    
    # Convert BGR to RGB (OpenCV loads images in BGR by default)
    cv_image_rgb = cv2.cvtColor(cv_image, cv2.COLOR_BGR2RGB)
    
    # Scale image if needed (currently set to 1.0 = no scaling)
    scale_factor = 1.0
    if scale_factor != 1.0:
        new_width = int(cv_image_rgb.shape[1] * scale_factor)
        new_height = int(cv_image_rgb.shape[0] * scale_factor)
        cv_image_rgb = cv2.resize(cv_image_rgb, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
        logger.info(f"Image resized to {new_width}x{new_height}")
    
    # LAB color space processing for better enhancement
    lab_image = cv2.cvtColor(cv_image_rgb, cv2.COLOR_RGB2LAB)
    l_channel, a_channel, b_channel = cv2.split(lab_image)
    
    # Apply CLAHE to luminosity channel
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced_l_channel = clahe.apply(l_channel)
    
    # Apply bilateral filter to reduce noise while preserving edges
    enhanced_l_channel = cv2.bilateralFilter(enhanced_l_channel, 5, 50, 50)
    
    # Adjust contrast
    alpha = 1.1  # Contrast (1.0 = no change)
    beta = 0     # Brightness (0 = no change)
    enhanced_l_channel = cv2.convertScaleAbs(enhanced_l_channel, alpha=alpha, beta=beta)
    
    # Enhance sharpness
    kernel = np.array([[-0.5, -0.5, -0.5], 
                      [-0.5,  5.0, -0.5], 
                      [-0.5, -0.5, -0.5]])
    enhanced_l_channel = cv2.filter2D(enhanced_l_channel, -1, kernel)
    
    # Reconstruct LAB image with enhanced luminosity
    enhanced_lab_image = cv2.merge([enhanced_l_channel, a_channel, b_channel])
    
    # Convert back to RGB
    enhanced_rgb_image = cv2.cvtColor(enhanced_lab_image, cv2.COLOR_LAB2RGB)
    
    # Convert to BGR for saving with OpenCV
    enhanced_bgr_image = cv2.cvtColor(enhanced_rgb_image, cv2.COLOR_RGB2BGR)
    
    # Encode to JPEG with high quality
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 95]
    _, enhanced_image_bytes = cv2.imencode('.jpg', enhanced_bgr_image, encode_param)
    
    logger.info("Image enhancement with OpenCV completed")
    return enhanced_image_bytes.tobytes() 