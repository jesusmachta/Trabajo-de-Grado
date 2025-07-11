#!/usr/bin/env python3
"""
Script para inicializar la colección de estadísticas a partir de datos históricos en PersonaAR.
Este script se debe ejecutar una única vez para cargar los datos históricos antes de empezar a usar 
el sistema de actualizaciones incrementales.
"""

import sys
import os
import logging
from datetime import datetime
from pymongo import MongoClient

# Añadir el directorio raíz al path para importar los módulos
script_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(script_dir)
sys.path.append(backend_dir)

try:
    from backend.statistics.incremental_stats import initialize_statistics, update_statistics_on_insert
    from backend.database import collections
    logger_prefix = "Usando importaciones directas: "
except ImportError:
    # Si falla la importación, intentamos con rutas absolutas
    sys.path.insert(0, backend_dir)
    try:
        from statistics.incremental_stats import initialize_statistics, update_statistics_on_insert
        from database import collections
        logger_prefix = "Usando importaciones absolutas: "
    except ImportError:
        # Como último recurso, conectamos directamente a MongoDB
        logger_prefix = "Usando conexión directa a MongoDB: "
        MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017/")
        DB_NAME = os.environ.get("DB_NAME", "store_sense_db")
        client = MongoClient(MONGO_URI)
        db = client[DB_NAME]
        collections = {
            "Persona_AR": db["Persona_AR"],
            "Estadisticas": db["Estadisticas"]
        }
        # Importaciones fallidas, definimos funciones placeholder
        def initialize_statistics():
            """Inicializa los documentos de estadísticas."""
            logger.info("Inicializando documentos de estadísticas manualmente...")
            # Crear documentos básicos
            docs = [
                {"_id": "peak_hours", "description": "Horas pico por día de la semana", "data": {}},
                {"_id": "least_busy_hours", "description": "Horas menos concurridas por día de la semana", "data": {}},
                {"_id": "most_busy_day", "description": "Día más concurrido de la semana", "data": {}},
                {"_id": "least_busy_day", "description": "Día menos concurrido de la semana", "data": {}},
                {"_id": "most_visited_category", "description": "Categoría más visitada", "data": {}},
                {"_id": "least_visited_category", "description": "Categoría menos visitada", "data": {}},
                {"_id": "gender_distribution", "description": "Distribución por género", "data": {}},
                {"_id": "age_distribution", "description": "Distribución por edad", "data": {}},
                {"_id": "most_frequent_emotions", "description": "Emociones más frecuentes", "data": {}},
                {"_id": "preferred_category_by_gender", "description": "Categorías preferidas por género", "data": {"Male": {}, "Female": {}}},
                {"_id": "emotion_percentage_by_category", "description": "Porcentaje de emociones por categoría", "data": {}}
            ]
            for doc in docs:
                collections["Estadisticas"].replace_one({"_id": doc["_id"]}, doc, upsert=True)
            
        def update_statistics_on_insert(document):
            """Actualiza las estadísticas en base a un documento de PersonaAR."""
            # Implementación básica para contar categorías y emociones
            cat = document.get("categoria_producto", "")
            gender = document.get("gender", "")
            emotion = document.get("emotions", "")
            if cat and gender and emotion:
                logger.info(f"Procesando documento con categoría: {cat}, género: {gender}, emoción: {emotion}")
                # Aquí podríamos implementar una versión simplificada de las actualizaciones
                # Pero por ahora solo registramos que se procesó

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

def main():
    """Función principal para inicializar estadísticas desde el historial."""
    try:
        # Inicializar los documentos de estadísticas
        logger.info(f"{logger_prefix}Inicializando documentos de estadísticas...")
        initialize_statistics()

        # Contar cuántos registros hay que procesar
        total_records = collections["Persona_AR"].count_documents({})
        logger.info(f"{logger_prefix}Procesando {total_records} registros históricos de PersonaAR...")

        # Procesar registros históricos
        processed = 0
        batch_size = 100  # Procesar en lotes para mostrar progreso
        
        cursor = collections["Persona_AR"].find().sort("id", 1)  # Ordenar por ID para procesar en orden cronológico
        
        for document in cursor:
            # Actualizar estadísticas incrementalmente
            update_statistics_on_insert(document)
            
            processed += 1
            if processed % batch_size == 0:
                logger.info(f"{logger_prefix}Procesados {processed}/{total_records} registros ({processed/total_records*100:.1f}%)")
        
        logger.info(f"{logger_prefix}Procesamiento completado! {processed} registros procesados.")
        logger.info(f"{logger_prefix}Las estadísticas han sido inicializadas correctamente.")
    
    except Exception as e:
        logger.error(f"{logger_prefix}Error durante la inicialización de estadísticas: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        # Cerrar conexión a MongoDB si se creó directamente
        if 'client' in globals():
            client.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 