from pymongo import MongoClient
import random
from datetime import datetime, timedelta
import sys
import os
from bson.objectid import ObjectId

# Add the parent directory to the path so we can import from backend
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.database import collections
from backend.statistics.incremental_stats import update_statistics_on_insert, initialize_statistics

# Constants
EMPRESA = "Fruteria Los Pomelos"
START_ID = 416
NUM_DOCUMENTS = 150
START_DATE = "2025-05-24"  # Saturday
END_DATE = "2025-05-25"    # Sunday
START_TIME = "07:00:00"    # 7:00 AM
END_TIME = "22:00:00"      # 10:00 PM
MIN_AGE = 7
MAX_AGE = 80
AGE_DIFFERENCE = 5

# Emotions and categories
EMOTIONS = ["HAPPY", "SAD", "ANGRY", "CONFUSED", "SURPRISED", "CALM", "DISGUSTED", "FEAR"]
CATEGORIES = {
    "Vegetales": 1,  # id_camara = 1 for Vegetales
    "Frutas": 2      # id_camara = 2 for Frutas
}
GENDERS = ["Male", "Female"]

def random_time():
    """Generate a random time between START_TIME and END_TIME."""
    start_h, start_m, start_s = map(int, START_TIME.split(':'))
    end_h, end_m, end_s = map(int, END_TIME.split(':'))
    
    # Convert to seconds
    start_seconds = start_h * 3600 + start_m * 60 + start_s
    end_seconds = end_h * 3600 + end_m * 60 + end_s
    
    # Generate random time in seconds
    random_seconds = random.randint(start_seconds, end_seconds)
    
    # Convert back to HH:MM:SS
    h = random_seconds // 3600
    m = (random_seconds % 3600) // 60
    s = random_seconds % 60
    
    return f"{h:02d}:{m:02d}:{s:02d}"

def random_date():
    """Generate a random date between START_DATE and END_DATE."""
    start_date = datetime.strptime(START_DATE, "%Y-%m-%d")
    end_date = datetime.strptime(END_DATE, "%Y-%m-%d")
    
    delta = (end_date - start_date).days
    random_days = random.randint(0, delta)
    
    return (start_date + timedelta(days=random_days)).strftime("%Y-%m-%d")

def random_age_range():
    """Generate a random age range with the specified difference."""
    low = random.randint(MIN_AGE, MAX_AGE - AGE_DIFFERENCE)
    high = low + AGE_DIFFERENCE
    
    return {"low": low, "high": high}

def get_next_id():
    """Get the next available ID for Persona_AR."""
    # Find the highest ID currently in use
    last_doc = collections["Persona_AR"].find_one(
        {"empresa": EMPRESA},
        sort=[("id", -1)]  # Sort by id in descending order
    )
    
    if last_doc and "id" in last_doc:
        return last_doc["id"] + 1
    
    return START_ID

def generate_sample_data():
    """Generate and insert sample data into Persona_AR collection."""
    # Get current count and next available ID
    current_count = collections["Persona_AR"].count_documents({"empresa": EMPRESA})
    next_id = get_next_id()
    
    print(f"Current count for '{EMPRESA}': {current_count}")
    print(f"Next ID: {next_id}")
    
    # Calculate remaining documents to insert
    remaining = NUM_DOCUMENTS - current_count
    
    if remaining <= 0:
        print(f"Already have {current_count} documents, no need to insert more.")
        return
    
    print(f"Generating {remaining} more documents for {EMPRESA}...")
    
    # Initialize statistics for the company if they don't exist
    print("Initializing statistics for the company...")
    initialize_statistics(EMPRESA)
    
    documents_inserted = 0
    for i in range(remaining):
        # Select random category and associated camera id
        category = random.choice(list(CATEGORIES.keys()))
        id_camara = CATEGORIES[category]
        
        # Create document
        document = {
            "_id": ObjectId(),  # Generate a new ObjectId
            "id": next_id + i,
            "date": random_date(),
            "time": random_time(),
            "id_camara": id_camara,
            "categoria_producto": category,
            "gender": random.choice(GENDERS),
            "age_range": random_age_range(),
            "emotions": random.choice(EMOTIONS),
            "empresa": EMPRESA
        }
        
        # Insert into Persona_AR collection
        result = collections["Persona_AR"].insert_one(document)
        documents_inserted += 1
        
        # Update statistics for this document
        update_statistics_on_insert(document)
        
        if documents_inserted % 10 == 0:
            print(f"Inserted {documents_inserted} documents...")
    
    print(f"Successfully inserted {documents_inserted} documents into Persona_AR collection")
    print(f"Total documents for {EMPRESA}: {current_count + documents_inserted}")
    print(f"Statistics have been updated for {EMPRESA}")

if __name__ == "__main__":
    generate_sample_data() 