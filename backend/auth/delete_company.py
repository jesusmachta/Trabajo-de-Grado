from backend.database import collections, db
import logging
from fastapi import HTTPException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CompanyDeletionManager:
    @staticmethod
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
            
            # Get all collections in the database (excluding system collections)
            all_collections = db.list_collection_names()
            
            # List of collections to clean - Include all except system collections
            collections_to_clean = [
                'Users', 
                'Persona_AR', 
                'Tipo_Producto', 
                'Tipo_Producto_Zona_Camara',
                'HeatMap',
                'Cameras',
                'Categories',
                'Chats',
                'AnalysisResults',
                'Images',
                'Emotions',
                'Visits'
                # Add any other collections that might contain company data
            ]
            
            # Add any other collections from the database that aren't in our predefined list
            # but aren't system collections (those that start with 'system.')
            for collection_name in all_collections:
                if (collection_name not in collections_to_clean and 
                    not collection_name.startswith('system.') and
                    collection_name != 'Empresas' and 
                    collection_name != 'Estadisticas' and
                    collection_name != 'counters'):
                    collections_to_clean.append(collection_name)
            
            logger.info(f"Collections to clean: {collections_to_clean}")
            
            # Delete data from each collection
            for collection_name in collections_to_clean:
                try:
                    if collection_name in collections:
                        # Try with 'empresa' field first
                        result = collections[collection_name].delete_many({"empresa": empresa})
                        if result.deleted_count == 0:
                            # If no documents were deleted, try with 'company' field
                            result = collections[collection_name].delete_many({"company": empresa})
                        
                        deleted_counts[collection_name] = result.deleted_count
                        logger.info(f"Deleted {result.deleted_count} documents from {collection_name}")
                except Exception as e:
                    logger.error(f"Error deleting from collection {collection_name}: {str(e)}")
                    # Continue with other collections
                    deleted_counts[collection_name] = f"Error: {str(e)}"
            
            # Delete statistics documents that end with :{empresa}
            try:
                stats_query = {"_id": {"$regex": f":{empresa}$"}}
                stats_result = collections["Estadisticas"].delete_many(stats_query)
                deleted_counts["Estadisticas"] = stats_result.deleted_count
                logger.info(f"Deleted {stats_result.deleted_count} documents from Estadisticas")
            except Exception as e:
                logger.error(f"Error deleting from Estadisticas: {str(e)}")
                deleted_counts["Estadisticas"] = f"Error: {str(e)}"
            
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

# Export function directly for backward compatibility
delete_company = CompanyDeletionManager.delete_company 