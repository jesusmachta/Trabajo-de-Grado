import os
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Use environment variables
mongo_uri = os.environ.get("MONGODB_URI")
client = MongoClient(mongo_uri)
db = client['TesisBD']
collections = {
    "Persona_AR": db['Persona_AR'],
    "Tipo_Producto": db['Tipo_Producto'],
    "Tipo_Producto_Zona_Camara": db['Tipo_Producto_Zona_Camara'],
    "counters": db['counters'],
    "HeatMap": db['HeatMap'],
    "Users": db['Users'],
    "Estadisticas": db['Estadisticas'],
    "Empresas": db['Empresas'],
    "Sensors": db['Sensors'],
    "SensorsSettings": db['SensorsSettings'],
    "BigQuerySync": db['BigQuerySync']
}

# Inicializar el contador si no existe
if collections['counters'].count_documents({"_id": "persona_id"}) == 0:
    collections['counters'].insert_one({"_id": "persona_id", "seq": 2})

# Inicializar el contador para user_id si no existe
if collections['counters'].count_documents({"_id": "user_id"}) == 0:
    collections['counters'].insert_one({"_id": "user_id", "seq": 0})