from datetime import datetime, timedelta
from fastapi import HTTPException
from typing import Optional, Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_most_visited_category(empresa: str, period: str, date: Optional[str] = None) -> Dict[str, Any]:
    """
    Obtiene la categoría de producto más visitada desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        period: Período de tiempo (day, week, month)
        date: Fecha específica (opcional)
        
    Returns:
        Dictionary containing the most visited category data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"most_visited_category:{empresa}"})
        if not stats:
            logger.error(f"Most visited category statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        # Determinar qué período usar
        if period == "day":
            date_key = date if date else datetime.now().strftime("%Y-%m-%d")
            data = stats.get("daily", {}).get(date_key)
        elif period == "week":
            if date:
                date_obj = datetime.strptime(date, "%Y-%m-%d")
            else:
                date_obj = datetime.now()
            monday = (date_obj - timedelta(days=date_obj.weekday())).strftime("%Y-%m-%d")
            data = stats.get("weekly", {}).get(monday)
        elif period == "month":
            if date:
                month_key = date[:7]
            else:
                month_key = datetime.now().strftime("%Y-%m")
            data = stats.get("monthly", {}).get(month_key)
        else:
            raise HTTPException(status_code=400, detail="Período no válido. Use 'day', 'week', o 'month'.")
            
        if not data:
            data = stats.get("category_counts", {})
            if data:
                most_cat = max(data.items(), key=lambda x: x[1]) if data else ("", 0)
                data = {"category": most_cat[0], "count": most_cat[1]}
            else:
                data = {"category": None, "count": 0}
                
        return {"most_visited_category": data.get("category"), "count": data.get("count")}
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching most visited category for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching most visited category: {str(e)}")
    
def get_available_most_visited_category_dates(empresa: str) -> Dict[str,list]: 
    stats = collections["Estadisticas"].find_one({"_id": f"most_visited_category:{empresa}"})
    if not stats:
        raise HTTPException(status_code=404, detail="Estadísticas no encontradas")

    daily = list(stats.get("daily", {}).keys())
    weekly = list(stats.get("weekly", {}).keys())
    monthly = list(stats.get("monthly", {}).keys())
    return{
        "daily": sorted(daily),
        "weekly": sorted(weekly),
        "monthly": sorted(monthly)
    }



