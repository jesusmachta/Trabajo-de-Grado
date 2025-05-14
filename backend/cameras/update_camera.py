from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging
from typing import Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def update_camera(camera_id: str, update_data: Dict[str, Any], empresa: str) -> Dict[str, Any]:
    """
    Updates an existing camera's status or associated fields.
    
    Args:
        camera_id (str): The MongoDB ObjectId of the camera to update
        update_data (Dict[str, Any]): The fields to update (isActive, Id_Camara, Tipo_Producto)
        empresa (str): The company identifier
        
    Returns:
        Dict[str, Any]: The updated camera document
        
    Raises:
        HTTPException: If camera not found, validation errors or other errors
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(camera_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")

        # Validate input data
        if not isinstance(update_data, dict):
            raise HTTPException(status_code=400, detail="Invalid request body format.")
        
        # Validate optional fields
        is_active = update_data.get("isActive")
        id_camara = update_data.get("Id_Camara")
        tipo_producto = update_data.get("Tipo_Producto")

        if is_active is not None and not isinstance(is_active, bool):
            raise HTTPException(status_code=400, detail="'isActive' must be a boolean.")

        if id_camara is not None and not isinstance(id_camara, int):
            raise HTTPException(status_code=400, detail="'Id_Camara' must be an integer.")

        if tipo_producto is not None and not isinstance(tipo_producto, int):
            raise HTTPException(status_code=400, detail="'Tipo_Producto' must be an integer.")

        # Verify if the camera belongs to the company
        camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": object_id, "empresa": empresa})
        if not camera:
            raise HTTPException(
                status_code=404,
                detail=f"Camera with id {camera_id} not found or does not belong to your company."
            )

        # Check if the new `Id_Camara` already exists for the same company
        if id_camara is not None:
            existing_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"Id_Camara": id_camara, "empresa": empresa})
            if existing_camera and str(existing_camera["_id"]) != camera_id:
                raise HTTPException(
                    status_code=409, 
                    detail=f"Camera with Id_Camara {id_camara} already exists for this company."
                )

        # Check if the `Tipo_Producto` belongs to the same company
        if tipo_producto is not None:
            product_type = collections['Tipo_Producto'].find_one({"Tipo_Producto": tipo_producto, "empresa": empresa})
            if not product_type:
                raise HTTPException(
                    status_code=404, 
                    detail=f"Tipo_Producto {tipo_producto} not found for this company."
                )

        # Build the fields to update
        update_fields = {}
        if is_active is not None:
            update_fields["isActive"] = is_active
        if id_camara is not None:
            update_fields["Id_Camara"] = id_camara
        if tipo_producto is not None:
            update_fields["Tipo_Producto"] = tipo_producto

        # Update the camera
        update_result = collections['Tipo_Producto_Zona_Camara'].update_one(
            {"_id": object_id, "empresa": empresa},
            {"$set": update_fields}
        )

        if update_result.matched_count == 0:
            raise HTTPException(
                status_code=404,
                detail=f"Camera with id {camera_id} not found or does not belong to your company."
            )

        # Get the updated camera
        updated_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": object_id, "empresa": empresa})
        
        # Convert ObjectId to string for JSON serialization
        if updated_camera and '_id' in updated_camera:
            updated_camera['_id'] = str(updated_camera['_id'])
            
        return updated_camera

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error updating camera: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating camera: {str(e)}") 