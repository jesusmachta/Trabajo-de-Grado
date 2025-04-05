from fastapi import FastAPI, HTTPException
from backend.database import collections  

persona_collection = collections["Persona_AR"]
tipo_producto_collection = collections["Tipo_Producto"]

app = FastAPI()

@app.get("/most-visited-category-historical/")
def get_most_visited_category_historical():
    """
    Calcula la categoría de producto más visitada utilizando todos los datos históricos.
    :return: JSON con la categoría de producto más visitada y el número de visitas.
    """
    try:
        # Obtener todas las categorías disponibles de Tipo_Producto
        categorias = tipo_producto_collection.find({}, {"Categoria_Producto": 1, "_id": 0})
        categorias = [categoria["Categoria_Producto"] for categoria in categorias]

        # Diccionario para contar las visitas por categoría
        category_counts = {categoria: 0 for categoria in categorias}

        # Obtener todos los documentos de Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1})

        # Contar las visitas por categoría
        for persona in personas:
            category_name = persona.get("categoria_producto")
            if category_name in category_counts:
                category_counts[category_name] += 1

        # Verificar si hay datos
        if all(count == 0 for count in category_counts.values()):
            return {"most_visited_category": None, "message": "No data available in the database."}

        # Encontrar la categoría más visitada
        most_visited_category = max(category_counts, key=category_counts.get)

        return {"most_visited_category": most_visited_category, "count": category_counts[most_visited_category]}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))