import asyncio
import sys
import os

# Add the parent directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.heatmap.generate_sample_data import generate_heatmap_data

# Company ID to generate data for
EMPRESA = "CataSus"  # Change this to your company ID
NUM_SAMPLES = 10     # Number of samples per zone

if __name__ == "__main__":
    print(f"Generating heatmap data for company '{EMPRESA}'...")
    result = asyncio.run(generate_heatmap_data(EMPRESA, NUM_SAMPLES))
    
    if result:
        print(f"Successfully generated {NUM_SAMPLES} samples for each zone.")
    else:
        print("Failed to generate heatmap data.") 