import os
import logging
from datetime import datetime
from google.cloud import bigquery
from google.oauth2 import service_account
from backend.database import collections

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ruta al archivo de credenciales
CREDENTIALS_PATH = "/Users/jesusmachta/Desktop/Tesis/app-turnos-farmacia-289dc7b54113.json"
# ID completo de la tabla en formato: proyecto.dataset.tabla
TABLE_ID = "app-turnos-farmacia.StoresDataChat.StoresDataChat"
# IDs separados para mayor claridad
PROJECT_ID = "app-turnos-farmacia"
DATASET_ID = "StoresDataChat"
TABLE_NAME = "StoresDataChat"

def get_bigquery_client():
    """Configura y retorna un cliente de BigQuery usando las credenciales."""
    try:
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_PATH,
            scopes=["https://www.googleapis.com/auth/bigquery"]
        )
        return bigquery.Client(credentials=credentials, project=credentials.project_id)
    except Exception as e:
        logger.error(f"Error al configurar BigQuery: {e}")
        raise

def create_dataset_and_table_if_not_exist():
    """Crea el dataset y la tabla en BigQuery si no existen."""
    client = get_bigquery_client()
    
    # Verificar si el dataset existe, si no, crearlo
    dataset_ref = client.dataset(DATASET_ID)
    try:
        client.get_dataset(dataset_ref)
        logger.info(f"Dataset {DATASET_ID} ya existe")
    except Exception as e:
        logger.info(f"Dataset {DATASET_ID} no existe, creándolo...")
        dataset = bigquery.Dataset(dataset_ref)
        dataset.location = "US"  # Puedes cambiar la ubicación según sea necesario
        dataset = client.create_dataset(dataset)
        logger.info(f"Dataset {DATASET_ID} creado exitosamente")
    
    # Verificar si la tabla existe, si no, crearla
    table_ref = dataset_ref.table(TABLE_NAME)
    try:
        client.get_table(table_ref)
        logger.info(f"Tabla {TABLE_NAME} ya existe")
    except Exception as e:
        logger.info(f"Tabla {TABLE_NAME} no existe, creándola...")
        
        # Definir el esquema de la tabla
        schema = [
            bigquery.SchemaField("id", "INTEGER", mode="REQUIRED"),
            bigquery.SchemaField("date", "DATE"),
            bigquery.SchemaField("time", "STRING"),
            bigquery.SchemaField("id_camara", "INTEGER"),
            bigquery.SchemaField("categoria_producto", "STRING"),
            bigquery.SchemaField("empresa", "STRING"),
            bigquery.SchemaField("gender", "STRING"),
            bigquery.SchemaField("age_range_low", "INTEGER"),
            bigquery.SchemaField("age_range_high", "INTEGER"),
            bigquery.SchemaField("emotions", "STRING"),
            bigquery.SchemaField("sync_timestamp", "TIMESTAMP"),
        ]
        
        # Crear la tabla
        table = bigquery.Table(table_ref, schema=schema)
        table = client.create_table(table)
        logger.info(f"Tabla {TABLE_NAME} creada exitosamente")

def get_last_synced_id():
    """Obtiene el último ID sincronizado desde la colección de control."""
    sync_record = collections["BigQuerySync"].find_one({"collection": "Persona_AR"})
    if sync_record:
        return sync_record["last_id"]
    return 0

def update_last_synced_id(last_id):
    """Actualiza el último ID sincronizado."""
    collections["BigQuerySync"].update_one(
        {"collection": "Persona_AR"},
        {"$set": {"last_id": last_id, "last_sync": datetime.now()}},
        upsert=True
    )

def prepare_bigquery_row(doc):
    """Prepara un documento de MongoDB para inserción en BigQuery."""
    return {
        "id": doc["id"],
        "date": doc.get("date"),
        "time": doc.get("time"),
        "id_camara": doc.get("id_camara"),
        "categoria_producto": doc.get("categoria_producto"),
        "empresa": doc.get("empresa"),
        "gender": doc.get("gender"),
        "age_range_low": doc.get("age_range", {}).get("low"),
        "age_range_high": doc.get("age_range", {}).get("high"),
        "emotions": doc.get("emotions"),
        "sync_timestamp": datetime.now().isoformat()
    }

def sync_data_to_bigquery(batch_size=100, force_full_sync=False):
    """
    Sincroniza datos desde MongoDB a BigQuery de forma progresiva.
    
    Args:
        batch_size: Número de documentos a procesar por lote
        force_full_sync: Si es True, sincroniza todos los documentos sin importar el último ID
    
    Returns:
        dict: Resultados de la sincronización
    """
    try:
        # Inicializar cliente BigQuery
        client = get_bigquery_client()
        
        # Asegurar que el dataset y la tabla existan
        create_dataset_and_table_if_not_exist()
        
        # Obtener último ID sincronizado
        last_id = 0 if force_full_sync else get_last_synced_id()
        logger.info(f"Último ID sincronizado: {last_id}")
        
        # Preparar consulta
        query = {} if force_full_sync else {"id": {"$gt": last_id}}
        
        # Contar total de documentos a sincronizar
        total_docs = collections["Persona_AR"].count_documents(query)
        logger.info(f"Total de documentos a sincronizar: {total_docs}")
        
        if total_docs == 0:
            return {"success": True, "records_synced": 0, "message": "No hay nuevos documentos para sincronizar"}
        
        # Procesar documentos en lotes
        processed = 0
        max_id = last_id
        
        # Usamos un cursor para procesar en lotes
        cursor = collections["Persona_AR"].find(query).sort("id", 1)
        
        while processed < total_docs:
            # Preparar lote actual
            batch = []
            batch_count = 0
            
            for doc in cursor:
                batch.append(prepare_bigquery_row(doc))
                max_id = max(max_id, doc["id"])
                batch_count += 1
                processed += 1
                
                if batch_count >= batch_size:
                    break
            
            # Insertar lote en BigQuery
            if batch:
                errors = client.insert_rows_json(TABLE_ID, batch)
                
                if errors:
                    logger.error(f"Errores al insertar en BigQuery: {errors}")
                    return {
                        "success": False, 
                        "records_synced": processed - batch_count,
                        "errors": errors
                    }
                else:
                    # Actualizar último ID sincronizado
                    update_last_synced_id(max_id)
                    logger.info(f"Sincronizados {batch_count} documentos a BigQuery. Progreso: {processed}/{total_docs}")
            
            # Si procesamos menos documentos que el tamaño del lote, hemos terminado
            if batch_count < batch_size:
                break
        
        return {
            "success": True,
            "records_synced": processed,
            "message": f"Sincronización completada. {processed} documentos procesados."
        }
        
    except Exception as e:
        logger.error(f"Error durante la sincronización: {e}")
        return {"success": False, "error": str(e)}

def reset_sync_status():
    """Reinicia el estado de sincronización para forzar una sincronización completa."""
    collections["BigQuerySync"].delete_one({"collection": "Persona_AR"})
    logger.info("Estado de sincronización reiniciado")
    return {"success": True, "message": "Estado de sincronización reiniciado"}

if __name__ == "__main__":
    # Ejecutar sincronización como script independiente
    import argparse
    
    parser = argparse.ArgumentParser(description='Sincronizar datos de MongoDB a BigQuery')
    parser.add_argument('--reset', action='store_true', help='Reiniciar estado de sincronización')
    parser.add_argument('--full', action='store_true', help='Realizar sincronización completa')
    parser.add_argument('--batch', type=int, default=100, help='Tamaño del lote')
    
    args = parser.parse_args()
    
    if args.reset:
        result = reset_sync_status()
        print(result["message"])
    
    result = sync_data_to_bigquery(batch_size=args.batch, force_full_sync=args.full)
    print(result["message"] if "message" in result else f"Error: {result.get('error', 'Desconocido')}") 