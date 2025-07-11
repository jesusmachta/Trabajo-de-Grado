from fastapi import HTTPException
from backend.database import collections  
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

def get_most_frequent_emotions(empresa: str) -> Dict[str, Any]:
    """
    Obtiene las emociones más frecuentes desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing most frequent emotions data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"most_frequent_emotions:{empresa}"})
        if not stats:
            logger.error(f"Most frequent emotions statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching most frequent emotions for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching most frequent emotions.")