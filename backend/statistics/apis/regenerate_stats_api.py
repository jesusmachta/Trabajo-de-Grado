from datetime import datetime
import logging
from fastapi import APIRouter, BackgroundTasks, HTTPException
from backend.database import collections
from backend.statistics.incremental_stats import recalculate_all_statistics, update_statistics_on_insert

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/statistics/regenerate/")
async def regenerate_statistics():
    """
    Endpoint para regenerar todas las estadísticas desde cero usando los datos históricos.
    Este es un proceso costoso que puede tomar tiempo, dependiendo de la cantidad de datos.
    """
    try:
        # Regenerar estadísticas en segundo plano
        background_tasks = BackgroundTasks()
        background_tasks.add_task(recalculate_all_statistics)
        
        return {
            "message": "Success", 
            "detail": "Iniciado proceso de regeneración de estadísticas en segundo plano"
        }
    except Exception as e:
        logger.error(f"Error iniciando regeneración de estadísticas: {e}")
        return {"message": "Error", "error": str(e)}

@router.post("/statistics/regenerate-preferred-gender/")
async def regenerate_preferred_gender_stats():
    """
    Endpoint para regenerar solo las estadísticas de categorías preferidas por género.
    """
    try:
        logger.info("Iniciando regeneración de estadísticas de categorías preferidas por género...")
        
        # 1. Eliminar el documento actual
        collections["Estadisticas"].delete_one({"_id": "preferred_category_by_gender"})
        
        # 2. Crear nuevo documento limpio
        preferred_doc = {
            "_id": "preferred_category_by_gender",
            "description": "Categorías preferidas por género",
            "data": {
                "Male": {"category": "", "count": 0},
                "Female": {"category": "", "count": 0}
            },
            "raw_counts": {
                "Male": {},
                "Female": {}
            },
            "last_updated": datetime.utcnow().isoformat()
        }
        collections["Estadisticas"].insert_one(preferred_doc)
        
        # 3. Procesar todos los documentos de Persona_AR para esta estadística específica
        total_docs = collections["Persona_AR"].count_documents({})
        processed = 0
        male_categories = {}
        female_categories = {}
        
        cursor = collections["Persona_AR"].find({})
        for document in cursor:
            try:
                gender = document.get("gender")
                category = document.get("categoria_producto")
                
                if gender and category:
                    if gender == "Male":
                        male_categories[category] = male_categories.get(category, 0) + 1
                    elif gender == "Female":
                        female_categories[category] = female_categories.get(category, 0) + 1
                
                processed += 1
            except Exception as e:
                logger.error(f"Error procesando documento: {e}")
                continue
        
        # 4. Calcular categorías preferidas
        male_preferred = {"category": "", "count": 0}
        if male_categories:
            max_male = max(male_categories.items(), key=lambda x: x[1])
            male_preferred = {"category": max_male[0], "count": max_male[1]}
        
        female_preferred = {"category": "", "count": 0}
        if female_categories:
            max_female = max(female_categories.items(), key=lambda x: x[1])
            female_preferred = {"category": max_female[0], "count": max_female[1]}
        
        # 5. Actualizar documento con resultados
        collections["Estadisticas"].update_one(
            {"_id": "preferred_category_by_gender"},
            {"$set": {
                "data": {
                    "Male": male_preferred,
                    "Female": female_preferred
                },
                "raw_counts": {
                    "Male": male_categories,
                    "Female": female_categories
                },
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        
        logger.info(f"Regeneración completada. Procesados {processed} documentos.")
        
        return {
            "message": "Success", 
            "detail": "Estadísticas de categorías preferidas por género regeneradas correctamente",
            "data": {
                "Male": male_preferred,
                "Female": female_preferred
            }
        }
    except Exception as e:
        logger.error(f"Error en regeneración de estadísticas preferred_category_by_gender: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {"message": "Error", "error": str(e)}

@router.post("/statistics/regenerate-for-company/")
async def regenerate_statistics_for_company(empresa: str):
    """
    Endpoint para regenerar todas las estadísticas para una empresa específica.
    Este es un proceso que puede tomar tiempo según la cantidad de datos.
    """
    try:
        # Eliminar todos los documentos de estadísticas existentes para esta empresa
        deleted = collections["Estadisticas"].delete_many({"_id": {"$regex": f":{empresa}$"}})
        logger.info(f"Se eliminaron {deleted.deleted_count} documentos de estadísticas para la empresa '{empresa}'")
        
        # Inicializar nuevos documentos de estadísticas para la empresa
        from backend.statistics.incremental_stats import initialize_statistics
        initialize_statistics(empresa)
        
        # Recalcular las estadísticas usando los datos históricos de esta empresa
        count = 0
        cursor = collections["Persona_AR"].find({"empresa": empresa})
        for document in cursor:
            try:
                update_statistics_on_insert(document)
                count += 1
            except Exception as doc_error:
                logger.error(f"Error al procesar documento {document.get('id', 'unknown')}: {str(doc_error)}")
                continue
        return {
            "message": "Success", 
            "detail": f"Se regeneraron las estadísticas para la empresa '{empresa}'. Procesados {count} documentos."
        }
    except Exception as e:
        logger.error(f"Error al regenerar estadísticas para empresa '{empresa}': {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"Error al regenerar estadísticas: {str(e)}"
        ) 