from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from typing import Optional
from backend.database import collections  

collection = collections["Persona_AR"]

app = FastAPI()

@app.get("/least-busy-hours/")
def get_least_busy_hours(start_date: Optional[str] = None):
    """
    Calcula la hora menos concurrida por día de la semana para una semana específica.
    Si no se especifica el lunes, se calculan las horas menos concurridas de la semana actual.
    :param start_date: Fecha inicial (lunes) en formato "YYYY-MM-DD".
    :return: JSON con el día de la semana y la hora menos concurrida.
    """
    try:
        if start_date:
            # Convertir la fecha inicial a un objeto datetime
            start_date_obj = datetime.strptime(start_date, "%Y-%m-%d")
        else:
            # Calcular el lunes de la semana actual
            today = datetime.now()
            start_date_obj = today - timedelta(days=today.weekday())  # Restar días para llegar al lunes

        least_busy_hours = {}

        # Iterar sobre los días de la semana
        for i in range(7):
            current_date = start_date_obj + timedelta(days=i)
            day_of_week = current_date.strftime("%A")  # Obtener el día de la semana (Monday, Tuesday, etc.)

            # Filtrar los documentos de la colección por la fecha actual
            personas = collection.find({"date": current_date.strftime("%Y-%m-%d")}, {"time": 1})

            # Contar las personas por hora
            hourly_count = [0] * 24
            for persona in personas:
                time_str = persona.get("time")
                if not time_str:
                    continue  

                hour = int(time_str.split(":")[0])
                if 6 <= hour <= 23:  # Contar solo las horas entre 6 AM y 11 PM
                    hourly_count[hour] += 1

            # Verificar si hay datos para ese día, si no hay entonces es 0
            if sum(hourly_count) == 0:
                least_busy_hours[day_of_week] = 0  
            else:
                # Encontrar la hora con menos personas 
                min_count = min(hourly_count)
                least_busy_hour = [h for h, count in enumerate(hourly_count) if count == min_count]
                least_busy_hours[day_of_week] = least_busy_hour[0] if least_busy_hour else 0

        return least_busy_hours

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use 'YYYY-MM-DD'.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))