import random
from datetime import datetime, timedelta
from backend.database import collections
import asyncio
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def generate_heatmap_data(empresa, num_samples=10):
    """
    Generate random heatmap data for all categories for the specified company
    
    Args:
        empresa (str): Company ID to generate data for
        num_samples (int): Number of samples to generate per category
    """
    try:
        # Get categories from Tipo_Producto collection for this company
        category_collection = collections['Tipo_Producto']
        categories = list(category_collection.find({"empresa": empresa, "isActive": True}))
        
        if not categories:
            logger.warning(f"No active categories found for company '{empresa}'")
            return False
        
        heatmap_collection = collections['HeatMap']
        
        # Generate timestamp within the last 24 hours
        now = datetime.now()
        
        # Generate data for each category
        for category in categories:
            category_id = str(category.get('Tipo_Producto', 0))
            category_name = category.get('Categoria_Producto', 'Unknown')
            
            logger.info(f"Generating data for category {category_name} (ID: {category_id})")
            
            # Generate samples for this category
            for i in range(num_samples):
                # Random count between 5 and 25
                count = random.randint(5, 25)
                
                # Random timestamp in the last 24 hours
                random_hours = random.uniform(0, 24)
                timestamp = now - timedelta(hours=random_hours)
                
                # Create document
                heatmap_document = {
                    "location_id": category_id,  # Use category ID as location_id
                    "count": count,
                    "timestamp": timestamp,
                    "empresa": empresa
                }
                
                # Insert into collection
                heatmap_collection.insert_one(heatmap_document)
                
        # Add one entry for the entrance
        entrance_doc = {
            "location_id": "entrance",
            "count": random.randint(30, 50),  # Higher count for entrance
            "timestamp": now - timedelta(hours=random.uniform(0, 24)),
            "empresa": empresa
        }
        heatmap_collection.insert_one(entrance_doc)
        
        logger.info(f"Generated {num_samples} samples for each of {len(categories)} categories for company '{empresa}'")
        return True
    
    except Exception as e:
        logger.error(f"Error generating heatmap data: {str(e)}")
        return False

# Usage example: 
# asyncio.run(generate_heatmap_data("CataSus", 10)) 