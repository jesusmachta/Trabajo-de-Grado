from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_sensor(sensor_data: dict, empresa: str):
    """
    Creates a new sensor entry in Sensors collection.
    
    Args:
        sensor_data (dict): Data for the new sensor including id_sensor, tipo_producto_principal,
                           tipo_producto_medium, tipo_producto_far, isActive
        empresa (str): The company identifier
        
    Returns:
        dict: The created sensor document
    
    Raises:
        HTTPException: If sensor validation fails or other errors occur
    """
    required_fields = ["id_sensor", "tipo_producto_principal", "isActive"]
    if not all(field in sensor_data for field in required_fields):
        raise HTTPException(status_code=400, detail="Missing required fields: id_sensor, tipo_producto_principal, isActive")

    try:
        # Verify if the sensor ID already exists for the same company
        existing_sensor = collections['Sensors'].find_one({
            "id_sensor": sensor_data["id_sensor"],
            "empresa": empresa
        })
        if existing_sensor:
            raise HTTPException(
                status_code=409,
                detail=f"Sensor with id_sensor {sensor_data['id_sensor']} already exists for this company."
            )

        # Verify if the principal product type exists and belongs to the same company
        principal_product_type = collections['Tipo_Producto'].find_one({
            "Tipo_Producto": sensor_data["tipo_producto_principal"],
            "empresa": empresa
        })
        if not principal_product_type:
            raise HTTPException(
                status_code=404,
                detail=f"Tipo_Producto {sensor_data['tipo_producto_principal']} not found for this company."
            )

        # Check if the principal product type is already assigned to another sensor
        existing_sensor_with_principal = collections['Sensors'].find_one({
            "tipo_producto_principal": sensor_data["tipo_producto_principal"],
            "empresa": empresa
        })
        if existing_sensor_with_principal:
            raise HTTPException(
                status_code=409,
                detail=f"Tipo_Producto {sensor_data['tipo_producto_principal']} is already assigned as principal to another sensor."
            )

        # Validate medium product type if provided
        if "tipo_producto_medium" in sensor_data and sensor_data["tipo_producto_medium"] is not None:
            # Verify if the medium product type exists
            medium_product_type = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": sensor_data["tipo_producto_medium"],
                "empresa": empresa
            })
            if not medium_product_type:
                raise HTTPException(
                    status_code=404,
                    detail=f"Tipo_Producto medium {sensor_data['tipo_producto_medium']} not found for this company."
                )
                
            # Check if medium product type is already assigned to another sensor
            existing_sensor_with_medium = collections['Sensors'].find_one({
                "$or": [
                    {"tipo_producto_principal": sensor_data["tipo_producto_medium"]},
                    {"tipo_producto_medium": sensor_data["tipo_producto_medium"]},
                    {"tipo_producto_far": sensor_data["tipo_producto_medium"]}
                ],
                "empresa": empresa
            })
            if existing_sensor_with_medium:
                raise HTTPException(
                    status_code=409,
                    detail=f"Tipo_Producto {sensor_data['tipo_producto_medium']} is already assigned to another sensor."
                )

        # Validate far product type if provided
        if "tipo_producto_far" in sensor_data and sensor_data["tipo_producto_far"] is not None:
            # Verify if the far product type exists
            far_product_type = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": sensor_data["tipo_producto_far"],
                "empresa": empresa
            })
            if not far_product_type:
                raise HTTPException(
                    status_code=404,
                    detail=f"Tipo_Producto far {sensor_data['tipo_producto_far']} not found for this company."
                )
                
            # Check if far product type is already assigned to another sensor
            existing_sensor_with_far = collections['Sensors'].find_one({
                "$or": [
                    {"tipo_producto_principal": sensor_data["tipo_producto_far"]},
                    {"tipo_producto_medium": sensor_data["tipo_producto_far"]},
                    {"tipo_producto_far": sensor_data["tipo_producto_far"]}
                ],
                "empresa": empresa
            })
            if existing_sensor_with_far:
                raise HTTPException(
                    status_code=409,
                    detail=f"Tipo_Producto {sensor_data['tipo_producto_far']} is already assigned to another sensor."
                )

        # Add company field to the sensor document
        sensor_data["empresa"] = empresa

        # Insert the new sensor into the database
        insert_result = collections['Sensors'].insert_one(sensor_data)
        created_sensor = collections['Sensors'].find_one({"_id": insert_result.inserted_id})
        
        # Convert ObjectId to string for JSON serialization
        if created_sensor and '_id' in created_sensor:
            created_sensor['_id'] = str(created_sensor['_id'])
            
        return created_sensor
    except HTTPException as http_exc:
        raise http_exc  # Re-raise HTTP exceptions
    except Exception as e:
        logger.error(f"Error creating sensor: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error creating sensor: {str(e)}") 