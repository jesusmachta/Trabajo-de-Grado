from pydantic import BaseModel, Field
from typing import Optional

class CategoryBase(BaseModel):
    """Base model for category data"""
    Categoria_Producto: str
    isActive: bool
    icon: str = "category"  # Default icon if not specified

class CategoryCreate(CategoryBase):
    """Model for creating a new category"""
    Tipo_Producto: int = Field(..., ge=0, description="Debe ser un número entero positivo")

class CategoryUpdate(CategoryBase):
    """Model for updating an existing category"""
    pass

class CategoryResponse(CategoryBase):
    """Model for category response data"""
    _id: str
    Tipo_Producto: Optional[int] = None
    
    class Config:
        from_attributes = True 