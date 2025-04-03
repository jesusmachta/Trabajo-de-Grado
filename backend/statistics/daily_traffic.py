from pymongo import MongoClient
from datetime import datetime
from collections import defaultdict

# Conexión a MongoDB
client = MongoClient("mongodb://localhost:27017/")  # Cambia esto si usas otro URI
db = client["<nombre_de_tu_base_de_datos>"]  # Cambia esto por el nombre de tu base de datos
collection = db["Persona_AR"]

def get_peak_hours():
    """
    Calcula las horas pico de los clientes por día de la semana.
    Devuelve un diccionario con los días de la semana como claves y un conteo de personas por hora.
    """
    # Diccionario para almacenar los resultados
    weekly_traffic = {day: [0] * 24 for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]}

    # Obtener todos los documentos de la colección
    personas = collection.find({}, {"date": 1, "time": 1})

    for persona in personas:
        # Obtener la fecha y la hora
        date_str = persona.get("date")
        time_str = persona.get("time")

        if not date_str or not time_str:
            continue  # Saltar si faltan datos

        # Convertir la fecha a un objeto datetime para obtener el día de la semana
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        day_of_week = date_obj.strftime("%A")  # Obtener el día de la semana (Monday, Tuesday, etc.)

        # Obtener la hora como entero
        hour = int(time_str.split(":")[0])

        # Contabilizar solo las horas entre 6 AM y 12 AM
        if 6 <= hour <= 23:
            weekly_traffic[day_of_week][hour] += 1

    return weekly_traffic