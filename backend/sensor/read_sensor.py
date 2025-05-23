from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
import logging
from typing import List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_sensors_with_details(empresa: str) -> List[Dict[str, Any]]:
    """
    Retrieves all sensors from Sensors and joins them
    with their corresponding product categories from Tipo_Producto.
    
    Args:
        empresa (str): The company identifier to filter sensors
        
    Returns:
        List[Dict[str, Any]]: List of sensors with product details
        
    Raises:
        HTTPException: If there's an error fetching the sensors
    """
    try:
        # Get all sensors for the company
        sensors_cursor = collections['Sensors'].find({"empresa": empresa})
        sensors_list = []
        
        for sensor in sensors_cursor:
            sensor_with_details = sensor.copy()
            
            # Get principal product details
            if 'tipo_producto_principal' in sensor and sensor['tipo_producto_principal'] is not None:
                principal_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": sensor['tipo_producto_principal'],
                    "empresa": empresa
                })
                if principal_product:
                    sensor_with_details['principal_category_name'] = principal_product.get('Categoria_Producto', 'Desconocido')
            
            # Get medium product details
            if 'tipo_producto_medium' in sensor and sensor['tipo_producto_medium'] is not None:
                medium_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": sensor['tipo_producto_medium'],
                    "empresa": empresa
                })
                if medium_product:
                    sensor_with_details['medium_category_name'] = medium_product.get('Categoria_Producto', 'Desconocido')
            
            # Get far product details
            if 'tipo_producto_far' in sensor and sensor['tipo_producto_far'] is not None:
                far_product = collections['Tipo_Producto'].find_one({
                    "Tipo_Producto": sensor['tipo_producto_far'],
                    "empresa": empresa
                })
                if far_product:
                    sensor_with_details['far_category_name'] = far_product.get('Categoria_Producto', 'Desconocido')
            
            # Convert ObjectId to string for JSON serialization
            if '_id' in sensor_with_details:
                sensor_with_details['_id'] = str(sensor_with_details['_id'])
            
            sensors_list.append(sensor_with_details)

        # Sort by sensor ID for consistent display
        return sorted(sensors_list, key=lambda x: x.get('id_sensor', 0))
    except Exception as e:
        logger.error(f"Error fetching sensors: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching sensors: {str(e)}")

def get_sensor_by_id(sensor_id: str, empresa: str) -> Dict[str, Any]:
    """
    Retrieves a specific sensor by its MongoDB ObjectId.
    
    Args:
        sensor_id (str): The MongoDB ObjectId of the sensor
        empresa (str): The company identifier
        
    Returns:
        Dict[str, Any]: The sensor document with product details
        
    Raises:
        HTTPException: If sensor not found or there's an error fetching the sensor
    """
    try:
        # Validate ObjectId format
        try:
            object_id = ObjectId(sensor_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB ObjectId format.")
            
        # Find the sensor by ID and company
        sensor = collections['Sensors'].find_one({
            "_id": object_id,
            "empresa": empresa
        })
        
        if not sensor:
            raise HTTPException(
                status_code=404,
                detail=f"Sensor with id {sensor_id} not found or does not belong to your company."
            )
            
        sensor_with_details = sensor.copy()
        
        # Get principal product details
        if 'tipo_producto_principal' in sensor and sensor['tipo_producto_principal'] is not None:
            principal_product = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": sensor['tipo_producto_principal'],
                "empresa": empresa
            })
            if principal_product:
                sensor_with_details['principal_category_name'] = principal_product.get('Categoria_Producto', 'Desconocido')
        
        # Get medium product details
        if 'tipo_producto_medium' in sensor and sensor['tipo_producto_medium'] is not None:
            medium_product = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": sensor['tipo_producto_medium'],
                "empresa": empresa
            })
            if medium_product:
                sensor_with_details['medium_category_name'] = medium_product.get('Categoria_Producto', 'Desconocido')
        
        # Get far product details
        if 'tipo_producto_far' in sensor and sensor['tipo_producto_far'] is not None:
            far_product = collections['Tipo_Producto'].find_one({
                "Tipo_Producto": sensor['tipo_producto_far'],
                "empresa": empresa
            })
            if far_product:
                sensor_with_details['far_category_name'] = far_product.get('Categoria_Producto', 'Desconocido')
            
        # Convert ObjectId to string for JSON serialization
        if '_id' in sensor_with_details:
            sensor_with_details['_id'] = str(sensor_with_details['_id'])
            
        return sensor_with_details
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching sensor: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching sensor: {str(e)}")

def get_available_categories(empresa: str, exclude_sensor_id: str = None) -> Dict[str, List[Dict[str, Any]]]:
    """
    Gets categories available for assignment to sensors (not already assigned to other sensors).
    
    Args:
        empresa (str): The company identifier
        exclude_sensor_id (str, optional): Sensor ID to exclude from checking (for update operations)
        
    Returns:
        Dict[str, List[Dict[str, Any]]]: Dictionary with available categories
        
    Raises:
        HTTPException: If there's an error fetching the categories
    """
    try:
        # Get all categories for the company
        all_categories = list(collections['Tipo_Producto'].find({"empresa": empresa}))
        
        # Get all assigned categories from sensors
        assigned_query = {"empresa": empresa}
        if exclude_sensor_id:
            assigned_query["_id"] = {"$ne": ObjectId(exclude_sensor_id)}
            
        sensors = list(collections['Sensors'].find(assigned_query))
        
        # Collect all assigned category IDs
        assigned_categories = set()
        for sensor in sensors:
            if 'tipo_producto_principal' in sensor and sensor['tipo_producto_principal'] is not None:
                assigned_categories.add(sensor['tipo_producto_principal'])
            if 'tipo_producto_medium' in sensor and sensor['tipo_producto_medium'] is not None:
                assigned_categories.add(sensor['tipo_producto_medium'])
            if 'tipo_producto_far' in sensor and sensor['tipo_producto_far'] is not None:
                assigned_categories.add(sensor['tipo_producto_far'])
        
        # Filter out assigned categories from all categories
        available_categories = []
        for category in all_categories:
            if category['Tipo_Producto'] not in assigned_categories:
                category['_id'] = str(category['_id'])
                available_categories.append(category)
        
        return {
            "available_categories": available_categories
        }
    except Exception as e:
        logger.error(f"Error fetching available categories: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching available categories: {str(e)}") 