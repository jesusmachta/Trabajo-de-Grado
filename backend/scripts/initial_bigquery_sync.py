#!/usr/bin/env python
"""
Script para la sincronización inicial completa con BigQuery.
Este script realiza los siguientes pasos:
1. Inicializa la colección de control BigQuerySync
2. Reinicia el estado de sincronización para forzar una sincronización completa
3. Ejecuta la sincronización completa

Ejecutar este script una vez cuando se quiera hacer la sincronización inicial
o cuando se necesite resincronizar todos los datos.
"""

import os
import sys
import logging
from datetime import datetime

# Agregar el directorio raíz al path para poder importar correctamente
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
sys.path.append(parent_dir)

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def main():
    """Función principal que ejecuta la sincronización inicial completa."""
    from backend.scripts.initialize_bigquery_sync import initialize_bigquery_sync_collection
    from backend.scripts.sync_to_bigquery import sync_data_to_bigquery, reset_sync_status
    
    logger.info("=== Iniciando sincronización inicial completa con BigQuery ===")
    start_time = datetime.now()
    
    try:
        # Paso 1: Inicializar colección de control
        logger.info("Paso 1: Inicializando colección de control...")
        initialize_bigquery_sync_collection()
        
        # Paso 2: Reiniciar estado de sincronización
        logger.info("Paso 2: Reiniciando estado de sincronización...")
        reset_sync_status()
        
        # Paso 3: Ejecutar sincronización completa
        logger.info("Paso 3: Ejecutando sincronización completa...")
        result = sync_data_to_bigquery(batch_size=100, force_full_sync=True)
        
        # Registrar resultado
        if result["success"]:
            logger.info(f"Sincronización inicial exitosa: {result['message']}")
        else:
            logger.error(f"Error en sincronización inicial: {result.get('error', 'Desconocido')}")
        
        # Calcular tiempo de ejecución
        execution_time = datetime.now() - start_time
        logger.info(f"Tiempo total de ejecución: {execution_time}")
        
    except Exception as e:
        logger.exception(f"Error no controlado durante la sincronización inicial: {e}")
    
    logger.info("=== Fin de sincronización inicial completa ===\n")

if __name__ == "__main__":
    main() 