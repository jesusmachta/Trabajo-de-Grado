from fastapi import APIRouter, HTTPException, Depends
from bson import ObjectId
from backend.database import collections
from backend.auth.dependencies import get_empresa

router = APIRouter()
categories_collection = collections["Tipo_Producto"]

@router.delete("/categories/{category_id}", tags=["Categories"])
async def delete_category(category_id: str, empresa: str = Depends(get_empresa)):
    """
    Endpoint para eliminar una categoría por su ID, asociada a la empresa del usuario autenticado.
    """
    try:
        # Verificar si el ID es válido
        if not ObjectId.is_valid(category_id):
            raise HTTPException(status_code=400, detail="ID de categoría inválido")

        # Intentar eliminar la categoría asociada a la empresa
        result = categories_collection.delete_one({
            "_id": ObjectId(category_id),
            "empresa": empresa  # Asegurarse de que la categoría pertenece a la empresa del usuario
        })

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Categoría no encontrada o no pertenece a su empresa")

        return {"message": "Categoría eliminada exitosamente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al eliminar categoría: {str(e)}")