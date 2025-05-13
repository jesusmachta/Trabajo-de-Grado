from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_camera(camera_data: dict, empresa: str):
    """
    Creates a new camera entry in Tipo_Producto_Zona_Camara.
    
    Args:
        camera_data (dict): Data for the new camera including Id_Camara, Tipo_Producto, isActive
        empresa (str): The company identifier
        
    Returns:
        dict: The created camera document
    
    Raises:
        HTTPException: If camera with same ID exists, product type not found or other errors
    """
    required_fields = ["Id_Camara", "Tipo_Producto", "isActive"]
    if not all(field in camera_data for field in required_fields):
        raise HTTPException(status_code=400, detail="Missing required fields: Id_Camara, Tipo_Producto, isActive")

    try:
        # Verificar si el ID de la cámara ya existe para la misma empresa
        existing_camera = collections['Tipo_Producto_Zona_Camara'].find_one({
            "Id_Camara": camera_data["Id_Camara"],
            "empresa": empresa
        })
        if existing_camera:
            raise HTTPException(
                status_code=409,
                detail=f"Camera with Id_Camara {camera_data['Id_Camara']} already exists for this company."
            )

        # Verificar si el Tipo_Producto existe y pertenece a la misma empresa
        product_type = collections['Tipo_Producto'].find_one({
            "Tipo_Producto": camera_data["Tipo_Producto"],
            "empresa": empresa
        })
        if not product_type:
            raise HTTPException(
                status_code=404,
                detail=f"Tipo_Producto {camera_data['Tipo_Producto']} not found for this company."
            )

        # Agregar el campo empresa al documento de la cámara
        camera_data["empresa"] = empresa

        # Insertar la nueva cámara en la base de datos
        insert_result = collections['Tipo_Producto_Zona_Camara'].insert_one(camera_data)
        created_camera = collections['Tipo_Producto_Zona_Camara'].find_one({"_id": insert_result.inserted_id})
        
        # Convertir ObjectId a string para serialización JSON
        if created_camera and '_id' in created_camera:
            created_camera['_id'] = str(created_camera['_id'])
            
        return created_camera
    except HTTPException as http_exc:
        raise http_exc  # Re-raise HTTP exceptions
    except Exception as e:
        logger.error(f"Error creating camera: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error creating camera: {str(e)}") 