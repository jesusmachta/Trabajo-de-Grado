import sys
import os

# Add the parent directory to the path so we can import from backend
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.database import collections

def verify_persona_ar_data():
    """Verify the sample data inserted into Persona_AR collection."""
    # Check how many documents were inserted for Fruteria Los Pomelos
    empresa = "Fruteria Los Pomelos"
    count = collections["Persona_AR"].count_documents({"empresa": empresa})
    print(f"Found {count} documents for '{empresa}' in Persona_AR collection")
    
    # Get a sample document to inspect
    sample = collections["Persona_AR"].find_one({"empresa": empresa, "id": {"$gte": 416}})
    if sample:
        print("\nSample document:")
        print(f"ID: {sample.get('id')}")
        print(f"Date: {sample.get('date')}")
        print(f"Time: {sample.get('time')}")
        print(f"Camera ID: {sample.get('id_camara')}")
        print(f"Category: {sample.get('categoria_producto')}")
        print(f"Gender: {sample.get('gender')}")
        print(f"Age Range: {sample.get('age_range')}")
        print(f"Emotion: {sample.get('emotions')}")
    else:
        print("No sample document found.")
    
    # Check statistics documents
    stat_names = [
        "peak_hours", "least_busy_hours", "most_busy_day", "least_busy_day",
        "most_visited_category", "least_visited_category", "historical_categories",
        "emotion_percentage_by_category", "most_frequent_emotions", "age_distribution",
        "gender_distribution", "emotion_comparison", "preferred_category_by_gender",
        "top_successful_categories", "emotional_differences_by_category",
        "age_gender_distribution_by_category"
    ]
    
    print("\nChecking statistics documents:")
    for stat in stat_names:
        doc = collections["Estadisticas"].find_one({"_id": f"{stat}:{empresa}"})
        if doc:
            print(f"  - {stat}: Found")
        else:
            print(f"  - {stat}: Not found")
    
    # Check processed documents record
    processed_doc = collections["Estadisticas"].find_one({"_id": f"processed_documents:{empresa}"})
    if processed_doc:
        print(f"\nProcessed documents tracking record found")
        print(f"Last ID processed: {processed_doc.get('last_id_processed')}")
        
        # Count processed IDs
        processed_ids = processed_doc.get("processed_ids", {})
        total_processed = sum(len(ids) for ids in processed_ids.values())
        print(f"Total IDs processed: {total_processed}")
    else:
        print("\nNo processed documents tracking record found")

if __name__ == "__main__":
    verify_persona_ar_data() 