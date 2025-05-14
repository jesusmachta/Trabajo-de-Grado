from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from typing import Optional, Dict, Any
from backend.database import collections
import logging

logger = logging.getLogger(__name__)

collection = collections["Persona_AR"]

app = FastAPI()

@app.get("/most-busy-day/")
def get_most_busy_day(start_date: Optional[str] = None):
    """
    Encuentra el día de la semana con el mayor flujo de personas.
    Si no se especifica una fecha, se calcula desde el mismo día de la semana anterior hasta el día actual.
    :param start_date: Fecha inicial en formato "YYYY-MM-DD".
    :return: JSON con el día de la semana con el mayor flujo de personas.
    """
    try:
        if start_date:
            # Convertir la fecha inicial a un objeto datetime
            start_date_obj = datetime.strptime(start_date, "%Y-%m-%d")
        else:
            # Calcular desde el mismo día de la semana anterior
            today = datetime.now()
            start_date_obj = today - timedelta(days=7)  # Exactamente una semana anterior

        # Calcular el último día a revisar (hoy)
        end_date_obj = datetime.now()

        # Diccionario para almacenar el conteo total de personas por día
        daily_counts = {}

        # Inicializar todos los días de la semana con valor 0
        for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]:
            daily_counts[day] = 0

        # Iterar sobre los días desde el inicio hasta el día actual
        current_date = start_date_obj
        while current_date <= end_date_obj:
            day_of_week = current_date.strftime("%A")  # Obtener el día de la semana (Monday, Tuesday, etc.)

            # Filtrar los documentos de la colección por la fecha actual
            personas = collection.find({"date": current_date.strftime("%Y-%m-%d")}, {"time": 1})

            # Contar el total de personas para el día actual
            total_count = 0
            for persona in personas:
                total_count += 1

            # Actualizar el conteo en el diccionario (acumular por día de semana)
            daily_counts[day_of_week] += total_count

            # Pasar al siguiente día
            current_date += timedelta(days=1)

        # Si todos los días tienen conteo 0, proporcionar un valor predeterminado
        if all(count == 0 for count in daily_counts.values()):
            return {"most_busy_day": "No data available"}

        # Encontrar el día con el mayor flujo de personas
        most_busy_day = max(daily_counts, key=daily_counts.get)

        return {"most_busy_day": most_busy_day}

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use 'YYYY-MM-DD'.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def get_most_busy_day(empresa: str) -> Dict[str, Any]:
    """
    Obtiene el día más concurrido de la semana desde la colección Estadisticas.
    
    Args:
        empresa: Identificador de la empresa para la que se obtienen las estadísticas
        
    Returns:
        Dictionary containing the most busy day data
        
    Raises:
        HTTPException: If statistics not found or error fetching data
    """
    try:
        # Buscar el documento de estadísticas de esta empresa
        stats = collections["Estadisticas"].find_one({"_id": f"most_busy_day:{empresa}"})
        if not stats:
            logger.error(f"Most busy day statistics not found for company '{empresa}'")
            raise HTTPException(status_code=404, detail="Estadísticas no encontradas para esta empresa")
        
        # Obtener los datos del día más concurrido
        data = stats.get("data", {})
        return data
    except HTTPException as http_exc:
        # Re-raise HTTP exceptions
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching most busy day for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching most busy days.")