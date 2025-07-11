from datetime import datetime, timedelta
from fastapi import HTTPException
from typing import Optional, Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_age_distribution(empresa: str, period: Optional[str] = None, date: Optional[str] = None, 
                         month: Optional[int] = None, year: Optional[int] = None) -> Dict[str, Any]:
    """
    Obtiene la distribución de visitantes por edad desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        period: Período de tiempo (week)
        date: Fecha específica para periodo semanal
        month: Mes específico (1-12) para filtrar por mes
        year: Año específico para filtrar por mes
        
    Returns:
        Dictionary containing age distribution data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"age_distribution:{empresa}"})
        if not stats:
            logger.error(f"Age distribution statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas de edad no encontradas")
        
        # Determinar qué datos retornar según los parámetros recibidos
        if period is None and month is None:
            return stats.get("overall", {})
            
        if period == "week" and date:
            try:
                date_obj = datetime.strptime(date, "%Y-%m-%d")
                monday = (date_obj - timedelta(days=date_obj.weekday())).strftime("%Y-%m-%d")
                if monday in stats.get("weekly", {}):
                    return stats["weekly"][monday]
                return {}
            except ValueError:
                raise HTTPException(status_code=400, detail="Formato de fecha inválido. Use YYYY-MM-DD")
                
        elif month is not None:
            if not 1 <= month <= 12:
                raise HTTPException(status_code=400, detail="El mes debe estar entre 1 y 12")
                
            if year is None:
                year = datetime.now().year
                
            month_key = f"{year}-{month:02d}"
            if month_key in stats.get("monthly", {}):
                return stats["monthly"][month_key]
            return {}
            
        return stats.get("overall", {})
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching age distribution for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching age distribution: {str(e)}")
    

def get_available_age_distribution_dates(empresa: str) -> Dict[str, list]:
    """
    Devuelve las semanas y meses disponibles para la distribución por edad.
    """
    stats = collections["Estadisticas"].find_one({"_id": f"age_distribution:{empresa}"})
    if not stats:
        raise HTTPException(status_code=404, detail="Estadísticas no encontradas")

    weekly = list(stats.get("weekly", {}).keys())
    monthly = list(stats.get("monthly", {}).keys())

    return {
        "weekly": sorted(weekly),
        "monthly": sorted(monthly)
    }
