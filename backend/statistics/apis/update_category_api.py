from fastapi import APIRouter, HTTPException, Depends
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
def update_category(category_id: str, request: UpdateCategoryRequest, empresa: str = Depends(get_empresa)):
    """
    Endpoint para actualizar una categoría por su ID, asociada a la empresa del usuario autenticado.
    """
    try:
        # Verificar si el ID es válido
        if not ObjectId.is_valid(category_id):
            raise HTTPException(status_code=400, detail="ID de categoría inválido")

        # Intentar actualizar la categoría asociada a la empresa
        result = categories_collection.update_one(
            {
                "_id": ObjectId(category_id),
                "empresa": empresa  # Asegurarse de que la categoría pertenece a la empresa del usuario
            },
            {
                "$set": {
                    "Categoria_Producto": request.Categoria_Producto,
                    "isActive": request.isActive
                }
            }
        )

        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Categoría no encontrada o no pertenece a su empresa")

        return {"message": "Categoría actualizada exitosamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al actualizar categoría: {str(e)}")