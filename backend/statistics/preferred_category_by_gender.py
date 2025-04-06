from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_preferred_category_by_gender():
    """
    Calcula las categorías de productos preferidas por género (hombres y mujeres).
    :return: JSON con las categorías más frecuentadas por hombres y mujeres.
    """
    try:
        # Diccionarios para contar las visitas por categoría y género
        gender_category_counts = {
            "male": defaultdict(int),
            "female": defaultdict(int)
        }

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"gender": 1, "categoria_producto": 1})

        for persona in personas:
            gender = persona.get("gender", "").lower()
            categoria_producto = persona.get("categoria_producto", "")

            if gender in ["male", "female"] and categoria_producto:
                gender_category_counts[gender][categoria_producto] += 1

        # Determinar la categoría más frecuentada por cada género
        preferred_categories = {}
        for gender, categories in gender_category_counts.items():
            if categories:
                preferred_category = max(categories, key=categories.get)
                preferred_categories[gender] = {
                    "category": preferred_category,
                    "count": categories[preferred_category]
                }
            else:
                preferred_categories[gender] = {
                    "category": None,
                    "count": 0
                }

        return preferred_categories

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")