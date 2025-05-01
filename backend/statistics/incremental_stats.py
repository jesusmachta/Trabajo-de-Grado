from backend.database import collections
from datetime import datetime, timedelta
import logging
from typing import Dict, Any, List, Optional
import pymongo
from collections import defaultdict

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def initialize_statistics():
    """
    Inicializa los documentos de estadísticas en la colección Estadisticas si no existen.
    También verifica si es necesario recalcular las estadísticas desde los datos históricos
    si se detecta que faltan documentos.
    """
    need_recalculation = False
    
    # Lista de estadísticas a inicializar
    stats_docs = [
        {
            "_id": "peak_hours", 
            "description": "Horas pico por día de la semana",
            "data": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
            "daily_counts": {"Monday": {}, "Tuesday": {}, "Wednesday": {}, "Thursday": {}, "Friday": {}, "Saturday": {}, "Sunday": {}},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "least_busy_hours", 
            "description": "Horas menos concurridas por día de la semana",
            "data": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
            "daily_counts": {"Monday": {}, "Tuesday": {}, "Wednesday": {}, "Thursday": {}, "Friday": {}, "Saturday": {}, "Sunday": {}},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "most_busy_day", 
            "description": "Día más concurrido de la semana",
            "data": {"day": "", "count": 0},
            "weekly_counts": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "least_busy_day", 
            "description": "Día menos concurrido de la semana",
            "data": {"day": "", "count": 0},
            "weekly_counts": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "most_visited_category", 
            "description": "Categoría más visitada",
            "daily": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}}
            "weekly": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}} (fecha es lunes de esa semana)
            "monthly": {},  # {"YYYY-MM": {"category": "nombre", "count": N}}
            "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "least_visited_category", 
            "description": "Categoría menos visitada",
            "daily": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}}
            "weekly": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}} (fecha es lunes de esa semana)
            "monthly": {},  # {"YYYY-MM": {"category": "nombre", "count": N}}
            "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "historical_categories", 
            "description": "Categorías más y menos visitadas históricamente",
            "most_visited": {"category": "", "count": 0},
            "least_visited": {"category": "", "count": 0},
            "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "emotion_percentage_by_category", 
            "description": "Porcentaje de emociones por categoría",
            "data": {},  # {"categoria1": {"HAPPY": N%, "SAD": M%, ...}, ...}
            "raw_counts": {},  # {"categoria1": {"HAPPY": N, "SAD": M, ...}, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "most_frequent_emotions",
            "description": "Emociones más frecuentes",
            "data": {},  # {"HAPPY": N, "SAD": M, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "age_distribution",
            "description": "Distribución por edades",
            "weekly": {},  # {"YYYY-MM-DD": {"0-18": N, "19-30": M, ...}}
            "monthly": {},  # {"YYYY-MM": {"0-18": N, "19-30": M, ...}}
            "overall": {"0-18": 0, "19-30": 0, "31-45": 0, "46-60": 0, "60+": 0},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "gender_distribution",
            "description": "Distribución por género",
            "weekly": {},  # {"YYYY-MM-DD": {"Male": N, "Female": M}}
            "monthly": {},  # {"YYYY-MM": {"Male": N, "Female": M}}
            "overall": {"Male": 0, "Female": 0},
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "emotion_comparison",
            "description": "Comparación de emociones positivas y negativas",
            "weekly": {},  # {"YYYY-MM-DD": {"day": "Monday", "HAPPY": N, "SAD": M}}
            "monthly": {},  # {"YYYY-MM": {"HAPPY": N, "SAD": M}}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "preferred_category_by_gender",
            "description": "Categorías preferidas por género",
            "data": {
                "Male": {"category": "", "count": 0},
                "Female": {"category": "", "count": 0}
            },
            "raw_counts": {
                "Male": {},  # {"categoria1": N, "categoria2": M, ...}
                "Female": {}  # {"categoria1": N, "categoria2": M, ...}
            },
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "top_successful_categories",
            "description": "Categorías que generan más emociones positivas",
            "data": [],  # [{"category": "nombre", "happy_percentage": N%}, ...]
            "raw_counts": {},  # {"categoria1": {"HAPPY": N, "total": M}, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "emotional_differences_by_category",
            "description": "Emociones por género en cada categoría de productos",
            "data": {},  # {"categoria1": {"male": {"HAPPY": N, ...}, "female": {"SAD": M, ...}}, ...}
            "last_updated": datetime.utcnow().isoformat()
        },
        {
            "_id": "age_gender_distribution_by_category",
            "description": "Combinaciones de género y edad más frecuentes por categoría",
            "data": {},  # {"categoria1": [{"gender": "Male", "age_range": "19-30", "count": N}, ...], ...}
            "raw_counts": {},  # {"categoria1": {"Male": {"0-18": N, ...}, "Female": {...}}, ...}
            "last_updated": datetime.utcnow().isoformat()
        }
    ]
    
    # Inicializar documentos si no existen
    for doc in stats_docs:
        if collections["Estadisticas"].count_documents({"_id": doc["_id"]}) == 0:
            collections["Estadisticas"].insert_one(doc)
            logger.info(f"Inicializado documento de estadísticas: {doc['_id']}")
            need_recalculation = True  # Marcar para recalcular si se creó algún documento
    
    # Contar documentos en Persona_AR
    persona_count = collections["Persona_AR"].count_documents({})
    
    # Si se necesita recalcular (porque faltaban documentos) y hay datos en Persona_AR
    if need_recalculation and persona_count > 0:
        logger.info("Se detectaron documentos de estadísticas faltantes, recalculando desde datos históricos...")
        recalculate_all_statistics()

def recalculate_all_statistics():
    """
    Recalcula todas las estadísticas desde cero usando los datos históricos de Persona_AR.
    Esta función procesa todos los documentos de la colección Persona_AR y actualiza
    todos los documentos de estadísticas.
    """
    try:
        logger.info("Iniciando recálculo completo de estadísticas desde datos históricos...")
        
        # Reiniciar los documentos de estadísticas a su estado inicial
        reset_statistics_documents()
        
        # Contar documentos para mostrar progreso
        total_docs = collections["Persona_AR"].count_documents({})
        if total_docs == 0:
            logger.info("No hay documentos en Persona_AR para recalcular estadísticas.")
            return
            
        processed = 0
        
        # Procesar todos los documentos de Persona_AR
        cursor = collections["Persona_AR"].find({}).sort("date", pymongo.ASCENDING)
        
        # Lista para almacenar documentos con errores
        error_docs = []
        
        for document in cursor:
            try:
                update_statistics_on_insert(document)
                processed += 1
                
                # Mostrar progreso cada 100 documentos
                if processed % 100 == 0 or processed == total_docs:
                    logger.info(f"Procesados {processed}/{total_docs} documentos ({processed/total_docs*100:.1f}%)")
            except Exception as doc_error:
                # Registrar error y continuar con el siguiente documento
                doc_id = document.get('id', 'desconocido')
                error_docs.append(doc_id)
                logger.error(f"Error procesando documento {doc_id}: {doc_error}")
                continue
        
        # Verificar si se han procesado documentos
        if processed == 0:
            logger.warning("No se procesaron documentos durante el recálculo.")
        else:
            logger.info(f"Recálculo de estadísticas completado. Procesados {processed} documentos.")
            
        # Informar sobre errores
        if error_docs:
            logger.warning(f"Hubo errores al procesar {len(error_docs)} documentos durante el recálculo.")
    except Exception as e:
        logger.error(f"Error en recalculate_all_statistics: {e}")
        import traceback
        logger.error(traceback.format_exc())

def reset_statistics_documents():
    """
    Reinicia todos los documentos de estadísticas a su estado inicial,
    manteniendo la estructura pero limpiando completamente los datos.
    """
    try:
        logger.info("Limpiando completamente todos los documentos de estadísticas...")
        
        # ENFOQUE RADICAL: Eliminar y recrear todos los documentos
        
        # 1. Lista de IDs de documentos de estadísticas
        stat_ids = [
            "peak_hours", "least_busy_hours", "most_busy_day", "least_busy_day",
            "most_visited_category", "least_visited_category", "historical_categories",
            "emotion_percentage_by_category", "most_frequent_emotions", "age_distribution",
            "gender_distribution", "emotion_comparison", "preferred_category_by_gender",
            "top_successful_categories", "emotional_differences_by_category",
            "age_gender_distribution_by_category"
        ]
        
        # 2. Eliminar todos los documentos de estadísticas existentes
        for doc_id in stat_ids:
            collections["Estadisticas"].delete_one({"_id": doc_id})
            logger.info(f"Eliminado documento de estadísticas: {doc_id}")
        
        # 3. Recrear los documentos desde cero
        # Lista de estadísticas a inicializar (mismo esquema que en initialize_statistics)
        stats_docs = [
            {
                "_id": "peak_hours", 
                "description": "Horas pico por día de la semana",
                "data": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
                "daily_counts": {"Monday": {}, "Tuesday": {}, "Wednesday": {}, "Thursday": {}, "Friday": {}, "Saturday": {}, "Sunday": {}},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "least_busy_hours", 
                "description": "Horas menos concurridas por día de la semana",
                "data": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
                "daily_counts": {"Monday": {}, "Tuesday": {}, "Wednesday": {}, "Thursday": {}, "Friday": {}, "Saturday": {}, "Sunday": {}},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "most_busy_day", 
                "description": "Día más concurrido de la semana",
                "data": {"day": "", "count": 0},
                "weekly_counts": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "least_busy_day", 
                "description": "Día menos concurrido de la semana",
                "data": {"day": "", "count": 0},
                "weekly_counts": {"Monday": 0, "Tuesday": 0, "Wednesday": 0, "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "most_visited_category", 
                "description": "Categoría más visitada",
                "daily": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}}
                "weekly": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}} (fecha es lunes de esa semana)
                "monthly": {},  # {"YYYY-MM": {"category": "nombre", "count": N}}
                "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "least_visited_category", 
                "description": "Categoría menos visitada",
                "daily": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}}
                "weekly": {},  # {"YYYY-MM-DD": {"category": "nombre", "count": N}} (fecha es lunes de esa semana)
                "monthly": {},  # {"YYYY-MM": {"category": "nombre", "count": N}}
                "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "historical_categories", 
                "description": "Categorías más y menos visitadas históricamente",
                "most_visited": {"category": "", "count": 0},
                "least_visited": {"category": "", "count": 0},
                "category_counts": {},  # {"categoria1": N, "categoria2": M, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "emotion_percentage_by_category", 
                "description": "Porcentaje de emociones por categoría",
                "data": {},  # {"categoria1": {"HAPPY": N%, "SAD": M%, ...}, ...}
                "raw_counts": {},  # {"categoria1": {"HAPPY": N, "SAD": M, ...}, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "most_frequent_emotions",
                "description": "Emociones más frecuentes",
                "data": {},  # {"HAPPY": N, "SAD": M, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "age_distribution",
                "description": "Distribución por edades",
                "weekly": {},  # {"YYYY-MM-DD": {"0-18": N, "19-30": M, ...}}
                "monthly": {},  # {"YYYY-MM": {"0-18": N, "19-30": M, ...}}
                "overall": {"0-18": 0, "19-30": 0, "31-45": 0, "46-60": 0, "60+": 0},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "gender_distribution",
                "description": "Distribución por género",
                "weekly": {},  # {"YYYY-MM-DD": {"Male": N, "Female": M}}
                "monthly": {},  # {"YYYY-MM": {"Male": N, "Female": M}}
                "overall": {"Male": 0, "Female": 0},
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "emotion_comparison",
                "description": "Comparación de emociones positivas y negativas",
                "weekly": {},  # {"YYYY-MM-DD": {"day": "Monday", "HAPPY": N, "SAD": M}}
                "monthly": {},  # {"YYYY-MM": {"HAPPY": N, "SAD": M}}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "preferred_category_by_gender",
                "description": "Categorías preferidas por género",
                "data": {
                    "Male": {"category": "", "count": 0},
                    "Female": {"category": "", "count": 0}
                },
                "raw_counts": {
                    "Male": {},  # {"categoria1": N, "categoria2": M, ...}
                    "Female": {}  # {"categoria1": N, "categoria2": M, ...}
                },
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "top_successful_categories",
                "description": "Categorías que generan más emociones positivas",
                "data": [],  # [{"category": "nombre", "happy_percentage": N%}, ...]
                "raw_counts": {},  # {"categoria1": {"HAPPY": N, "total": M}, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "emotional_differences_by_category",
                "description": "Emociones por género en cada categoría de productos",
                "data": {},  # {"categoria1": {"male": {"HAPPY": N, ...}, "female": {"SAD": M, ...}}, ...}
                "last_updated": datetime.utcnow().isoformat()
            },
            {
                "_id": "age_gender_distribution_by_category",
                "description": "Combinaciones de género y edad más frecuentes por categoría",
                "data": {},  # {"categoria1": [{"gender": "Male", "age_range": "19-30", "count": N}, ...], ...}
                "raw_counts": {},  # {"categoria1": {"Male": {"0-18": N, ...}, "Female": {...}}, ...}
                "last_updated": datetime.utcnow().isoformat()
            }
        ]
        
        # Crear nuevos documentos desde cero
        for doc in stats_docs:
            collections["Estadisticas"].insert_one(doc)
            logger.info(f"Recreado documento de estadísticas: {doc['_id']}")
        
        logger.info("Documentos de estadísticas reiniciados completamente")
    except Exception as e:
        logger.error(f"Error en reset_statistics_documents: {e}")
        import traceback
        logger.error(traceback.format_exc())

def get_age_group(age_low: int, age_high: int) -> str:
    """Determina el grupo de edad basado en el rango de edad."""
    avg_age = (age_low + age_high) / 2
    
    if avg_age <= 18:
        return "0-18"
    elif avg_age <= 30:
        return "19-30"
    elif avg_age <= 45:
        return "31-45"
    elif avg_age <= 60:
        return "46-60"
    else:
        return "60+"

def update_statistics_on_insert(document: Dict[str, Any]):
    """
    Actualiza todas las estadísticas de forma incremental cuando se inserta un nuevo documento.
    
    Args:
        document: El documento recién insertado en la colección Persona_AR.
    """
    try:
        # Extraer información relevante del documento
        date_str = document.get("date")
        time_str = document.get("time")
        category = document.get("categoria_producto")
        gender = document.get("gender")
        age_range = document.get("age_range", {})
        emotion = document.get("emotions")
        
        if not all([date_str, time_str, category, gender, emotion, age_range]):
            logger.warning(f"Documento incompleto, no se puede actualizar estadísticas: {document}")
            return
        
        # Convertir la fecha a objeto datetime para manipulación
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        day_of_week = date_obj.strftime("%A")  # Lunes, Martes, etc.
        month_str = date_str[:7]  # YYYY-MM
        
        # Obtener la hora del día
        hour = int(time_str.split(":")[0])
        
        # Calcular el lunes de la semana actual (para estadísticas semanales)
        monday_of_week = (date_obj - timedelta(days=date_obj.weekday())).strftime("%Y-%m-%d")
        
        # Determinar el grupo de edad
        age_low = age_range.get("low", 0)
        age_high = age_range.get("high", 0)
        age_group = get_age_group(age_low, age_high)
        
        # Actualizar horas pico
        update_peak_hours(day_of_week, hour)
        
        # Actualizar horas menos concurridas
        update_least_busy_hours(day_of_week, hour)
        
        # Actualizar días más y menos concurridos
        update_busy_days(day_of_week)
        
        # Actualizar categorías más y menos visitadas
        update_visited_categories(category, date_str, monday_of_week, month_str)
        
        # Actualizar porcentajes de emociones por categoría
        update_emotion_percentage_by_category(category, emotion)
        
        # Actualizar emociones más frecuentes
        update_most_frequent_emotions(emotion)
        
        # Actualizar distribución de edad
        update_age_distribution(age_group, monday_of_week, month_str)
        
        # Actualizar distribución de género
        update_gender_distribution(gender, monday_of_week, month_str)
        
        # Actualizar comparación de emociones
        update_emotion_comparison(emotion, day_of_week, monday_of_week, month_str)
        
        # Actualizar categorías preferidas por género
        update_preferred_category_by_gender(gender, category)
        
        # Actualizar categorías exitosas (emociones positivas)
        update_top_successful_categories(category, emotion)
        
        # Actualizar diferencias emocionales por categoría y género
        update_emotional_differences_by_category(category, gender, emotion)
        
        # Actualizar distribución de edad y género por categoría
        update_age_gender_distribution_by_category(category, gender, age_group)
        
        logger.info(f"Estadísticas actualizadas exitosamente para documento: {document.get('id')}")
        
    except Exception as e:
        logger.error(f"Error al actualizar estadísticas: {e}")

def update_peak_hours(day_of_week: str, hour: int):
    """Actualiza las horas pico por día de la semana."""
    try:
        # Obtener el documento de estadísticas
        stats = collections["Estadisticas"].find_one({"_id": "peak_hours"})
        if not stats:
            logger.warning("Documento de estadísticas 'peak_hours' no encontrado")
            return
        
        # Inicializar conteo para esta hora si no existe
        daily_counts = stats.get("daily_counts", {})
        day_counts = daily_counts.get(day_of_week, {})
        
        # Convertir claves de horas a enteros para manipulación
        hour_counts = {int(h): count for h, count in day_counts.items()}
        
        # Incrementar contador para esta hora
        hour_counts[hour] = hour_counts.get(hour, 0) + 1
        
        # Encontrar la hora pico (con más visitas)
        peak_hour = max(hour_counts.items(), key=lambda x: x[1])[0] if hour_counts else 0
        
        # Actualizar el documento
        collections["Estadisticas"].update_one(
            {"_id": "peak_hours"},
            {"$set": {
                f"data.{day_of_week}": peak_hour,
                f"daily_counts.{day_of_week}": {str(h): c for h, c in hour_counts.items()},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_peak_hours: {e}")

def update_least_busy_hours(day_of_week: str, hour: int):
    """Actualiza las horas menos concurridas por día de la semana."""
    try:
        # Obtener el documento de estadísticas
        stats = collections["Estadisticas"].find_one({"_id": "least_busy_hours"})
        if not stats:
            logger.warning("Documento de estadísticas 'least_busy_hours' no encontrado")
            return
        
        # Inicializar conteo para esta hora si no existe
        daily_counts = stats.get("daily_counts", {})
        day_counts = daily_counts.get(day_of_week, {})
        
        # Convertir claves de horas a enteros para manipulación
        hour_counts = {int(h): count for h, count in day_counts.items()}
        
        # Inicializar contadores para horas de operación (6-23) si no existen
        for h in range(6, 24):
            if h not in hour_counts:
                hour_counts[h] = 0
        
        # Incrementar contador para esta hora
        if 6 <= hour <= 23:  # Solo contar horas de operación
            hour_counts[hour] = hour_counts.get(hour, 0) + 1
        
        # Encontrar la hora menos concurrida (con menos visitas)
        least_busy_hours = [h for h in range(6, 24) if h in hour_counts]
        least_busy_hour = min(least_busy_hours, key=lambda h: hour_counts.get(h, 0)) if least_busy_hours else 0
        
        # Actualizar el documento
        collections["Estadisticas"].update_one(
            {"_id": "least_busy_hours"},
            {"$set": {
                f"data.{day_of_week}": least_busy_hour,
                f"daily_counts.{day_of_week}": {str(h): c for h, c in hour_counts.items()},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_least_busy_hours: {e}")

def update_busy_days(day_of_week: str):
    """Actualiza los días más y menos concurridos de la semana."""
    try:
        # Actualizar día más concurrido
        most_busy = collections["Estadisticas"].find_one({"_id": "most_busy_day"})
        if not most_busy:
            logger.warning("Documento de estadísticas 'most_busy_day' no encontrado")
            return
        
        weekly_counts = most_busy.get("weekly_counts", {})
        weekly_counts[day_of_week] = weekly_counts.get(day_of_week, 0) + 1
        
        # Encontrar el día más concurrido
        most_busy_day = max(weekly_counts.items(), key=lambda x: x[1])
        
        collections["Estadisticas"].update_one(
            {"_id": "most_busy_day"},
            {"$set": {
                "data": {"day": most_busy_day[0], "count": most_busy_day[1]},
                "weekly_counts": weekly_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        
        # Actualizar día menos concurrido
        least_busy = collections["Estadisticas"].find_one({"_id": "least_busy_day"})
        if not least_busy:
            logger.warning("Documento de estadísticas 'least_busy_day' no encontrado")
            return
        
        weekly_counts = least_busy.get("weekly_counts", {})
        weekly_counts[day_of_week] = weekly_counts.get(day_of_week, 0) + 1
        
        # Encontrar el día menos concurrido
        least_busy_day = min(weekly_counts.items(), key=lambda x: x[1])
        
        collections["Estadisticas"].update_one(
            {"_id": "least_busy_day"},
            {"$set": {
                "data": {"day": least_busy_day[0], "count": least_busy_day[1]},
                "weekly_counts": weekly_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_busy_days: {e}")

def update_visited_categories(category: str, date_str: str, monday_of_week: str, month_str: str):
    """Actualiza las categorías más y menos visitadas."""
    try:
        # Actualizar categorías más y menos visitadas
        most_visited = collections["Estadisticas"].find_one({"_id": "most_visited_category"})
        least_visited = collections["Estadisticas"].find_one({"_id": "least_visited_category"})
        historical = collections["Estadisticas"].find_one({"_id": "historical_categories"})
        
        if not all([most_visited, least_visited, historical]):
            logger.warning("Documentos de categorías visitadas no encontrados")
            return
        
        # Actualizar contadores de categorías
        for doc in [most_visited, least_visited, historical]:
            category_counts = doc.get("category_counts", {})
            category_counts[category] = category_counts.get(category, 0) + 1
            
            # Actualizar documento
            collections["Estadisticas"].update_one(
                {"_id": doc["_id"]},
                {"$set": {"category_counts": category_counts, "last_updated": datetime.utcnow().isoformat()}}
            )
        
        # Actualizar más visitada por período
        most_cat_counts = most_visited["category_counts"]
        most_cat = max(most_cat_counts.items(), key=lambda x: x[1]) if most_cat_counts else ("", 0)
        
        collections["Estadisticas"].update_one(
            {"_id": "most_visited_category"},
            {"$set": {
                f"daily.{date_str}": {"category": most_cat[0], "count": most_cat[1]},
                f"weekly.{monday_of_week}": {"category": most_cat[0], "count": most_cat[1]},
                f"monthly.{month_str}": {"category": most_cat[0], "count": most_cat[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        
        # Actualizar menos visitada por período
        least_cat_counts = least_visited["category_counts"]
        # Solo considerar categorías con al menos una visita
        active_categories = {k: v for k, v in least_cat_counts.items() if v > 0}
        least_cat = min(active_categories.items(), key=lambda x: x[1]) if active_categories else ("", 0)
        
        collections["Estadisticas"].update_one(
            {"_id": "least_visited_category"},
            {"$set": {
                f"daily.{date_str}": {"category": least_cat[0], "count": least_cat[1]},
                f"weekly.{monday_of_week}": {"category": least_cat[0], "count": least_cat[1]},
                f"monthly.{month_str}": {"category": least_cat[0], "count": least_cat[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        
        # Actualizar históricos
        hist_counts = historical["category_counts"]
        most_hist = max(hist_counts.items(), key=lambda x: x[1]) if hist_counts else ("", 0)
        active_hist = {k: v for k, v in hist_counts.items() if v > 0}
        least_hist = min(active_hist.items(), key=lambda x: x[1]) if active_hist else ("", 0)
        
        collections["Estadisticas"].update_one(
            {"_id": "historical_categories"},
            {"$set": {
                "most_visited": {"category": most_hist[0], "count": most_hist[1]},
                "least_visited": {"category": least_hist[0], "count": least_hist[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_visited_categories: {e}")

def update_emotion_percentage_by_category(category: str, emotion: str):
    """Actualiza los porcentajes de emociones por categoría."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotion_percentage_by_category"})
        if not stats:
            logger.warning("Documento 'emotion_percentage_by_category' no encontrado")
            return
        
        # Obtener conteos actuales
        raw_counts = stats.get("raw_counts", {})
        category_emotions = raw_counts.get(category, {})
        
        # Incrementar contador para esta emoción
        category_emotions[emotion] = category_emotions.get(emotion, 0) + 1
        
        # Actualizar raw_counts
        raw_counts[category] = category_emotions
        
        # Calcular porcentajes
        data = {}
        for cat, emotions in raw_counts.items():
            total = sum(emotions.values())
            data[cat] = {emotion: round((count / total) * 100, 2) for emotion, count in emotions.items()}
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "emotion_percentage_by_category"},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotion_percentage_by_category: {e}")

def update_most_frequent_emotions(emotion: str):
    """Actualiza las emociones más frecuentes."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "most_frequent_emotions"})
        if not stats:
            logger.warning("Documento 'most_frequent_emotions' no encontrado")
            return
        
        # Obtener conteos actuales
        data = stats.get("data", {})
        
        # Incrementar contador para esta emoción
        data[emotion] = data.get(emotion, 0) + 1
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "most_frequent_emotions"},
            {"$set": {
                "data": data,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_most_frequent_emotions: {e}")

def update_age_distribution(age_group: str, monday_of_week: str, month_str: str):
    """Actualiza la distribución por edades."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "age_distribution"})
        if not stats:
            logger.warning("Documento 'age_distribution' no encontrado")
            return
        
        # Obtener datos actuales
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        overall = stats.get("overall", {})
        
        # Actualizar datos semanales
        week_data = weekly.get(monday_of_week, {})
        week_data[age_group] = week_data.get(age_group, 0) + 1
        weekly[monday_of_week] = week_data
        
        # Actualizar datos mensuales
        month_data = monthly.get(month_str, {})
        month_data[age_group] = month_data.get(age_group, 0) + 1
        monthly[month_str] = month_data
        
        # Actualizar datos globales
        overall[age_group] = overall.get(age_group, 0) + 1
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "age_distribution"},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "overall": overall,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_age_distribution: {e}")

def update_gender_distribution(gender: str, monday_of_week: str, month_str: str):
    """Actualiza la distribución por género."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "gender_distribution"})
        if not stats:
            logger.warning("Documento 'gender_distribution' no encontrado")
            return
        
        # Obtener datos actuales
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        overall = stats.get("overall", {})
        
        # Actualizar datos semanales
        week_data = weekly.get(monday_of_week, {})
        week_data[gender] = week_data.get(gender, 0) + 1
        weekly[monday_of_week] = week_data
        
        # Actualizar datos mensuales
        month_data = monthly.get(month_str, {})
        month_data[gender] = month_data.get(gender, 0) + 1
        monthly[month_str] = month_data
        
        # Actualizar datos globales
        overall[gender] = overall.get(gender, 0) + 1
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "gender_distribution"},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "overall": overall,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_gender_distribution: {e}")

def update_emotion_comparison(emotion: str, day_of_week: str, monday_of_week: str, month_str: str):
    """Actualiza la comparación de emociones positivas y negativas."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotion_comparison"})
        if not stats:
            logger.warning("Documento 'emotion_comparison' no encontrado")
            return
        
        # Obtener datos actuales
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        
        # Solo procesamos HAPPY o SAD para esta estadística
        if emotion not in ["HAPPY", "SAD"]:
            return
        
        # Actualizar datos semanales
        week_data = weekly.get(monday_of_week, {})
        week_data["day"] = day_of_week
        week_data[emotion] = week_data.get(emotion, 0) + 1
        weekly[monday_of_week] = week_data
        
        # Actualizar datos mensuales
        month_data = monthly.get(month_str, {})
        month_data[emotion] = month_data.get(emotion, 0) + 1
        monthly[month_str] = month_data
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "emotion_comparison"},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotion_comparison: {e}")

def update_preferred_category_by_gender(gender: str, category: str):
    """Actualiza las categorías preferidas por género."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "preferred_category_by_gender"})
        if not stats:
            logger.warning("Documento 'preferred_category_by_gender' no encontrado")
            return
        
        # Obtener datos actuales
        raw_counts = stats.get("raw_counts", {})
        
        # Asegurar que existan las entradas para cada género
        if gender not in raw_counts:
            raw_counts[gender] = {}
        
        # Incrementar contador para esta categoría
        gender_categories = raw_counts[gender]
        gender_categories[category] = gender_categories.get(category, 0) + 1
        
        # Encontrar categoría preferida para cada género
        data = stats.get("data", {})
        for g, categories in raw_counts.items():
            if categories:
                preferred = max(categories.items(), key=lambda x: x[1])
                data[g] = {"category": preferred[0], "count": preferred[1]}
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "preferred_category_by_gender"},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_preferred_category_by_gender: {e}")

def update_top_successful_categories(category: str, emotion: str):
    """Actualiza las categorías más exitosas (con más emociones positivas)."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "top_successful_categories"})
        if not stats:
            logger.warning("Documento 'top_successful_categories' no encontrado")
            return
        
        # Obtener datos actuales
        raw_counts = stats.get("raw_counts", {})
        
        # Asegurar que existan las entradas para esta categoría
        if category not in raw_counts:
            raw_counts[category] = {"HAPPY": 0, "total": 0}
        
        # Incrementar contador para esta emoción
        category_counts = raw_counts[category]
        if emotion == "HAPPY":
            category_counts["HAPPY"] = category_counts.get("HAPPY", 0) + 1
        category_counts["total"] = category_counts.get("total", 0) + 1
        
        # Calcular porcentajes y ordenar categorías
        data = []
        for cat, counts in raw_counts.items():
            if counts["total"] > 0:
                happy_percentage = round((counts["HAPPY"] / counts["total"]) * 100, 2)
                data.append({"category": cat, "happy_percentage": happy_percentage})
        
        # Ordenar por porcentaje de felicidad descendente
        data.sort(key=lambda x: x["happy_percentage"], reverse=True)
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "top_successful_categories"},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_top_successful_categories: {e}")

def update_emotional_differences_by_category(category: str, gender: str, emotion: str):
    """Actualiza las emociones predominantes por género en cada categoría."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotional_differences_by_category"})
        if not stats:
            logger.warning("Documento 'emotional_differences_by_category' no encontrado")
            return
        
        # Obtener datos actuales
        raw_counts = stats.get("raw_counts", {})
        
        # Asegurar que existan las entradas para esta categoría y género
        if category not in raw_counts:
            raw_counts[category] = {"Male": {}, "Female": {}}
        if gender not in raw_counts[category]:
            raw_counts[category][gender] = {}
        
        # Incrementar contador para esta emoción
        gender_emotions = raw_counts[category][gender]
        gender_emotions[emotion] = gender_emotions.get(emotion, 0) + 1
        
        # Calcular emoción predominante para cada género en cada categoría
        data = {}
        for cat, genders in raw_counts.items():
            data[cat] = {}
            for g, emotions in genders.items():
                if emotions:
                    predominant = max(emotions.items(), key=lambda x: x[1])[0]
                    data[cat][g] = predominant
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "emotional_differences_by_category"},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotional_differences_by_category: {e}")

def update_age_gender_distribution_by_category(category: str, gender: str, age_group: str):
    """Actualiza las combinaciones de género y edad más frecuentes por categoría."""
    try:
        stats = collections["Estadisticas"].find_one({"_id": "age_gender_distribution_by_category"})
        if not stats:
            logger.warning("Documento 'age_gender_distribution_by_category' no encontrado")
            return
        
        # Obtener datos actuales
        raw_counts = stats.get("raw_counts", {})
        
        # Asegurar que existan las entradas para esta categoría y género
        if category not in raw_counts:
            raw_counts[category] = {"Male": {}, "Female": {}}
        if gender not in raw_counts[category]:
            raw_counts[category][gender] = {}
        
        # Incrementar contador para este grupo de edad
        gender_ages = raw_counts[category][gender]
        gender_ages[age_group] = gender_ages.get(age_group, 0) + 1
        
        # Generar los datos resumidos
        data = {}
        for cat, genders in raw_counts.items():
            cat_combinations = []
            for g, ages in genders.items():
                for age, count in ages.items():
                    cat_combinations.append({"gender": g, "age_range": age, "count": count})
            
            # Ordenar por conteo descendente
            cat_combinations.sort(key=lambda x: x["count"], reverse=True)
            data[cat] = cat_combinations
        
        # Actualizar documento
        collections["Estadisticas"].update_one(
            {"_id": "age_gender_distribution_by_category"},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_age_gender_distribution_by_category: {e}") 