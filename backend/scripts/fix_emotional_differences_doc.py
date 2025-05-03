import logging
from datetime import datetime
from backend.database import collections

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def fix_emotional_differences_doc():
    """
    Fixes the emotional_differences_by_category document format by removing raw_counts
    and ensuring the data structure is correct.
    """
    try:
        logger.info("Starting to fix emotional differences document format...")
        
        # Get current document
        stats = collections["Estadisticas"].find_one({"_id": "emotional_differences_by_category"})
        if not stats:
            logger.warning("Document not found, creating new one...")
            stats = {
                "_id": "emotional_differences_by_category",
                "description": "Emociones por género en cada categoría de productos",
                "data": {},
                "last_updated": datetime.utcnow().isoformat()
            }
        
        # If we have raw_counts, we need to process them into the correct format
        if "raw_counts" in stats:
            logger.info("Found raw_counts, converting to correct format...")
            raw_counts = stats["raw_counts"]
            data = {}
            
            for category, gender_data in raw_counts.items():
                data[category] = {
                    "male": {},
                    "female": {}
                }
                for gender, emotions in gender_data.items():
                    gender_key = gender.lower()
                    data[category][gender_key] = emotions
        else:
            # If no raw_counts, keep existing data or use empty dict
            data = stats.get("data", {})
        
        # Create new document with correct format
        new_doc = {
            "_id": "emotional_differences_by_category",
            "description": "Emociones por género en cada categoría de productos",
            "data": data,
            "last_updated": datetime.utcnow().isoformat()
        }
        
        # Replace the document
        result = collections["Estadisticas"].replace_one(
            {"_id": "emotional_differences_by_category"},
            new_doc,
            upsert=True
        )
        
        logger.info("Document updated successfully")
        logger.info(f"Modified: {result.modified_count}, Upserted: {result.upserted_id is not None}")
        
        # Verify the update
        updated_doc = collections["Estadisticas"].find_one({"_id": "emotional_differences_by_category"})
        if "raw_counts" not in updated_doc:
            logger.info("Verification successful: raw_counts field removed")
        else:
            logger.error("Verification failed: raw_counts field still present")
        
        return True
    
    except Exception as e:
        logger.error(f"Error fixing emotional differences document: {e}")
        return False

if __name__ == "__main__":
    success = fix_emotional_differences_doc()
    if success:
        logger.info("Successfully fixed emotional differences document")
    else:
        logger.error("Failed to fix emotional differences document") 