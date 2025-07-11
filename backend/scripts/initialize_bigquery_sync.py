from backend.database import collections, db
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def initialize_bigquery_sync_collection():
    """
    Inicializa la colección BigQuerySync si no existe.
    Verifica que la colección Persona_AR exista y tiene documentos.
    """
    # Verificar que BigQuerySync está en las colecciones
    if "BigQuerySync" not in collections:
        logger.error("La colección BigQuerySync no está definida en database.py")
        return False
    
    # Verificar que exista la colección Persona_AR
    if collections["Persona_AR"].count_documents({}) == 0:
        logger.warning("La colección Persona_AR está vacía, no hay datos para sincronizar")
    
    # Verificar si ya existe un registro de control
    if collections["BigQuerySync"].count_documents({"collection": "Persona_AR"}) == 0:
        # Inicializar con ID 0 para que la primera sincronización procese todo
        collections["BigQuerySync"].insert_one({
            "collection": "Persona_AR",
            "last_id": 0,
            "last_sync": None
        })
        logger.info("Colección BigQuerySync inicializada para Persona_AR")
        return True
    else:
        logger.info("La colección BigQuerySync ya está inicializada para Persona_AR")
        return True

if __name__ == "__main__":
    initialize_bigquery_sync_collection()
    print("Inicialización de BigQuerySync completada") 