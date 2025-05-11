from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from bson import ObjectId
from backend.database import collections
from backend.auth.dependencies import get_empresa, get_current_user

router = APIRouter()

categories_collection = collections["Tipo_Producto"]

class UpdateCategoryRequest(BaseModel):
    Categoria_Producto: str
    isActive: bool
    icon: str = "category"  # Default icon if not specified

@router.get("/categories", tags=["Categories"])
def get_categories(empresa: str= Depends (get_empresa)):
    """
    Endpoint para obtener todas las categorías tal como están en la base de datos (sincrónico).
    """
    try:
        
        # Obtener los documentos sin usar await
        categories_cursor = categories_collection.find({"empresa": empresa})
        categories_list = list(categories_cursor)  

        # Serializar los documentos
        serialized_categories = [
            {
                "_id": str(category["_id"]),
                "Tipo_Producto": category.get("Tipo_Producto", None),
                "Categoria_Producto": category.get("Categoria_Producto", "Sin nombre"),
                "isActive": category.get("isActive", True),
                "icon": category.get("icon", "category")  # Get the icon or use default
            }
            for category in categories_list
        ]

        return {"message": "Success", "data": serialized_categories}
    except Exception as e:
        print("Error:", str(e))
        raise HTTPException(status_code=500, detail=f"Error al obtener categorías: {str(e)}")
