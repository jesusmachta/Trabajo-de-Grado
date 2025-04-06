from backend.database import collections
from datetime import datetime

persona_collection = collections["Persona_AR"]

def get_emotion_comparison():
    """
    Compara las emociones positivas (HAPPY) y negativas (SAD) por día de la semana.
    Revisa todos los datos históricos de la colección Persona_AR.
    :return: JSON con la emoción predominante por día de la semana.
    """
    try:
        # Diccionarios para contar emociones por día de la semana
        emotion_counts = {
            "Monday": {"HAPPY": 0, "SAD": 0},
            "Tuesday": {"HAPPY": 0, "SAD": 0},
            "Wednesday": {"HAPPY": 0, "SAD": 0},
            "Thursday": {"HAPPY": 0, "SAD": 0},
            "Friday": {"HAPPY": 0, "SAD": 0},
            "Saturday": {"HAPPY": 0, "SAD": 0},
            "Sunday": {"HAPPY": 0, "SAD": 0},
        }

        # Obtener todos los documentos de la colección Persona_AR
        personas = persona_collection.find({}, {"date": 1, "emotions": 1})

        for persona in personas:
            # Obtener la fecha y la emoción
            date_obj = persona.get("date")  # MongoDB devuelve un objeto datetime si el campo es de tipo date
            emotion = persona.get("emotions", "").upper()

            if not date_obj or not emotion:
                continue  # Saltar si faltan datos

            # Obtener el día de la semana
            if isinstance(date_obj, str):
                date_obj = datetime.strptime(date_obj, "%Y-%m-%d")  # Convertir a datetime si es string
            day_of_week = date_obj.strftime("%A")  # Obtener el día de la semana (Monday, Tuesday, etc.)

            # Contar la emoción
            if emotion in ["HAPPY", "SAD"]:
                emotion_counts[day_of_week][emotion] += 1

        # Determinar la emoción predominante por día de la semana
        emotion_comparison = {}
        for day, counts in emotion_counts.items():
            if counts["HAPPY"] > counts["SAD"]:
                emotion_comparison[day] = {"predominant_emotion": "HAPPY", "count": counts["HAPPY"]}
            elif counts["SAD"] > counts["HAPPY"]:
                emotion_comparison[day] = {"predominant_emotion": "SAD", "count": counts["SAD"]}
            else:
                emotion_comparison[day] = {"predominant_emotion": "TIE", "count": counts["HAPPY"]}  # Empate

        return emotion_comparison

    except Exception as e:
        raise Exception(f"Unexpected error: {e}")