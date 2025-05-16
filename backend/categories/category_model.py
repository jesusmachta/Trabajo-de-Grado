from fastapi import HTTPException
from bson import ObjectId
from backend.database import collections
from typing import List, Dict, Any, Optional

class CategoryModel:
    def __init__(self):
        self.collection = collections["Tipo_Producto"]
    
    def get_all_categories(self, empresa: str) -> List[Dict[str, Any]]:
        """
        Get all categories for a specific company.
        """
        try:
            categories_cursor = self.collection.find({"empresa": empresa})
            categories_list = list(categories_cursor)

            serialized_categories = [
                {
                    "_id": str(category["_id"]),
                    "Tipo_Producto": category.get("Tipo_Producto", None),
                    "Categoria_Producto": category.get("Categoria_Producto", "Sin nombre"),
                    "isActive": category.get("isActive", True),
                    "icon": category.get("icon", "category")
                }
                for category in categories_list
            ]

            return serialized_categories
        except Exception as e:
            print("Error:", str(e))
            raise HTTPException(status_code=500, detail=f"Error al obtener categorías: {str(e)}")
    
    def create_category(self, tipo_producto: int, categoria_producto: str, 
                        is_active: bool, icon: str, empresa: str) -> str:
        """
        Create a new category.
        """
        try:
            # Verify category name is not empty
            if not categoria_producto.strip():
                raise HTTPException(status_code=400, detail="El nombre de la categoría no puede estar vacío")

            # Verify Tipo_Producto is a positive integer
            if tipo_producto is None or tipo_producto < 0:
                raise HTTPException(status_code=400, detail="El campo 'Tipo_Producto' debe ser un número entero positivo")

            # Convert Categoria_Producto to lowercase for validation
            categoria_producto_lower = categoria_producto.strip().lower()

            # Check if a category with the same Tipo_Producto or Categoria_Producto already exists
            existing_category = self.collection.find_one({
                "$and": [
                    {"empresa": empresa},
                    {
                        "$or": [
                            {"Tipo_Producto": tipo_producto},
                            {"Categoria_Producto": {"$regex": f"^{categoria_producto_lower}$", "$options": "i"}}
                        ]
                    }
                ]
            })

            if existing_category:
                raise HTTPException(
                    status_code=400,
                    detail="Ya existe una categoría con el mismo 'Tipo_Producto' o 'Categoria_Producto' para esta empresa"
                )

            # Create the new category
            new_category = {
                "Tipo_Producto": tipo_producto,
                "Categoria_Producto": categoria_producto.strip(),
                "isActive": is_active,
                "icon": icon,
                "empresa": empresa
            }
            result = self.collection.insert_one(new_category)

            return str(result.inserted_id)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error al crear categoría: {str(e)}")
    
    def update_category(self, category_id: str, categoria_producto: str, 
                       is_active: bool, icon: str, empresa: str) -> bool:
        """
        Update an existing category.
        """
        try:
            # Verify if ID is valid
            if not ObjectId.is_valid(category_id):
                raise HTTPException(status_code=400, detail="ID de categoría inválido")

            # Try to update the category
            result = self.collection.update_one(
                {
                    "_id": ObjectId(category_id),
                    "empresa": empresa
                },
                {
                    "$set": {
                        "Categoria_Producto": categoria_producto,
                        "isActive": is_active,
                        "icon": icon
                    }
                }
            )

            if result.matched_count == 0:
                raise HTTPException(status_code=404, detail="Categoría no encontrada o no pertenece a su empresa")

            return True
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error al actualizar categoría: {str(e)}")
    
    def delete_category(self, category_id: str, empresa: str) -> bool:
        """
        Delete a category.
        """
        try:
            # Verify if ID is valid
            if not ObjectId.is_valid(category_id):
                raise HTTPException(status_code=400, detail="ID de categoría inválido")

            # Try to delete the category
            result = self.collection.delete_one({
                "_id": ObjectId(category_id),
                "empresa": empresa
            })

            if result.deleted_count == 0:
                raise HTTPException(status_code=404, detail="Categoría no encontrada o no pertenece a su empresa")

            return True
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error al eliminar categoría: {str(e)}") 