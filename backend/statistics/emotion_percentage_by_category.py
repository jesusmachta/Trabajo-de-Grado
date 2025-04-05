from fastapi import FastAPI, HTTPException
from backend.database import collections  

persona_collection = collections["Persona_AR"]
tipo_producto_collection = collections["Tipo_Producto"]

app = FastAPI()

@app.get("/emotion-percentage-by-category/")
def get_emotion_percentage_by_category():
    """
    Calcula la relación entre emociones detectadas y categorías de producto en términos de porcentajes.
    :return: JSON con las categorías de producto y el porcentaje de emociones detectadas.
    """
    try:
        # Obtener todas las categorías disponibles de Tipo_Producto
        categorias = tipo_producto_collection.find({}, {"Categoria_Producto": 1, "_id": 0})
        categorias = [categoria["Categoria_Producto"] for categoria in categorias]

        # Diccionario para almacenar las emociones por categoría
        emotions_by_category = {categoria: {} for categoria in categorias}

        # Obtener todos los documentos de Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "emotions": 1})

        for persona in personas:
            category_name = persona.get("categoria_producto")  # Campo correcto en Persona_AR
            emotion = persona.get("emotions")  # Emoción única

            if category_name in emotions_by_category and emotion:
                # Contar la emoción para la categoría
                emotions_by_category[category_name][emotion] = (
                    emotions_by_category[category_name].get(emotion, 0) + 1
                )

        # Calcular el porcentaje de emociones por categoría
        emotion_percentages = {}
        for category_name, emotion_counts in emotions_by_category.items():
            total_emotions = sum(emotion_counts.values())
            if total_emotions > 0:
                emotion_percentages[category_name] = {
                    emotion: round((count / total_emotions) * 100, 2)
                    for emotion, count in emotion_counts.items()
                }
            else:
                # Si no hay emociones para la categoría, devolver un diccionario vacío
                emotion_percentages[category_name] = {}

        return emotion_percentages

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))