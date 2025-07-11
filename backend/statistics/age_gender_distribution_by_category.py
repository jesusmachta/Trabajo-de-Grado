from backend.database import collections
from collections import defaultdict
from fastapi import HTTPException
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

persona_collection = collections["Persona_AR"]

# Define age ranges
AGE_RANGES = {
    "18-25": (18, 25),
    "26-35": (26, 35),
    "36-45": (36, 45),
    "46-59": (46, 59),
    "60+": (60, float('inf')) # Use infinity for the upper bound of 60+
}

def get_age_range_label(low, high):
    """Determines the age range label based on low and high estimates."""
    # Use an average or midpoint for classification if needed, or use low edge.
    # Let's use the 'low' value primarily for categorization.
    age = low # Or use (low + high) // 2 if preferred

    for label, (min_age, max_age) in AGE_RANGES.items():
        if min_age <= age <= max_age:
            return label
    return None # Or a default label like "Other" if age doesn't fit defined ranges

def get_age_gender_distribution_by_category(empresa: str) -> Dict[str, Any]:
    """
    Obtiene las combinaciones de género y rango de edad más frecuentes por categoría de producto
    desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing age-gender distribution by category data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"age_gender_distribution_by_category:{empresa}"})
        if not stats:
            logger.error(f"Age-gender distribution by category statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching age-gender distribution by category for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching age-gender distribution by category: {str(e)}")
    