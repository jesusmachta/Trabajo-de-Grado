from fastapi import HTTPException
import logging
from backend.database import collections

# Configure logging
logger = logging.getLogger(__name__)

def validate_camera(id_camara: int, empresa: str):
    """
    Validates that a camera exists, belongs to the specified company, and is active.
    
    Args:
        id_camara: The ID of the camera to validate
        empresa: The company name the camera should belong to
    
    Raises:
        HTTPException: If the camera doesn't exist or isn't active
    """
    try:
        # Check if camera exists and is active
        camera = collections['Tipo_Producto_Zona_Camara'].find_one({
            "Id_Camara": id_camara,
            "empresa": empresa
        })
        
        if not camera:
            logger.warning(f"Camera {id_camara} not found for company {empresa}")
            raise HTTPException(
                status_code=404, 
                detail=f"Camera with ID {id_camara} not found for company {empresa}"
            )
            
        if not camera.get("isActive", False):
            logger.warning(f"Camera {id_camara} is disabled (isActive = False)")
            raise HTTPException(
                status_code=403, 
                detail="The camera is disabled (isActive = False)"
            )
            
        # If we reach here, the camera is valid and active
        logger.info(f"Camera {id_camara} for company {empresa} validated successfully")
        return True
        
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        # Log and convert any other exceptions to HTTPException
        logger.error(f"Error validating camera {id_camara}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error validating camera: {str(e)}") 