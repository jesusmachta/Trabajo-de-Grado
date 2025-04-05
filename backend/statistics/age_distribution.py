from datetime import datetime, timedelta
from backend.database import collections

persona_collection = collections["Persona_AR"]

def get_age_distribution(period: str, date: str = None):
    """
    Calcula la distribución de visitantes por rango de edad en un período (semana o mes).
    :param period: Puede ser "week" o "month".
    :param date: Fecha inicial en formato "YYYY-MM-DD". Si no se especifica, se usa la fecha actual.
    :return: JSON con la distribución de visitantes por rango de edad.
    """
    try:
        # Validar el período
        if period not in ["week", "month"]:
            raise ValueError("Invalid period. Use 'week' or 'month'.")

        # Usar la fecha actual si no se proporciona
        if date:
            start_date = datetime.strptime(date, "%Y-%m-%d")
        else:
            start_date = datetime.now()

        # Calcular el rango de fechas según el período
        if period == "week":
            end_date = start_date + timedelta(days=6)
        elif period == "month":
            next_month = start_date.replace(day=28) + timedelta(days=4)  # Ir al próximo mes
            end_date = next_month.replace(day=1) - timedelta(days=1)  # Último día del mes actual

        # Filtrar los documentos de Persona_AR en el rango de fechas
        personas = persona_collection.find(
            {"date": {"$gte": start_date.strftime("%Y-%m-%d"), "$lte": end_date.strftime("%Y-%m-%d")}},
            {"age_range": 1}
        )

        # Diccionario para contar visitantes por rango de edad
        age_distribution = {
            "0-18": 0,
            "19-25": 0,
            "26-35": 0,
            "36-50": 0,
            "51+": 0
        }

        # Contar las visitas por rango de edad
        for persona in personas:
            age_range = persona.get("age_range", {})
            low = age_range.get("low")
            high = age_range.get("high")

            if low is not None and high is not None:
                if high <= 18:
                    age_distribution["0-18"] += 1
                elif 19 <= low <= 25:
                    age_distribution["19-25"] += 1
                elif 26 <= low <= 35:
                    age_distribution["26-35"] += 1
                elif 36 <= low <= 50:
                    age_distribution["36-50"] += 1
                elif low >= 51:
                    age_distribution["51+"] += 1

        return age_distribution

    except ValueError as ve:
        raise ValueError(f"Error: {ve}")
    except Exception as e:
        raise Exception(f"Unexpected error: {e}")