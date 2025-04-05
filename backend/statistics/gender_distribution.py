from datetime import datetime, timedelta
from backend.database import collections

persona_collection = collections["Persona_AR"]

def get_gender_distribution(period: str, date: str = None):
    """
    Calcula la distribución de visitantes por sexo en un período (semana o mes).
    :param period: Puede ser "week" o "month".
    :param date: Fecha inicial en formato "YYYY-MM-DD". Si no se especifica, se usa la fecha actual.
    :return: JSON con la distribución de visitantes por sexo.
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
            {"gender": 1}
        )

        # Diccionario para contar visitantes por sexo
        gender_distribution = {
            "male": 0,
            "female": 0
        }

        # Contar las visitas por sexo
        for persona in personas:
            gender = persona.get("gender", "").lower()
            if gender in gender_distribution:
                gender_distribution[gender] += 1

        return gender_distribution

    except ValueError as ve:
        raise ValueError(f"Error: {ve}")
    except Exception as e:
        raise Exception(f"Unexpected error: {e}")