from pymongo import MongoClient
client = MongoClient("mongodb+srv://jesusmachta:tesisjesus@tesiscluster.rxp2l.mongodb.net/?retryWrites=true&w=majority&appName=TesisCluster")
db = client['TesisBD']
collections = {
    "Persona_AR": db['Persona_AR'],
    "Tipo_Producto": db['Tipo_Producto'],
    "Tipo_Producto_Zona_Camara": db['Tipo_Producto_Zona_Camara'] 
}


