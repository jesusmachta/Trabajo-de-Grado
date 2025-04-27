from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_emotional_differences_by_category():
    """
    Calcula las emociones por género (male/female) en cada categoría de productos.
    :return: JSON con todas las emociones con sus conteos por género para cada categoría.
    """
    try:
        # Diccionario para contar emociones por categoría y género
        category_emotion_counts = defaultdict(lambda: {"male": defaultdict(int), "female": defaultdict(int)})

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "gender": 1, "emotions": 1})

        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            gender = persona.get("gender", "").lower()
            emotion = persona.get("emotions", "").upper()

            if categoria_producto and gender in ["male", "female"] and emotion:
                category_emotion_counts[categoria_producto][gender][emotion] += 1

        # Crear estructura de datos con todas las emociones y sus conteos para cada género y categoría
        emotional_differences = {}
        for category, gender_data in category_emotion_counts.items():
            emotional_differences[category] = {}
            for gender, emotions in gender_data.items():
                if emotions:
                    # Añadir todas las emociones con sus conteos
                    emotional_differences[category][gender] = emotions
                else:
                    emotional_differences[category][gender] = {}

        return emotional_differences

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")