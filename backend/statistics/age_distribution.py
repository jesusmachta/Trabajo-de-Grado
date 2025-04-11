from datetime import datetime, timedelta
from backend.database import collections

persona_collection = collections["Persona_AR"]

def get_age_distribution(period: str, date: str = None, end_date: str = None):
    """
    Calcula la distribución de visitantes por rango de edad en un período (semana o mes).
    :param period: Puede ser "week" o "month".
    :param date: Fecha inicial en formato "YYYY-MM-DD". Si no se especifica, se usa la fecha actual.
    :param end_date: Fecha final en formato "YYYY-MM-DD" (opcional). Solo se usa si period es "week".
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
            start_date = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            # Si es month, vamos al primer día del mes
            if period == "month":
                start_date = start_date.replace(day=1)

        # Calcular el rango de fechas según el período
        if period == "week":
            if end_date:
                # Si se proporciona una fecha final, usamos esa
                end_date_obj = datetime.strptime(end_date, "%Y-%m-%d")
                # Ajustar para incluir todo el último día
                end_date_obj = end_date_obj.replace(hour=23, minute=59, second=59, microsecond=999999)
            else:
                # Si no se proporciona fecha final, calculamos 6 días después de la fecha inicial
                end_date_obj = start_date + timedelta(days=6)
                # Ajustar para incluir todo el último día
                end_date_obj = end_date_obj.replace(hour=23, minute=59, second=59, microsecond=999999)
                
            # Si la fecha final es futura, limitarla a hoy
            if end_date_obj > datetime.now():
                end_date_obj = datetime.now().replace(hour=23, minute=59, second=59, microsecond=999999)
        
        elif period == "month":
            # Si es mes, vamos hasta el último día del mes o hasta hoy si estamos en el mes actual
            if start_date.month == datetime.now().month and start_date.year == datetime.now().year:
                # Estamos en el mes actual, vamos hasta hoy
                end_date_obj = datetime.now().replace(hour=23, minute=59, second=59, microsecond=999999)
            else:
                # Ir al último día del mes seleccionado
                # Obtener el primer día del siguiente mes
                if start_date.month == 12:
                    next_month = datetime(start_date.year + 1, 1, 1)
                else:
                    next_month = datetime(start_date.year, start_date.month + 1, 1)
                # Restar un día para obtener el último día del mes actual
                end_date_obj = next_month - timedelta(days=1)
                # Ajustar para incluir todo el último día
                end_date_obj = end_date_obj.replace(hour=23, minute=59, second=59, microsecond=999999)

        # Filtrar los documentos de Persona_AR en el rango de fechas
        print(f"Querying for age distribution: date range from {start_date} to {end_date_obj}")
        
        # Verificar si hay documentos en este rango de fechas
        count = persona_collection.count_documents({"date": {"$gte": start_date, "$lte": end_date_obj}})
        print(f"Found {count} documents in the date range")
        
        personas = persona_collection.find(
            {"date": {"$gte": start_date, "$lte": end_date_obj}},
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