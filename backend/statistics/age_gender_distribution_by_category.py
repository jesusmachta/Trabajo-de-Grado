from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_age_gender_distribution_by_category():
    """
    Calcula las combinaciones de género y rango de edad más frecuentes por categoría de producto.
    :return: JSON con las combinaciones más frecuentes por categoría.
    """
    try:
        # Diccionario para contar combinaciones de género y edad por categoría
        category_distribution = defaultdict(lambda: {"male": defaultdict(int), "female": defaultdict(int)})

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "gender": 1, "age_range": 1})

        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            gender = persona.get("gender", "").lower()
            age_range = persona.get("age_range", {})

            # Calcular la edad promedio (mitad del rango)
            low = age_range.get("low")
            high = age_range.get("high")
            if categoria_producto and gender in ["male", "female"] and low is not None and high is not None:
                average_age = (low + high) // 2  # Calcular la edad promedio
                category_distribution[categoria_producto][gender][average_age] += 1

        # Formatear los resultados
        age_gender_distribution = {}
        for category, gender_data in category_distribution.items():
            age_gender_distribution[category] = {}
            for gender, ages in gender_data.items():
                # Ordenar las edades por frecuencia en orden descendente
                sorted_ages = sorted(ages.items(), key=lambda x: x[1], reverse=True)
                age_gender_distribution[category][gender] = [
                    {"age": age, "count": count} for age, count in sorted_ages
                ]

        return age_gender_distribution

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")
    