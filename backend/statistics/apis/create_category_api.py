from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from backend.database import collections

router = APIRouter()
categories_collection = collections["Tipo_Producto"]

class CreateCategoryRequest(BaseModel):
    Tipo_Producto: int = Field(..., ge=0, description="Debe ser un número entero positivo")
    Categoria_Producto: str
    isActive: bool

@router.post("/categories/create", tags=["Categories"])
async def create_category(request: CreateCategoryRequest):
    """
    Endpoint para crear una nueva categoría.
    """
    try:
        # Verificar que el nombre de la categoría no esté vacío
        if not request.Categoria_Producto.strip():
            raise HTTPException(status_code=400, detail="El nombre de la categoría no puede estar vacío")

        # Verificar que Tipo_Producto sea un número entero positivo
        if request.Tipo_Producto is None or request.Tipo_Producto < 0:
            raise HTTPException(status_code=400, detail="El campo 'Tipo_Producto' debe ser un número entero positivo")

        # Convertir Categoria_Producto a minúsculas para la validación
        categoria_producto_lower = request.Categoria_Producto.strip().lower()

        # Verificar si ya existe una categoría con el mismo Tipo_Producto o Categoria_Producto (sin sensibilidad a mayúsculas/minúsculas)
        existing_category = categories_collection.find_one({
            "$or": [
                {"Tipo_Producto": request.Tipo_Producto},
                {"Categoria_Producto": {"$regex": f"^{categoria_producto_lower}$", "$options": "i"}}
            ]
        })

        if existing_category:
            raise HTTPException(
                status_code=400,
                detail="Ya existe una categoría con el mismo 'Tipo_Producto' o 'Categoria_Producto'"
            )

        # Crear la nueva categoría en la base de datos
        new_category = {
            "Tipo_Producto": request.Tipo_Producto,
            "Categoria_Producto": request.Categoria_Producto.strip(),
            "isActive": request.isActive,
        }
        result = categories_collection.insert_one(new_category)

        return {"message": "Categoría creada exitosamente", "id": str(result.inserted_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al crear categoría: {str(e)}")