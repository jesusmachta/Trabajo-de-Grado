from pymongo import MongoClient

client = MongoClient("mongodb+srv://jesusmachta:tesisjesus@tesiscluster.rxp2l.mongodb.net/?retryWrites=true&w=majority&ssl=true&tlsAllowInvalidCertificates=true")
db = client['TesisBD']
collections = {
    "Persona_AR": db['Persona_AR'],
    "Tipo_Producto": db['Tipo_Producto'],
    "Tipo_Producto_Zona_Camara": db['Tipo_Producto_Zona_Camara'],
    "counters": db['counters'],
    "HeatMap": db['HeatMap']
}

# Inicializar el contador si no existe
if collections['counters'].count_documents({"_id": "persona_id"}) == 0:
    collections['counters'].insert_one({"_id": "persona_id", "seq": 2})