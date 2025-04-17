from fastapi import APIRouter, HTTPException
from bson import ObjectId
from backend.database import collections

router = APIRouter()
categories_collection = collections["Tipo_Producto"]

@router.get("/categories", tags=["Categories"])
def get_categories():
    """
    Endpoint para obtener todas las categorías tal como están en la base de datos (sincrónico).
    """
    try:
        # Obtener los documentos sin usar await
        categories_cursor = categories_collection.find()
        categories_list = list(categories_cursor)  # pymongo es sincrónico

        # Serializar los documentos
        serialized_categories = [
            {
                "_id": str(category["_id"]),
                "Tipo_Producto": category.get("Tipo_Producto", None),
                "Categoria_Producto": category.get("Categoria_Producto", "Sin nombre"),
                "isActive": category.get("isActive", True)
            }
            for category in categories_list
        ]

        return {"message": "Success", "data": serialized_categories}
    except Exception as e:
        print("Error:", str(e))
        raise HTTPException(status_code=500, detail=f"Error al obtener categorías: {str(e)}")
