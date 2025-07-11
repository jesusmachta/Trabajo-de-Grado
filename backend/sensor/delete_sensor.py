from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def delete_sensor(sensor_id: str, empresa: str):
    """
    Deletes a sensor entry from the Sensors collection.
    
    Args:
        sensor_id (str): The MongoDB ObjectId of the sensor to delete
        empresa (str): The company identifier
        
    Returns:
        dict: A success message
        
    Raises:
        HTTPException: If sensor not found or there's an error during deletion
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(sensor_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")
        
        # Find the sensor to ensure it exists and belongs to the company
        sensor = collections['Sensors'].find_one({
            "_id": object_id,
            "empresa": empresa
        })
        
        if not sensor:
            raise HTTPException(
                status_code=404,
                detail=f"Sensor with id {sensor_id} not found or does not belong to your company."
            )
            
        # Delete the sensor
        delete_result = collections['Sensors'].delete_one({
            "_id": object_id,
            "empresa": empresa
        })
        
        if delete_result.deleted_count == 0:
            raise HTTPException(
                status_code=500,
                detail="Failed to delete the sensor."
            )
            
        return {
            "success": True,
            "message": f"Sensor with id {sensor_id} deleted successfully."
        }
    except HTTPException as http_exc:
        raise http_exc  # Re-raise HTTP exceptions
    except Exception as e:
        logger.error(f"Error deleting sensor: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deleting sensor: {str(e)}") 