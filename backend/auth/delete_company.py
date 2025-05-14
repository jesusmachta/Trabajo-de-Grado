from backend.database import collections
import logging
from fastapi import HTTPException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def delete_company(empresa: str, admin_user_id: str):
    """
    Delete a company and all its related data
    """
    try:
        # Verify the company exists
        company = collections['Empresas'].find_one({"nombre": empresa})
        if company is None:
            raise HTTPException(status_code=404, detail=f"Company '{empresa}' not found")
            
        # Verify the user requesting deletion is an admin of the company
        admin_user = None
        try:
            admin_id_int = int(admin_user_id)
            admin_user = collections['Users'].find_one({"_id": admin_id_int, "empresa": empresa})
        except ValueError:
            # If conversion to int fails, try with string ID
            admin_user = collections['Users'].find_one({"_id": admin_user_id, "empresa": empresa})
            
        if admin_user is None:
            raise HTTPException(status_code=404, detail="Admin user not found")
            
        if admin_user.get("role") != "admin":
            raise HTTPException(
                status_code=403, 
                detail="Only company administrators can delete a company"
            )
            
        logger.info(f"Starting deletion of company: {empresa}")
        
        # Delete all data related to the company from all collections
        deleted_counts = {}
        
        # List of collections to clean (excluding system collections)
        collections_to_clean = [
            'Users', 
            'Persona_AR', 
            'Tipo_Producto', 
            'Tipo_Producto_Zona_Camara'
        ]
        
        # Delete data from each collection
        for collection_name in collections_to_clean:
            result = collections[collection_name].delete_many({"empresa": empresa})
            deleted_counts[collection_name] = result.deleted_count
            logger.info(f"Deleted {result.deleted_count} documents from {collection_name}")
        
        # Delete statistics documents that end with :{empresa}
        stats_query = {"_id": {"$regex": f":{empresa}$"}}
        stats_result = collections["Estadisticas"].delete_many(stats_query)
        deleted_counts["Estadisticas"] = stats_result.deleted_count
        logger.info(f"Deleted {stats_result.deleted_count} documents from Estadisticas")
        
        # Delete the company from the Empresas collection
        empresa_result = collections["Empresas"].delete_one({"nombre": empresa})
        deleted_counts["Empresas"] = empresa_result.deleted_count
        logger.info(f"Deleted {empresa_result.deleted_count} documents from Empresas")
        
        return {
            "success": True,
            "message": f"Company '{empresa}' and all related data have been successfully deleted",
            "deleted_counts": deleted_counts
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting company: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deleting company: {str(e)}") 