from pymongo import MongoClient
from datetime import datetime
from pytz import timezone

# Conexión a la base de datos
client = MongoClient("mongodb+srv://jesusmachta:tesisjesus@tesiscluster.rxp2l.mongodb.net/?retryWrites=true&w=majority&ssl=true&tlsAllowInvalidCertificates=true")
db = client['TesisBD']

# Zona horaria de Venezuela (UTC-4)
venezuela_tz = timezone('America/Caracas')

collection = db['Persona_AR']

count = 0
for doc in collection.find():
    update_fields = {}
    # Corrige el campo 'date'
    if 'date' in doc and not isinstance(doc['date'], str):
        # Si es datetime, conviértelo a string en formato YYYY-MM-DD en zona Venezuela
        if isinstance(doc['date'], datetime):
            date_ven = doc['date'].astimezone(venezuela_tz)
            update_fields['date'] = date_ven.strftime('%Y-%m-%d')
        else:
            # Si es otro tipo, intenta convertirlo a string
            update_fields['date'] = str(doc['date'])
    # Corrige el campo 'time'
    if 'time' in doc and not isinstance(doc['time'], str):
        if isinstance(doc['time'], datetime):
            time_ven = doc['time'].astimezone(venezuela_tz)
            update_fields['time'] = time_ven.strftime('%H:%M:%S')
        else:
            update_fields['time'] = str(doc['time'])
    # Si no existe 'time' pero sí 'date', extrae la hora de 'date'
    if 'time' not in doc and 'date' in doc and isinstance(doc['date'], datetime):
        time_ven = doc['date'].astimezone(venezuela_tz)
        update_fields['time'] = time_ven.strftime('%H:%M:%S')
        # También actualiza 'date' si no es string
        update_fields['date'] = time_ven.strftime('%Y-%m-%d')
    if update_fields:
        collection.update_one({'_id': doc['_id']}, {'$set': update_fields})
        count += 1
        print(f"Documento {doc['_id']} corregido: {update_fields}")

print(f"Total de documentos corregidos: {count}") 