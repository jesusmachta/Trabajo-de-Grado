from fastapi import HTTPException
from typing import Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_emotional_differences_by_category(empresa: str) -> Dict[str, Any]:
    """
    Obtiene las emociones por género en cada categoría de productos desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing emotional differences by category data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"emotional_differences_by_category:{empresa}"})
        if not stats:
            logger.error(f"Emotional differences by category statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching emotional differences by category for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching emotional differences by category: {str(e)}")