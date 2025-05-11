#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script para migrar los documentos existentes al nuevo formato de control de procesamiento paginado.
Este script convierte el registro de documentos procesados al nuevo formato que utiliza paginación
para evitar duplicación en el procesamiento de estadísticas.
"""

import sys
import os
import logging
from datetime import datetime

# Obtener la ruta absoluta al directorio raíz del proyecto
# Asumiendo que la estructura es: Trabajo-de-Grado/backend/scripts/este_script.py
script_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(script_dir)
project_root = os.path.dirname(backend_dir)

# Añadir el directorio raíz al path de Python
sys.path.insert(0, project_root)

# Ahora podemos importar desde backend
from backend.database import collections

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def migrate_to_new_format():
    """Migra los documentos existentes al nuevo formato de control de procesamiento paginado."""
    try:
        # Imprimir información de diagnóstico
        logger.info(f"Directorio de trabajo actual: {os.getcwd()}")
        logger.info(f"Ruta del script: {script_dir}")
        logger.info(f"Ruta de backend: {backend_dir}")
        logger.info(f"Ruta raíz del proyecto: {project_root}")
        
        # Paso 1: Encontrar todas las empresas únicas en Persona_AR
        empresas = list(collections["Persona_AR"].distinct("empresa"))
        logger.info(f"Se encontraron {len(empresas)} empresas para migrar")
        
        for empresa in empresas:
            if not empresa:
                logger.warning("Se encontró una empresa con nombre vacío o nulo, omitiendo")
                continue
                
            logger.info(f"Migrando datos para la empresa: {empresa}")
            
            # Paso 2: Eliminar documento de control existente si hay
            collections["Estadisticas"].delete_one({"_id": f"processed_documents:{empresa}"})
            
            # Paso 3: Crear nuevo documento de control con la estructura paginada
            processed_doc = {
                "_id": f"processed_documents:{empresa}",
                "processed_ids": {},
                "last_id_processed": 0,
                "current_page": 1,
                "last_updated": datetime.utcnow().isoformat()
            }
            collections["Estadisticas"].insert_one(processed_doc)
            
            # Paso 4: Obtener todos los IDs de documentos para esta empresa
            cursor = collections["Persona_AR"].find(
                {"empresa": empresa}, 
                {"id": 1, "_id": 0}
            ).sort("id", 1)
            
            all_ids = [doc.get("id") for doc in cursor if doc.get("id") is not None]
            
            if not all_ids:
                logger.warning(f"No se encontraron documentos con IDs válidos para la empresa {empresa}")
                continue
                
            logger.info(f"Registrando {len(all_ids)} documentos para la empresa {empresa}")
            
            # Paso 5: Organizar IDs en páginas (1000 por página)
            processed_ids = {}
            current_page = 1
            
            for i in range(0, len(all_ids), 1000):
                page_ids = all_ids[i:i+1000]
                processed_ids[str(current_page)] = [str(id) for id in page_ids]
                current_page += 1
            
            # Paso 6: Actualizar el documento de control con todos los IDs paginados
            last_id = all_ids[-1] if all_ids else 0
            
            collections["Estadisticas"].update_one(
                {"_id": f"processed_documents:{empresa}"},
                {"$set": {
                    "processed_ids": processed_ids,
                    "last_id_processed": last_id,
                    "current_page": current_page - 1,
                    "last_updated": datetime.utcnow().isoformat()
                }}
            )
            
            logger.info(f"Migración completada para la empresa {empresa}, {len(all_ids)} documentos registrados en {current_page - 1} páginas")
        
        logger.info("¡Migración completada con éxito!")
        
    except Exception as e:
        logger.error(f"Error durante la migración: {e}")
        import traceback
        logger.error(traceback.format_exc())

if __name__ == "__main__":
    logger.info("Iniciando migración de documentos al nuevo formato de control de procesamiento")
    migrate_to_new_format()
    logger.info("Proceso de migración finalizado")