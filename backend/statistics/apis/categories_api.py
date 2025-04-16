from fastapi import APIRouter, HTTPException
from backend.database import collections

categories_collection = collections["Tipo_Producto"]

# router = APIRouter()

# @router.get("/categories", tags=["Categories"])
# async def get_categories():
#     try:
#         categories = collections["Tipo_Producto"].distinct("Categoria_Producto")
#         return {"message": "Success", "data": categories}
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Error al obtener categorías: {str(e)}")
    

def get_categories():
    try:
        categories = categories_collection.distinct("Categoria_Producto")
        return {"message": "Success", "data": categories}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al obtener categorías: {str(e)}") 