#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script para recalcular todas las estadísticas con el nuevo sistema.
Este script borra y regenera todas las estadísticas, asegurando que cada
documento de Persona_AR solo se procese una vez gracias al nuevo sistema
de control de procesamiento paginado.
"""

import sys
import os
import logging

# Obtener la ruta absoluta al directorio raíz del proyecto
script_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(script_dir)
project_root = os.path.dirname(backend_dir)

# Añadir el directorio raíz al path de Python
sys.path.insert(0, project_root)

# Ahora podemos importar desde backend
from backend.statistics.incremental_stats import recalculate_all_statistics
from backend.database import collections

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def recalculate_stats_for_all_companies():
    """
    Ejecuta el recálculo de estadísticas para todas las empresas
    utilizando el nuevo sistema de control de procesamiento.
    """
    try:
        # Paso 1: Mostrar información diagnóstica
        logger.info(f"Directorio de trabajo actual: {os.getcwd()}")
        logger.info(f"Ruta del script: {script_dir}")
        logger.info(f"Ruta de backend: {backend_dir}")
        logger.info(f"Ruta raíz del proyecto: {project_root}")
        
        # Paso 2: Obtener todas las empresas
        empresas = list(collections["Persona_AR"].distinct("empresa"))
        logger.info(f"Se encontraron {len(empresas)} empresas para recalcular estadísticas")
        
        # Paso 3: Recalcular estadísticas para todas las empresas
        if not empresas:
            logger.warning("No se encontraron empresas para recalcular estadísticas")
            return
            
        # Opción 1: Recálculo general para todas las empresas
        logger.info("Iniciando recálculo general para todas las empresas...")
        recalculate_all_statistics()
        logger.info("Recálculo general completado con éxito")
        
        # Opción 2 (alternativa): Recálculo individual por empresa
        # Descomenta las siguientes líneas si prefieres recalcular empresa por empresa
        """
        for empresa in empresas:
            if not empresa:
                logger.warning("Se encontró una empresa con nombre vacío o nulo, omitiendo")
                continue
                
            logger.info(f"Recalculando estadísticas para la empresa: {empresa}")
            recalculate_all_statistics(empresa=empresa)
            logger.info(f"Recálculo completado para la empresa: {empresa}")
        """
        
        # Paso 4: Verificar que se hayan creado los documentos de control
        count = collections["Estadisticas"].count_documents({"_id": {"$regex": "^processed_documents:"}})
        logger.info(f"Se crearon {count} documentos de control para el sistema paginado")
        
        # Mostrar algunas estadísticas finales
        for empresa in empresas:
            if not empresa:
                continue
                
            doc = collections["Estadisticas"].find_one({"_id": f"processed_documents:{empresa}"})
            if doc:
                total_ids = 0
                for page in doc.get("processed_ids", {}).values():
                    total_ids += len(page)
                    
                logger.info(f"Empresa '{empresa}': {total_ids} documentos registrados en {doc.get('current_page', 0)} páginas")
                
        logger.info("¡Recálculo de estadísticas completado con éxito!")
        
    except Exception as e:
        logger.error(f"Error durante el recálculo de estadísticas: {e}")
        import traceback
        logger.error(traceback.format_exc())

if __name__ == "__main__":
    logger.info("=== INICIANDO RECÁLCULO COMPLETO DE ESTADÍSTICAS ===")
    recalculate_stats_for_all_companies()
    logger.info("=== PROCESO DE RECÁLCULO FINALIZADO ===") 