from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_top_successful_categories():
    """
    Calcula el top de categorías que generan más emociones positivas (HAPPY).
    :return: JSON con el top de categorías ordenadas por la cantidad de emociones HAPPY.
    """
    try:
        # Diccionario para contar las emociones HAPPY por categoría
        category_happy_counts = defaultdict(int)

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "emotions": 1})

        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            emotion = persona.get("emotions", "").upper()

            if categoria_producto and emotion == "HAPPY":
                category_happy_counts[categoria_producto] += 1

        # Ordenar las categorías por la cantidad de emociones HAPPY en orden descendente
        sorted_categories = sorted(category_happy_counts.items(), key=lambda x: x[1], reverse=True)

        # Formatear el resultado como un top
        top_categories = [
            {"rank": idx + 1, "category": category, "happy_count": count}
            for idx, (category, count) in enumerate(sorted_categories)
        ]

        return top_categories

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")