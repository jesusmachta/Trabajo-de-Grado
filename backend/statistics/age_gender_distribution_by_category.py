from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

# Define age ranges
AGE_RANGES = {
    "18-25": (18, 25),
    "26-35": (26, 35),
    "36-45": (36, 45),
    "46-59": (46, 59),
    "60+": (60, float('inf')) # Use infinity for the upper bound of 60+
}

def get_age_range_label(low, high):
    """Determines the age range label based on low and high estimates."""
    # Use an average or midpoint for classification if needed, or use low edge.
    # Let's use the 'low' value primarily for categorization.
    age = low # Or use (low + high) // 2 if preferred

    for label, (min_age, max_age) in AGE_RANGES.items():
        if min_age <= age <= max_age:
            return label
    return None # Or a default label like "Other" if age doesn't fit defined ranges

def get_age_gender_distribution_by_category():
    """
    Calcula las combinaciones de género y rango de edad más frecuentes por categoría de producto.
    Agrupa por rangos de edad predefinidos.
    :return: JSON con las combinaciones más frecuentes por categoría, formateado como se requiere.
    """
    try:
        # Diccionario para contar combinaciones de género y rango de edad por categoría
        # Structure: { "Category": { "Gender": { "AgeRangeLabel": count } } }
        category_distribution_counts = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "gender": 1, "age_range": 1})

        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            gender = persona.get("gender", "") # Keep original capitalization if needed, e.g., "Male", "Female"
            age_range_data = persona.get("age_range", {})

            low = age_range_data.get("low")
            high = age_range_data.get("high")

            if categoria_producto and gender in ["Male", "Female"] and low is not None and high is not None:
                age_range_label = get_age_range_label(low, high)
                if age_range_label:
                    category_distribution_counts[categoria_producto][gender][age_range_label] += 1

        # Formatear los resultados al formato deseado:
        # { "Category": [ { "gender": "Gender", "age_range": "RangeLabel", "count": N }, ... ] }
        formatted_distribution = {}
        for category, gender_data in category_distribution_counts.items():
            category_list = []
            for gender, age_range_counts in gender_data.items():
                for age_range_label, count in age_range_counts.items():
                    if count > 0: # Only include if count is positive
                        category_list.append({
                            "gender": gender,
                            "age_range": age_range_label,
                            "count": count
                        })
            # Sort the list within the category, e.g., by gender then age range, or by count
            # Sorting by count descending might be useful:
            category_list.sort(key=lambda x: x['count'], reverse=True)
            if category_list: # Only add category if it has data
                formatted_distribution[category] = category_list

        return formatted_distribution

    except Exception as e:
        # Log the error for debugging
        print(f"Error in get_age_gender_distribution_by_category: {e}")
        raise Exception(f"Unexpected error calculating age/gender distribution: {e}")
    