import random
from datetime import datetime, timedelta
from backend.database import collections
import asyncio
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def generate_heatmap_data(empresa, num_sensors=3):
    """
    Generate random heatmap data for sensors with assigned categories for the specified company
    
    Args:
        empresa (str): Company ID to generate data for
        num_sensors (int): Number of sensors to simulate
    """
    try:
        # Get categories from Tipo_Producto collection for this company
        category_collection = collections['Tipo_Producto']
        categories = list(category_collection.find({"empresa": empresa, "isActive": True}))
        
        if not categories:
            logger.warning(f"No active categories found for company '{empresa}'")
            return False
        
        # Get settings collection to check category assignments
        settings_collection = collections['SensorSettings']
        settings = settings_collection.find_one({"empresa": empresa})
        
        # If no settings exist, create default ones based on available categories
        if not settings and len(categories) >= 3:
            tipo_principal = categories[0]['Tipo_Producto']
            tipo_medium = categories[1]['Tipo_Producto'] if len(categories) > 1 else 0
            tipo_far = categories[2]['Tipo_Producto'] if len(categories) > 2 else 0
        else:
            tipo_principal = settings.get('tipo_producto_principal', 0)
            tipo_medium = settings.get('tipo_producto_medium', 0)
            tipo_far = settings.get('tipo_producto_far', 0)
        
        heatmap_collection = collections['HeatMap']
        
        # Generate data for simulated sensors
        for i in range(1, num_sensors + 1):
            sensor_id = f"sensor_{i}"
            
            # Random counts for each distance
            principal_count = random.randint(5, 25)
            medium_count = random.randint(3, 15)
            far_count = random.randint(1, 10)
            
            # Current timestamp
            timestamp = datetime.now()
            
            # Create document
            heatmap_document = {
                "sensor_id": sensor_id,
                "tipo_producto_principal": principal_count,
                "tipo_producto_medium": medium_count,
                "tipo_producto_far": far_count,
                "timestamp": timestamp,
                "empresa": empresa
            }
            
            # Check if document for this sensor already exists
            existing = heatmap_collection.find_one({"sensor_id": sensor_id, "empresa": empresa})
            
            if existing:
                # Update existing document
                heatmap_collection.replace_one({"_id": existing["_id"]}, heatmap_document)
                logger.info(f"Updated data for sensor {sensor_id}")
            else:
                # Insert new document
                heatmap_collection.insert_one(heatmap_document)
                logger.info(f"Created new data for sensor {sensor_id}")
        
        logger.info(f"Generated data for {num_sensors} sensors for company '{empresa}'")
        return True
    
    except Exception as e:
        logger.error(f"Error generating heatmap data: {str(e)}")
        return False

# Usage example: 
# asyncio.run(generate_heatmap_data("CataSus", 3)) 