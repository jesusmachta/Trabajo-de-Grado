from bson import ObjectId
from backend.database import collections
from fastapi import HTTPException
import logging

# Configure logging
logger = logging.getLogger(__name__)

def get_sensor_setting_by_empresa(empresa):
    """
    Get sensor setting by company name.
    
    Args:
        empresa (str): Company name
        
    Returns:
        dict: Sensor setting document
    """
    try:
        # Find the document for the specified company
        sensor_setting = collections['SensorsSettings'].find_one({
            "empresa": empresa
        })
        
        if not sensor_setting:
            # If no setting exists, return default values
            return {
                "empresa": empresa,
                "tipo_producto_principal": 15,  # Default high threshold
                "tipo_producto_medium": 10,     # Default medium threshold
                "tipo_producto_far": 5,         # Default low threshold
                "_id": None
            }
        
        # Convert ObjectId to string for JSON serialization
        sensor_setting["_id"] = str(sensor_setting["_id"])
        
        return sensor_setting
        
    except Exception as e:
        logger.error(f"Error retrieving sensor setting: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error retrieving sensor setting: {str(e)}") 