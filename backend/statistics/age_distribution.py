from datetime import datetime, timedelta
from backend.database import collections

persona_collection = collections["Persona_AR"]

def get_age_distribution(period: str = None, date: str = None, end_date: str = None, month: int = None, year: int = None):
    """
    Calcula la distribución de visitantes por edad promedio (average of high and low from age_range).
    
    :param period: Puede ser "week" para análisis semanal.
    :param date: Fecha inicial en formato "YYYY-MM-DD" para period="week".
    :param end_date: Fecha final en formato "YYYY-MM-DD" para period="week".
    :param month: Número de mes (1-12) para análisis mensual.
    :param year: Año para análisis mensual (default=current year).
    :return: JSON con la distribución de visitantes por edad promedio.
    """
    try:
        query = {}
        
        # Manejo del filtrado por período (month o week)
        if month is not None:
            # Filtrar por mes específico
            if not 1 <= month <= 12:
                raise ValueError("Month should be between 1 and 12")
                
            # Si no se proporciona un año, usar el año actual
            if year is None:
                year = datetime.now().year
                
            # Formatear el mes y año como cadenas para la búsqueda
            month_str = f"{month:02d}"
            year_str = str(year)
            
            # Buscar documentos donde el campo date comienza con "YYYY-MM"
            query["date"] = {"$regex": f"^{year_str}-{month_str}"}
            
            print(f"Filtering by month: {year_str}-{month_str}")
            
        elif period == "week" and date:
            # Validar fecha inicial
            try:
                start_date_obj = datetime.strptime(date, "%Y-%m-%d")
            except ValueError:
                raise ValueError("Start date should be in YYYY-MM-DD format")
                
            # Procesar fecha final si se proporciona, o calcular 7 días después
            if end_date:
                try:
                    end_date_obj = datetime.strptime(end_date, "%Y-%m-%d")
                except ValueError:
                    raise ValueError("End date should be in YYYY-MM-DD format")
                    
                # Verificar que end_date no sea más de 7 días después de date
                days_diff = (end_date_obj - start_date_obj).days
                if days_diff > 7 or days_diff < 0:
                    raise ValueError("End date should be between 1 and 7 days after start date")
            else:
                # Si no se proporciona end_date, usar 7 días después
                end_date_obj = start_date_obj + timedelta(days=6)
                
            # Formatear para la búsqueda (las fechas están almacenadas como strings)
            start_date_str = start_date_obj.strftime("%Y-%m-%d")
            end_date_str = end_date_obj.strftime("%Y-%m-%d")
            
            # Buscar documentos donde la fecha está en el rango
            query["date"] = {"$gte": start_date_str, "$lte": end_date_str}
            
            print(f"Filtering by week: from {start_date_str} to {end_date_str}")
        
        # Verificar si hay documentos que cumplan con el filtro
        count = persona_collection.count_documents(query)
        print(f"Found {count} documents matching the filter")
        
        if count == 0:
            return {"message": "No data found for the specified parameters"}
        
        # Recuperar documentos que cumplan con el filtro
        personas = persona_collection.find(query, {"age_range": 1})
        
        # Inicializar diccionario para contar edades promedio
        age_distribution = {}
        
        # Procesar cada documento y calcular la edad promedio
        for persona in personas:
            age_range = persona.get("age_range", {})
            low = age_range.get("low")
            high = age_range.get("high")
            
            if low is not None and high is not None:
                # Calcular el promedio y redondear a entero
                avg_age = round((low + high) / 2)
                
                # Incrementar el contador para esta edad
                if avg_age in age_distribution:
                    age_distribution[avg_age] += 1
                else:
                    age_distribution[avg_age] = 1
        
        # Ordenar el diccionario por edad
        sorted_distribution = dict(sorted(age_distribution.items()))
        
        return sorted_distribution

    except ValueError as ve:
        raise ValueError(f"Error: {ve}")
    except Exception as e:
        raise Exception(f"Unexpected error: {e}")