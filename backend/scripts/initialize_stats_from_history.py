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

# Añadir el directorio raíz al path para importar los módulos
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.statistics.incremental_stats import initialize_statistics, update_statistics_on_insert
from backend.database import collections

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
        logger.info("Inicializando documentos de estadísticas...")
        initialize_statistics()

        # Contar cuántos registros hay que procesar
        total_records = collections["Persona_AR"].count_documents({})
        logger.info(f"Procesando {total_records} registros históricos de PersonaAR...")

        # Procesar registros históricos
        processed = 0
        batch_size = 100  # Procesar en lotes para mostrar progreso
        
        cursor = collections["Persona_AR"].find().sort("id", 1)  # Ordenar por ID para procesar en orden cronológico
        
        for document in cursor:
            # Actualizar estadísticas incrementalmente
            update_statistics_on_insert(document)
            
            processed += 1
            if processed % batch_size == 0:
                logger.info(f"Procesados {processed}/{total_records} registros ({processed/total_records*100:.1f}%)")
        
        logger.info(f"Procesamiento completado! {processed} registros procesados.")
        logger.info("Las estadísticas han sido inicializadas correctamente.")
    
    except Exception as e:
        logger.error(f"Error durante la inicialización de estadísticas: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 