from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_emotional_differences_by_category():
    """
    Calcula las emociones predominantes por género (male/female) en cada categoría de productos.
    :return: JSON con las emociones predominantes por género para cada categoría.
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

        # Determinar la emoción predominante por género para cada categoría
        emotional_differences = {}
        for category, gender_data in category_emotion_counts.items():
            emotional_differences[category] = {}
            for gender, emotions in gender_data.items():
                if emotions:
                    predominant_emotion = max(emotions, key=emotions.get)
                    emotional_differences[category][gender] = {
                        "predominant_emotion": predominant_emotion,
                        "count": emotions[predominant_emotion]
                    }
                else:
                    emotional_differences[category][gender] = {
                        "predominant_emotion": None,
                        "count": 0
                    }

        return emotional_differences

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")