#!/usr/bin/env python
"""
Script para sincronización periódica con BigQuery mediante cron.
Puede ser configurado para ejecutarse automáticamente.

Ejemplos de configuración en crontab:
* Cada hora: 0 * * * * /ruta/al/entorno/python /ruta/al/script/cron_sync_to_bigquery.py >> /ruta/logs/sync_bigquery.log 2>&1
* Diariamente a medianoche: 0 0 * * * /ruta/al/entorno/python /ruta/al/script/cron_sync_to_bigquery.py >> /ruta/logs/sync_bigquery.log 2>&1
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
    """Función principal que ejecuta la sincronización."""
    from backend.scripts.sync_to_bigquery import sync_data_to_bigquery
    
    logger.info("=== Iniciando sincronización periódica con BigQuery ===")
    start_time = datetime.now()
    
    try:
        # Ejecutar sincronización
        result = sync_data_to_bigquery(batch_size=200)  # Procesar hasta 200 documentos por lote
        
        # Registrar resultado
        if result["success"]:
            logger.info(f"Sincronización exitosa: {result['message']}")
        else:
            logger.error(f"Error en sincronización: {result.get('error', 'Desconocido')}")
        
        # Calcular tiempo de ejecución
        execution_time = datetime.now() - start_time
        logger.info(f"Tiempo de ejecución: {execution_time}")
        
    except Exception as e:
        logger.exception(f"Error no controlado durante la sincronización: {e}")
    
    logger.info("=== Fin de sincronización periódica ===\n")

if __name__ == "__main__":
    main() 