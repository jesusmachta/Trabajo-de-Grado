from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from typing import Optional
from backend.database import collections  

persona_collection = collections["Persona_AR"]
tipo_producto_collection = collections["Tipo_Producto"]

app = FastAPI()

@app.get("/most-visited-category/")
def get_most_visited_category(period: str, date: Optional[str] = None):
    """
    Calcula la categoría de producto más visitada en un rango de tiempo (día, semana o mes).
    :param period: Puede ser "day", "week" o "month".
    :param date: Fecha inicial en formato "YYYY-MM-DD". Si no se especifica, se usa la fecha actual.
    :return: JSON con la categoría de producto más visitada.
    """
    try:
        # Validar el período
        if period not in ["day", "week", "month"]:
            raise HTTPException(status_code=400, detail="Invalid period. Use 'day', 'week', or 'month'.")

        # Usar la fecha actual si no se proporciona
        if date:
            start_date = datetime.strptime(date, "%Y-%m-%d")
        else:
            start_date = datetime.now()

        # Calcular el rango de fechas según el período
        if period == "day":
            end_date = start_date
        elif period == "week":
            end_date = start_date + timedelta(days=6)
        elif period == "month":
            next_month = start_date.replace(day=28) + timedelta(days=4)  # Ir al próximo mes
            end_date = next_month.replace(day=1) - timedelta(days=1)  # Último día del mes actual

        # Obtener todas las categorías disponibles de Tipo_Producto
        categorias = tipo_producto_collection.find({}, {"Categoria_Producto": 1, "_id": 0})
        categorias = [categoria["Categoria_Producto"] for categoria in categorias]

        # Diccionario para contar las visitas por categoría
        category_counts = {categoria: 0 for categoria in categorias}

        # Filtrar los documentos de Persona_AR en el rango de fechas
        personas = persona_collection.find(
            {"date": {"$gte": start_date.strftime("%Y-%m-%d"), "$lte": end_date.strftime("%Y-%m-%d")}},
            {"categoria_producto": 1}
        )

        # Contar las visitas por categoría
        for persona in personas:
            category_name = persona.get("categoria_producto")
            if category_name in category_counts:
                category_counts[category_name] += 1

        # Verificar si hay datos
        if all(count == 0 for count in category_counts.values()):
            return {"most_visited_category": None, "message": "No data available for the specified period."}

        # Encontrar la categoría más visitada
        most_visited_category = max(category_counts, key=category_counts.get)

        return {"most_visited_category": most_visited_category, "count": category_counts[most_visited_category]}

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use 'YYYY-MM-DD'.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))