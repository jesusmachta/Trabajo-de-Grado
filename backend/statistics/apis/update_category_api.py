from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from bson import ObjectId
from backend.database import collections
from backend.auth.dependencies import get_empresa

router = APIRouter()
categories_collection = collections["Tipo_Producto"]

class UpdateCategoryRequest(BaseModel):
    Categoria_Producto: str
    isActive: bool

@router.put("/categories/{category_id}", tags=["Categories"])
def update_category(category_id: str, request: UpdateCategoryRequest):
    """
    Endpoint para actualizar una categoría por su ID.
    """
    try:
        # Verificar si el ID es válido
        if not ObjectId.is_valid(category_id):
            raise HTTPException(status_code=400, detail="ID de categoría inválido")

        # Actualizar la categoría en la base de datos
        result = categories_collection.update_one(
            {"_id": ObjectId(category_id)},
            {"$set": {"Categoria_Producto": request.Categoria_Producto, "isActive": request.isActive}}
        )

        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Categoría no encontrada")

        return {"message": "Categoría actualizada exitosamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al actualizar categoría: {str(e)}")