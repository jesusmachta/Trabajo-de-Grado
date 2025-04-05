from fastapi import FastAPI, HTTPException
from backend.database import collections  

persona_collection = collections["Persona_AR"]
tipo_producto_collection = collections["Tipo_Producto"]

app = FastAPI()

@app.get("/most-frequent-emotions/")
def get_most_frequent_emotions():
    """
    Calcula las emociones más frecuentes detectadas por categoría de producto utilizando todos los datos históricos.
    :return: JSON con las categorías de producto y sus emociones más frecuentes.
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

        # Encontrar la emoción más frecuente por categoría
        most_frequent_emotions = {}
        for category_name, emotion_counts in emotions_by_category.items():
            if emotion_counts:
                most_frequent_emotion = max(emotion_counts, key=emotion_counts.get)
                most_frequent_emotions[category_name] = {
                    "emotion": most_frequent_emotion,
                    "count": emotion_counts[most_frequent_emotion],
                }
            else:
                # Si no hay emociones para la categoría, devolver None
                most_frequent_emotions[category_name] = {
                    "emotion": None,
                    "count": 0
                }

        return most_frequent_emotions

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))