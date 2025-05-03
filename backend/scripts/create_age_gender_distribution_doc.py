import logging
from datetime import datetime
from backend.database import collections
from collections import defaultdict

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Define age ranges
AGE_RANGES = {
    "18-25": (18, 25),
    "26-35": (26, 35),
    "36-45": (36, 45),
    "46-59": (46, 59),
    "60+": (60, float('inf'))  # Use infinity for the upper bound of 60+
}

def get_age_range_label(low, high):
    """Determines the age range label based on low and high estimates."""
    age = low  # Use the low value for categorization
    for label, (min_age, max_age) in AGE_RANGES.items():
        if min_age <= age <= max_age:
            return label
    return None

def create_age_gender_distribution_doc():
    """
    Creates or updates the age-gender distribution by category statistics document.
    This document contains the distribution of visitors by age range and gender for each product category.
    """
    try:
        logger.info("Starting creation of age-gender distribution by category statistics...")
        
        # Get all documents from Persona_AR
        personas = collections["Persona_AR"].find({}, {
            "categoria_producto": 1,
            "gender": 1,
            "age_range": 1
        })
        
        # Initialize counters
        processed_count = 0
        valid_count = 0
        
        # Structure: { "Category": { "Gender": { "AgeRangeLabel": count } } }
        category_distribution_counts = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
        
        # Process each document
        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            gender = persona.get("gender", "")  # Keep original capitalization (Male/Female)
            age_range_data = persona.get("age_range", {})
            
            processed_count += 1
            if processed_count % 100 == 0:
                logger.info(f"Processed {processed_count} documents so far, valid: {valid_count}")
            
            low = age_range_data.get("low")
            high = age_range_data.get("high")
            
            if categoria_producto and gender in ["Male", "Female"] and low is not None and high is not None:
                age_range_label = get_age_range_label(low, high)
                if age_range_label:
                    valid_count += 1
                    category_distribution_counts[categoria_producto][gender][age_range_label] += 1
        
        logger.info(f"Finished processing all {processed_count} documents, found {valid_count} valid entries")
        
        # Format the data for storage
        formatted_data = {}
        raw_counts = {}
        
        for category, gender_data in category_distribution_counts.items():
            category_list = []
            raw_counts[category] = {}
            
            for gender, age_range_counts in gender_data.items():
                raw_counts[category][gender] = dict(age_range_counts)
                for age_range_label, count in age_range_counts.items():
                    if count > 0:  # Only include if count is positive
                        category_list.append({
                            "gender": gender,
                            "age_range": age_range_label,
                            "count": count
                        })
            
            # Sort by count descending
            category_list.sort(key=lambda x: x["count"], reverse=True)
            if category_list:  # Only add category if it has data
                formatted_data[category] = category_list
        
        # Create or update the statistics document
        stats_doc = {
            "_id": "age_gender_distribution_by_category",
            "description": "Combinaciones de género y edad más frecuentes por categoría",
            "data": formatted_data,
            "raw_counts": raw_counts,
            "last_updated": datetime.utcnow().isoformat()
        }
        
        # Update or insert the document
        collections["Estadisticas"].replace_one(
            {"_id": "age_gender_distribution_by_category"},
            stats_doc,
            upsert=True
        )
        
        logger.info("Successfully created/updated age-gender distribution by category statistics")
        logger.info(f"Found data for {len(formatted_data)} categories")
        
    except Exception as e:
        logger.error(f"Error creating age-gender distribution document: {e}")
        raise

if __name__ == "__main__":
    create_age_gender_distribution_doc() 