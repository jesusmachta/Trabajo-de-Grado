from fastapi import APIRouter, HTTPException
from bson import ObjectId
from backend.database import collections
from backend.auth.dependencies import get_empresa

router = APIRouter()
categories_collection = collections["Tipo_Producto"]

@router.delete("/categories/{category_id}", tags=["Categories"])
async def delete_category(category_id: str):
    """
    Endpoint para eliminar una categoría por su ID.
    """
    try:
        # Verificar si el ID es válido
        if not ObjectId.is_valid(category_id):
            raise HTTPException(status_code=400, detail="ID de categoría inválido")

        # Eliminar la categoría de la base de datos
        result = categories_collection.delete_one({"_id": ObjectId(category_id)})

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Categoría no encontrada")

        return {"message": "Categoría eliminada exitosamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al eliminar categoría: {str(e)}")