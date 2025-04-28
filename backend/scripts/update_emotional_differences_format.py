from pymongo import MongoClient
import os
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# MongoDB connection string (use environment variable or update with your connection details)
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017/")
DB_NAME = os.environ.get("DB_NAME", "store_sense_db")

def update_emotional_differences_format():
    """
    Updates the emotional_differences_by_category document in the Estadisticas collection
    to use the new format that includes all emotions with their counts for each gender and category.
    """
    try:
        # Connect to MongoDB
        client = MongoClient(MONGO_URI)
        db = client[DB_NAME]
        stats_collection = db["Estadisticas"]
        
        # Get the current document
        current_doc = stats_collection.find_one({"_id": "emotional_differences_by_category"})
        
        if not current_doc:
            logger.error("Document 'emotional_differences_by_category' not found in Estadisticas collection")
            return False
        
        logger.info("Found document to update. Converting to new format...")
        
        # Check if the document already has raw_counts field
        if "raw_counts" not in current_doc:
            logger.error("Document does not have 'raw_counts' field, cannot convert to new format")
            return False
        
        # Create the new document structure using the raw_counts as the primary data
        raw_counts = current_doc.get("raw_counts", {})
        
        # Update the document to use the raw_counts as the main data
        stats_collection.update_one(
            {"_id": "emotional_differences_by_category"},
            {
                "$set": {
                    "data": raw_counts,
                    "description": "Emociones por género en cada categoría de productos",
                    "last_updated": datetime.now().isoformat()
                }
            }
        )
        
        logger.info("Successfully updated the document to the new format")
        return True
        
    except Exception as e:
        logger.error(f"Error updating document: {e}")
        return False
    finally:
        if 'client' in locals():
            client.close()

if __name__ == "__main__":
    logger.info("Starting the update process...")
    success = update_emotional_differences_format()
    if success:
        logger.info("Update completed successfully")
    else:
        logger.error("Update process failed") 