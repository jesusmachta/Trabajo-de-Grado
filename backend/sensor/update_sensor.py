from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def update_sensor(sensor_id: str, update_data: dict, empresa: str):
    """
    Updates an existing sensor entry in the Sensors collection.
    
    Args:
        sensor_id (str): The MongoDB ObjectId of the sensor to update
        update_data (dict): Data for updating the sensor, may include id_sensor, 
                           tipo_producto_principal, tipo_producto_medium, tipo_producto_far, isActive
        empresa (str): The company identifier
        
    Returns:
        dict: The updated sensor document
    
    Raises:
        HTTPException: If sensor not found, validation fails, or other errors
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(sensor_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")
        
        # Find the sensor by ID and company to ensure it exists
        current_sensor = collections['Sensors'].find_one({
            "_id": object_id,
            "empresa": empresa
        })
        
        if not current_sensor:
            raise HTTPException(
                status_code=404,
                detail=f"Sensor with id {sensor_id} not found or does not belong to your company."
            )

        # Check if the sensor ID is being updated and if the new ID doesn't conflict
        if "id_sensor" in update_data and update_data["id_sensor"] != current_sensor["id_sensor"]:
            existing_sensor = collections['Sensors'].find_one({
                "id_sensor": update_data["id_sensor"],
                "empresa": empresa,
                "_id": {"$ne": object_id}  # Exclude current sensor
            })
            
            if existing_sensor:
                raise HTTPException(
                    status_code=409,
                    detail=f"Sensor with id_sensor {update_data['id_sensor']} already exists for this company."
                )

        # Validate and check product types
        # Principal product type validation
        if "tipo_producto_principal" in update_data:
            if update_data["tipo_producto_principal"] is not None:
                # Check if the principal product type exists
                principal_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": update_data["tipo_producto_principal"],
                    "empresa": empresa
                })
                if not principal_product:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Tipo_Producto {update_data['tipo_producto_principal']} not found for this company."
                    )
                
                # Check if the product type is already assigned to another sensor
                if update_data["tipo_producto_principal"] != current_sensor.get("tipo_producto_principal"):
                    existing_sensor = collections['Sensors'].find_one({
                        "tipo_producto_principal": update_data["tipo_producto_principal"],
                        "empresa": empresa,
                        "_id": {"$ne": object_id}
                    })
                    if existing_sensor:
                        raise HTTPException(
                            status_code=409,
                            detail=f"Tipo_Producto {update_data['tipo_producto_principal']} is already assigned to another sensor."
                        )
            else:
                # Principal product type cannot be null
                raise HTTPException(
                    status_code=400,
                    detail="tipo_producto_principal cannot be null."
                )

        # Medium product type validation
        if "tipo_producto_medium" in update_data:
            if update_data["tipo_producto_medium"] is not None:
                # Check if the medium product type exists
                medium_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": update_data["tipo_producto_medium"],
                    "empresa": empresa
                })
                if not medium_product:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Tipo_Producto medium {update_data['tipo_producto_medium']} not found for this company."
                    )
                
                # Check if the medium product type is already assigned to another sensor
                if update_data["tipo_producto_medium"] != current_sensor.get("tipo_producto_medium"):
                    existing_sensor = collections['Sensors'].find_one({
                        "$or": [
                            {"tipo_producto_principal": update_data["tipo_producto_medium"]},
                            {"tipo_producto_medium": update_data["tipo_producto_medium"]},
                            {"tipo_producto_far": update_data["tipo_producto_medium"]}
                        ],
                        "empresa": empresa,
                        "_id": {"$ne": object_id}
                    })
                    if existing_sensor:
                        raise HTTPException(
                            status_code=409,
                            detail=f"Tipo_Producto {update_data['tipo_producto_medium']} is already assigned to another sensor."
                        )

        # Far product type validation
        if "tipo_producto_far" in update_data:
            if update_data["tipo_producto_far"] is not None:
                # Check if the far product type exists
                far_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": update_data["tipo_producto_far"],
                    "empresa": empresa
                })
                if not far_product:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Tipo_Producto far {update_data['tipo_producto_far']} not found for this company."
                    )
                
                # Check if the far product type is already assigned to another sensor
                if update_data["tipo_producto_far"] != current_sensor.get("tipo_producto_far"):
                    existing_sensor = collections['Sensors'].find_one({
                        "$or": [
                            {"tipo_producto_principal": update_data["tipo_producto_far"]},
                            {"tipo_producto_medium": update_data["tipo_producto_far"]},
                            {"tipo_producto_far": update_data["tipo_producto_far"]}
                        ],
                        "empresa": empresa,
                        "_id": {"$ne": object_id}
                    })
                    if existing_sensor:
                        raise HTTPException(
                            status_code=409,
                            detail=f"Tipo_Producto {update_data['tipo_producto_far']} is already assigned to another sensor."
                        )

        # Update the sensor document
        update_result = collections['Sensors'].update_one(
            {"_id": object_id, "empresa": empresa},
            {"$set": update_data}
        )
        
        if update_result.modified_count == 0:
            raise HTTPException(
                status_code=404,
                detail="No changes were made to the sensor."
            )
            
        # Get the updated sensor document
        updated_sensor = collections['Sensors'].find_one({"_id": object_id})
        if updated_sensor:
            updated_sensor['_id'] = str(updated_sensor['_id'])
            
        return updated_sensor
    except HTTPException as http_exc:
        raise http_exc  # Re-raise HTTP exceptions
    except Exception as e:
        logger.error(f"Error updating sensor: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating sensor: {str(e)}") 