from datetime import datetime
from bson import ObjectId
from backend.database import collections
from fastapi import HTTPException
import logging

# Configure logging
logger = logging.getLogger(__name__)

def update_sensor_setting(empresa, tipo_producto_principal, tipo_producto_medium, tipo_producto_far):
    """
    Update a sensor setting document for a company.
    
    Args:
        empresa (str): Company name
        tipo_producto_principal (int): Main threshold value
        tipo_producto_medium (int): Medium threshold value
        tipo_producto_far (int): Far threshold value
        
    Returns:
        dict: Updated sensor setting document
    """
    try:
        # Validate thresholds
        if not (tipo_producto_far <= tipo_producto_medium <= tipo_producto_principal):
            raise ValueError("Los umbrales deben seguir la regla: Lejano <= Medio <= Principal")
        
        # Check if a document with the empresa exists
        existing_doc = collections['SensorsSettings'].find_one({
            "empresa": empresa
        })
        
        if not existing_doc:
            # If no document exists, create a new one
            from backend.sensorSettings.create_sensorsetting import create_sensor_setting
            doc_id = create_sensor_setting(empresa, tipo_producto_principal, tipo_producto_medium, tipo_producto_far)
            updated_doc = collections['SensorsSettings'].find_one({"_id": ObjectId(doc_id)})
        else:
            # Update existing document
            update_data = {
                "tipo_producto_principal": tipo_producto_principal,
                "tipo_producto_medium": tipo_producto_medium,
                "tipo_producto_far": tipo_producto_far,
                "updated_at": datetime.now()
            }
            
            result = collections['SensorsSettings'].update_one(
                {"empresa": empresa},
                {"$set": update_data}
            )
            
            if result.modified_count == 0 and result.matched_count == 0:
                raise HTTPException(status_code=404, detail=f"Sensor setting for company {empresa} not found")
            
            updated_doc = collections['SensorsSettings'].find_one({"empresa": empresa})
        
        # Convert ObjectId to string for JSON serialization
        updated_doc["_id"] = str(updated_doc["_id"])
        
        logger.info(f"Updated sensor setting for company {empresa}")
        return updated_doc
        
    except ValueError as ve:
        logger.error(f"Validation error updating sensor setting: {str(ve)}")
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Error updating sensor setting: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating sensor setting: {str(e)}") 