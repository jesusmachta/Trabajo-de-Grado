from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def delete_camera(camera_id: str, empresa: str) -> None:
    """
    Deletes a camera entry by its MongoDB ObjectId.
    
    Args:
        camera_id (str): The MongoDB ObjectId of the camera to delete
        empresa (str): The company identifier
        
    Returns:
        None
        
    Raises:
        HTTPException: If camera not found or there's an error deleting the camera
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(camera_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")

        # Verify if the camera belongs to the company
        camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": object_id, "empresa": empresa})
        if not camera:
            raise HTTPException(
                status_code=404,
                detail=f"Camera with id {camera_id} not found or does not belong to your company."
            )

        # Delete the camera
        delete_result = collections['Tipo_Producto_Zona_Camara'].delete_one({"_id": object_id, "empresa": empresa})

        if delete_result.deleted_count == 0:
            raise HTTPException(
                status_code=404,
                detail=f"Camera with id {camera_id} not found or does not belong to your company."
            )

        # Return None on successful deletion
        return None

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error deleting camera: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deleting camera: {str(e)}") 