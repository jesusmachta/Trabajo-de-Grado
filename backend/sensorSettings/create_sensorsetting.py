from datetime import datetime
from bson import ObjectId
from backend.database import collections
from fastapi import HTTPException
import logging

# Configure logging
logger = logging.getLogger(__name__)

def create_sensor_setting(empresa, tipo_producto_principal, tipo_producto_medium, tipo_producto_far):
    """
    Create a sensor setting document for a company.
    
    Args:
        empresa (str): Company name
        tipo_producto_principal (int): Main threshold value
        tipo_producto_medium (int): Medium threshold value
        tipo_producto_far (int): Far threshold value
        
    Returns:
        str: ID of the created document
    """
    try:
        # Validate thresholds
        if not (tipo_producto_far <= tipo_producto_medium <= tipo_producto_principal):
            raise ValueError("Los umbrales deben seguir la regla: Lejano <= Medio <= Principal")
        
        # Check if a document with the same empresa already exists
        existing_doc = collections['SensorsSettings'].find_one({
            "empresa": empresa
        })
        
        if existing_doc:
            logger.info(f"Sensor setting for company {empresa} already exists. Returning existing ID.")
            return str(existing_doc["_id"])
        
        # Create sensor setting document
        sensor_setting = {
            "empresa": empresa,
            "tipo_producto_principal": tipo_producto_principal,
            "tipo_producto_medium": tipo_producto_medium,
            "tipo_producto_far": tipo_producto_far,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        }
        
        # Insert the document
        result = collections['SensorsSettings'].insert_one(sensor_setting)
        
        logger.info(f"Created sensor setting for company {empresa}")
        return str(result.inserted_id)
        
    except ValueError as ve:
        logger.error(f"Validation error creating sensor setting: {str(ve)}")
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Error creating sensor setting: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error creating sensor setting: {str(e)}") 