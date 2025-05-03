from pymongo import MongoClient

# Conexión a la base de datos
client = MongoClient("mongodb+srv://jesusmachta:tesisjesus@tesiscluster.rxp2l.mongodb.net/?retryWrites=true&w=majority&ssl=true&tlsAllowInvalidCertificates=true")
db = client['TesisBD']

# Listar todas las colecciones, excluyendo 'counters'
collection_names = [name for name in db.list_collection_names() if name != 'counters']

empresa_value = "CataSus"

total_updated = 0
for collection_name in collection_names:
    collection = db[collection_name]
    result = collection.update_many(
        {},  # Todos los documentos
        {"$set": {"empresa": empresa_value}}
    )
    print(f"Colección '{collection_name}': {result.modified_count} documentos actualizados.")
    total_updated += result.modified_count

print(f"¡Actualización completada! Total de documentos actualizados: {total_updated}") 