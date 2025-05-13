from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging
from typing import List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_cameras_with_details(empresa: str) -> List[Dict[str, Any]]:
    """
    Retrieves all cameras from Tipo_Producto_Zona_Camara and joins them
    with their corresponding product category from Tipo_Producto.
    
    Args:
        empresa (str): The company identifier to filter cameras
        
    Returns:
        List[Dict[str, Any]]: List of cameras with product details
        
    Raises:
        HTTPException: If there's an error fetching the cameras
    """
    try:
        # Use aggregation pipeline to join collections and filter by empresa
        pipeline = [
            {
                '$match': {
                    'empresa': empresa  # Filtrar por la empresa del usuario autenticado
                }
            },
            {
                '$lookup': {
                    'from': 'Tipo_Producto',
                    'let': {'tipoProducto': '$Tipo_Producto'},
                    'pipeline': [
                        {
                            '$match': {
                                '$expr': {
                                    '$and': [
                                        {'$eq': ['$Tipo_Producto', '$$tipoProducto']},
                                        {'$eq': ['$empresa', empresa]}  # Filtrar por empresa en Tipo_Producto
                                    ]
                                }
                            }
                        }
                    ],
                    'as': 'productDetails'
                }
            },
            {
                '$unwind': {
                    'path': '$productDetails',
                    'preserveNullAndEmptyArrays': True  # Mantener cámaras incluso si no hay coincidencias
                }
            },
            {
                '$project': {
                    '_id': 1,
                    'Id_Camara': 1,
                    'Tipo_Producto_Id': '$Tipo_Producto',
                    'Categoria_Producto': '$productDetails.Categoria_Producto',
                    'isActive': 1
                }
            }
        ]
        cameras_cursor = collections['Tipo_Producto_Zona_Camara'].aggregate(pipeline)
        cameras_list = []
        
        for camera in cameras_cursor:
            # Convert ObjectId to string for JSON serialization
            if '_id' in camera:
                camera['_id'] = str(camera['_id'])
            cameras_list.append(camera)

        return cameras_list
    except Exception as e:
        logger.error(f"Error fetching cameras: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching cameras: {str(e)}")

def get_camera_by_id(camera_id: str, empresa: str) -> Dict[str, Any]:
    """
    Retrieves a specific camera by its MongoDB ObjectId.
    
    Args:
        camera_id (str): The MongoDB ObjectId of the camera
        empresa (str): The company identifier
        
    Returns:
        Dict[str, Any]: The camera document with product details
        
    Raises:
        HTTPException: If camera not found or there's an error fetching the camera
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(camera_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")
            
        # Find the camera by ID and company
        camera = collections['Tipo_Producto_Zona_Camara'].find_one({
            "_id": object_id,
            "empresa": empresa
        })
        
        if not camera:
            raise HTTPException(
                status_code=404,
                detail=f"Camera with id {camera_id} not found or does not belong to your company."
            )
            
        # Get product type details
        product_type = None
        if 'Tipo_Producto' in camera:
            product_type = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": camera['Tipo_Producto'],
                "empresa": empresa
            })
            
        # Add category if product type found
        if product_type and 'Categoria_Producto' in product_type:
            camera['Categoria_Producto'] = product_type['Categoria_Producto']
            
        # Convert ObjectId to string for JSON serialization
        if '_id' in camera:
            camera['_id'] = str(camera['_id'])
            
        return camera
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching camera: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching camera: {str(e)}") 