from fastapi import HTTPException
from typing import Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_preferred_category_by_gender(empresa: str) -> Dict[str, Any]:
    """
    Obtiene las categorías de productos preferidas por género desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing preferred category by gender data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"preferred_category_by_gender:{empresa}"})
        if not stats:
            logger.error(f"Preferred category by gender statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        raw_counts = stats.get("raw_counts", {})
        if not raw_counts.get("Male") and not raw_counts.get("Female"):
            logger.info(f"No hay datos en preferred_category_by_gender para empresa '{empresa}', recalculando...")
            from backend.statistics.incremental_stats import recalculate_all_statistics
            recalculate_all_statistics(empresa=empresa)
            stats = collections["Estadisticas"].find_one({"_id": f"preferred_category_by_gender:{empresa}"})
            if not stats:
                logger.error(f"No se pudieron recalcular las estadísticas para empresa '{empresa}'")
                raise HTTPException(status_code=500, detail="No se pudieron recalcular las estadísticas")
        
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching preferred category by gender for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching preferred category by gender: {str(e)}")