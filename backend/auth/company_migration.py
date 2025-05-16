from datetime import datetime
import logging
from fastapi import APIRouter, HTTPException
from backend.database import collections

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/migrate-companies")
async def migrate_existing_companies():
    """
    Endpoint para migrar las empresas existentes a la colección Empresas.
    Este es un endpoint de uso único para migración de datos.
    """
    try:
        # Obtener todas las empresas únicas de la colección Users
        pipeline = [
            {"$group": {"_id": {"empresa": "$empresa", "rif": "$rif"}}},
            {"$project": {"nombre": "$_id.empresa", "rif": "$_id.rif", "_id": 0}}
        ]
        
        unique_companies = list(collections['Users'].aggregate(pipeline))
        
        # Contador de empresas migradas y empresas ya existentes
        migrated_count = 0
        already_exists_count = 0
        
        for company in unique_companies:
            nombre = company.get("nombre")
            rif = company.get("rif")
            
            # Validar que tengamos nombre y RIF
            if not nombre:
                logger.warning(f"Empresa sin nombre encontrada, omitiendo: {company}")
                continue
                
            # Verificar si ya existe en la colección Empresas
            existing = collections['Empresas'].find_one({"nombre": nombre})
            if existing:
                already_exists_count += 1
                continue
                
            # Crear documento de empresa
            empresa_doc = {
                "nombre": nombre,
                "rif": rif,
                "created_at": datetime.utcnow().isoformat(),
                "migrated": True  # Marcar como migrada para referencia
            }
            
            # Insertar en la colección Empresas
            collections['Empresas'].insert_one(empresa_doc)
            migrated_count += 1
            
        return {
            "message": "Migración completada",
            "migrated_count": migrated_count,
            "already_exists_count": already_exists_count,
            "total_processed": len(unique_companies)
        }
    
    except Exception as e:
        logger.error(f"Error al migrar empresas: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error al migrar empresas: {str(e)}") 