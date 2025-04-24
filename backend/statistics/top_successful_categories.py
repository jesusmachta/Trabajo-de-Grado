from backend.database import collections
from collections import defaultdict

persona_collection = collections["Persona_AR"]

def get_top_successful_categories():
    """
    Calcula el top de categorías que generan más emociones positivas (HAPPY).
    :return: JSON con el top 3 de categorías ordenadas por la cantidad de emociones HAPPY.
    """
    try:
        # Diccionario para contar las emociones HAPPY por categoría
        category_happy_counts = defaultdict(int)
        
        # Conjunto para almacenar todas las categorías existentes
        all_categories = set()

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"categoria_producto": 1, "emotions": 1})

        for persona in personas:
            categoria_producto = persona.get("categoria_producto", "")
            emotion = persona.get("emotions", "").upper()
            
            # Añadir la categoría al conjunto de todas las categorías
            if categoria_producto:
                all_categories.add(categoria_producto)

            if categoria_producto and emotion == "HAPPY":
                category_happy_counts[categoria_producto] += 1

        # Ordenar las categorías por la cantidad de emociones HAPPY en orden descendente
        sorted_categories = sorted(category_happy_counts.items(), key=lambda x: x[1], reverse=True)

        # Si hay menos de 3 categorías con emociones HAPPY, añadir categorías adicionales con count=0
        if len(sorted_categories) < 3:
            # Obtener categorías que no tienen HAPPY
            remaining_categories = list(all_categories - set(cat for cat, _ in sorted_categories))
            
            # Si aún no tenemos suficientes categorías, podemos buscar en la colección Tipo_Producto
            if len(sorted_categories) + len(remaining_categories) < 3:
                try:
                    tipo_producto_docs = collections['Tipo_Producto'].find({}, {"Categoria_Producto": 1})
                    for doc in tipo_producto_docs:
                        cat = doc.get("Categoria_Producto")
                        if cat and cat not in category_happy_counts and cat not in remaining_categories:
                            remaining_categories.append(cat)
                except Exception:
                    pass  # Si hay error al consultar Tipo_Producto, continuamos con lo que tenemos
            
            # Añadir categorías faltantes hasta llegar a 3
            for cat in remaining_categories:
                if len(sorted_categories) < 3:
                    sorted_categories.append((cat, 0))
                else:
                    break

        # Formatear el resultado como un top (máximo 3 categorías)
        top_categories = [
            {"rank": idx + 1, "category": category, "happy_count": count}
            for idx, (category, count) in enumerate(sorted_categories[:3])
        ]
        
        # Asegurarse de que siempre se devuelvan exactamente 3 elementos
        while len(top_categories) < 3:
            top_categories.append({
                "rank": len(top_categories) + 1,
                "category": "Sin datos",
                "happy_count": 0
            })

        return top_categories

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")