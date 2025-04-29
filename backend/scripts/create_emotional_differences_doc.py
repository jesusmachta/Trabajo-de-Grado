from pymongo import MongoClient
import os
import logging
from datetime import datetime
from backend.database import collections

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def create_emotional_differences_doc():
    """
    Creates the emotional_differences_by_category document in the Estadisticas collection
    with the new format that includes all emotions with their counts for each gender and category.
    """
    try:
        # Access collections directly from the imported collections dictionary
        stats_collection = collections["Estadisticas"]
        persona_collection = collections["Persona_AR"]  # Use the correct collection name from database.py
        
        logger.info("Checking for documents in Persona_AR collection...")
        doc_count = persona_collection.count_documents({})
        logger.info(f"Found {doc_count} documents in Persona_AR collection")
        
        if doc_count == 0:
            logger.error("No documents found in Persona_AR collection")
            return False
        
        logger.info("Calculating emotional differences by category...")
        
        # Create a dictionary to store emotion counts by category and gender
        category_emotion_counts = {}
        
        # Query all documents from Persona_AR collection
        personas = persona_collection.find({})
        processed_count = 0
        valid_count = 0
        
        # Count emotions by category and gender
        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            gender = persona.get("gender", "").lower()
            emotion = persona.get("emotions", "").upper()
            
            processed_count += 1
            if processed_count % 100 == 0:
                logger.info(f"Processed {processed_count} documents so far, valid: {valid_count}")
            
            if categoria_producto and gender in ["male", "female"] and emotion:
                valid_count += 1
                # Initialize category if it doesn't exist
                if categoria_producto not in category_emotion_counts:
                    category_emotion_counts[categoria_producto] = {
                        "male": {},
                        "female": {}
                    }
                
                # Initialize emotion count if it doesn't exist
                if emotion not in category_emotion_counts[categoria_producto][gender]:
                    category_emotion_counts[categoria_producto][gender][emotion] = 0
                
                # Increment the emotion count
                category_emotion_counts[categoria_producto][gender][emotion] += 1
        
        logger.info(f"Finished processing all {processed_count} documents, found {valid_count} valid entries")
        logger.info(f"Found data for {len(category_emotion_counts)} categories")
        
        # Log some sample data
        if category_emotion_counts:
            sample_category = list(category_emotion_counts.keys())[0]
            logger.info(f"Sample data for category '{sample_category}': {category_emotion_counts[sample_category]}")
        else:
            logger.warning("No emotional data was collected! Check your data in Persona_AR collection")
            logger.info("Creating an empty document as a placeholder")
            # Create a sample structure even if no data was found
            category_emotion_counts = {
                "Sample": {
                    "male": {"HAPPY": 0, "SAD": 0},
                    "female": {"HAPPY": 0, "SAD": 0}
                }
            }
        
        # Create the document
        emotional_differences_doc = {
            "_id": "emotional_differences_by_category",
            "description": "Emociones por género en cada categoría de productos",
            "data": category_emotion_counts,
            "last_updated": datetime.now().isoformat()
        }
        
        # Insert or update the document in the database
        result = stats_collection.replace_one(
            {"_id": "emotional_differences_by_category"},
            emotional_differences_doc,
            upsert=True
        )
        
        logger.info(f"Document replaced: {result.modified_count}, Document upserted: {result.upserted_id is not None}")
        logger.info("Successfully created/updated the document with the new format")
        
        return True
        
    except Exception as e:
        logger.error(f"Error creating document: {e}")
        logger.exception("Exception details:")
        return False

if __name__ == "__main__":
    logger.info("Starting the creation process...")
    success = create_emotional_differences_doc()
    if success:
        logger.info("Creation completed successfully")
    else:
        logger.error("Creation process failed")