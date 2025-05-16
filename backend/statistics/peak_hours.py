from datetime import datetime, timedelta
from fastapi import HTTPException
from typing import Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_peak_hours(empresa: str) -> Dict[str, Any]:
    """
    Obtiene las horas pico de los clientes por día de la semana desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing the peak hours data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        # Buscar el documento de estadísticas de esta empresa
        stats = collections["Estadisticas"].find_one({"_id": f"peak_hours:{empresa}"})
        if not stats:
            logger.error(f"Peak hours statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas para esta empresa")
        
        # Obtener los datos de horas pico
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching peak hours for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching peak hours.")