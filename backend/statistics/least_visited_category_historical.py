from fastapi import FastAPI, HTTPException
from backend.database import collections  
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

persona_collection = collections["Persona_AR"]
tipo_producto_collection = collections["Tipo_Producto"]

app = FastAPI()

@app.get("/least-visited-category-historical/")
def get_least_visited_category_historical(empresa: str) -> Dict[str, Any]:
    """
    Obtiene la categoría de producto menos visitada históricamente desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing the least visited category historical data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats = collections["Estadisticas"].find_one({"_id": f"historical_categories:{empresa}"})
        if not stats:
            logger.error(f"Historical categories statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas")
        
        data = stats.get("least_visited", {})
        if not data or data.get("category") == "":
            return {"least_visited_category": None, "count": 0}
            
        return {"least_visited_category": data.get("category"), "count": data.get("count")}
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching historical least visited category for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching historical_categories.")