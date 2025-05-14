from fastapi import HTTPException
from typing import Dict, Any, List
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

def get_top_successful_categories(empresa: str) -> List[Dict[str, Any]]:
    """
    Obtiene el top 3 de categorías más exitosas según emociones positivas (HAPPY count)
    desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        List of dictionaries containing top successful categories data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        stats_doc = collections["Estadisticas"].find_one({"_id": f"top_successful_categories:{empresa}"})
        if not stats_doc:
            logger.error(f"Top successful categories statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas de 'top_successful_categories' no encontradas para esta empresa")
        
        raw_counts = stats_doc.get("raw_counts")
        if not raw_counts or not isinstance(raw_counts, dict):
            logger.error(f"Raw counts not found or in incorrect format for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Datos de 'raw_counts' no encontrados o en formato incorrecto")
        
        category_happy_counts = []
        for category, counts in raw_counts.items():
            if isinstance(counts, dict) and "HAPPY" in counts:
                category_happy_counts.append({
                    "category": category,
                    "happy_count": counts.get("HAPPY", 0)
                })
            else:
                logger.warning(f"Categoría '{category}' en raw_counts no tiene conteo 'HAPPY' o formato incorrecto. Omitiendo.")
        
        category_happy_counts.sort(key=lambda x: x["happy_count"], reverse=True)
        
        top_categories_ranked = []
        for i, item in enumerate(category_happy_counts[:3]):
            top_categories_ranked.append({
                "category": item["category"],
                "happy_count": item["happy_count"],
                "rank": i + 1
            })
        
        # Asegurarse de que siempre se devuelvan exactamente 3 elementos
        while len(top_categories_ranked) < 3:
            top_categories_ranked.append({
                "rank": len(top_categories_ranked) + 1,
                "category": "Sin datos",
                "happy_count": 0
            })
            
        return top_categories_ranked
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error calculating top successful categories for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to calculate top categories: {str(e)}")