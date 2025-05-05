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
        empresa = document.get("empresa")
        if not all([date_str, time_str, category, gender, emotion, age_range, empresa]):
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
        update_peak_hours(day_of_week, hour, empresa)
        # Actualizar horas menos concurridas
        update_least_busy_hours(day_of_week, hour, empresa)
        # Actualizar días más y menos concurridos
        update_busy_days(day_of_week, empresa)
        # Actualizar categorías más y menos visitadas
        update_visited_categories(category, date_str, monday_of_week, month_str, empresa)
        # Actualizar porcentajes de emociones por categoría
        update_emotion_percentage_by_category(category, emotion, empresa)
        # Actualizar emociones más frecuentes
        update_most_frequent_emotions(emotion, empresa)
        # Actualizar distribución de edad
        update_age_distribution(age_group, monday_of_week, month_str, empresa)
        # Actualizar distribución de género
        update_gender_distribution(gender, monday_of_week, month_str, empresa)
        # Actualizar comparación de emociones
        update_emotion_comparison(emotion, day_of_week, monday_of_week, month_str, empresa)
        # Actualizar categorías preferidas por género
        update_preferred_category_by_gender(gender, category, empresa)
        # Actualizar categorías exitosas (emociones positivas)
        update_top_successful_categories(category, emotion, empresa)
        # Actualizar emociones por género en cada categoría
        update_emotional_differences_by_category(category, gender, emotion, empresa)
        # Actualizar distribución de edad y género por categoría
        update_age_gender_distribution_by_category(category, gender, age_group, empresa)
        logger.info(f"Estadísticas actualizadas exitosamente para documento: {document.get('id')}")
    except Exception as e:
        logger.error(f"Error al actualizar estadísticas: {e}")

def update_peak_hours(day_of_week: str, hour: int, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "peak_hours", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento de estadísticas 'peak_hours' no encontrado para empresa {empresa}")
            return
        daily_counts = stats.get("daily_counts", {})
        day_counts = daily_counts.get(day_of_week, {})
        hour_counts = {int(h): count for h, count in day_counts.items()}
        hour_counts[hour] = hour_counts.get(hour, 0) + 1
        peak_hour = max(hour_counts.items(), key=lambda x: x[1])[0] if hour_counts else 0
        collections["Estadisticas"].update_one(
            {"_id": "peak_hours", "empresa": empresa},
            {"$set": {
                f"data.{day_of_week}": peak_hour,
                f"daily_counts.{day_of_week}": {str(h): c for h, c in hour_counts.items()},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_peak_hours: {e}")

def update_least_busy_hours(day_of_week: str, hour: int, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "least_busy_hours", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento de estadísticas 'least_busy_hours' no encontrado para empresa {empresa}")
            return
        daily_counts = stats.get("daily_counts", {})
        day_counts = daily_counts.get(day_of_week, {})
        hour_counts = {int(h): count for h, count in day_counts.items()}
        for h in range(6, 24):
            if h not in hour_counts:
                hour_counts[h] = 0
        if 6 <= hour <= 23:
            hour_counts[hour] = hour_counts.get(hour, 0) + 1
        least_busy_hours = [h for h in range(6, 24) if h in hour_counts]
        least_busy_hour = min(least_busy_hours, key=lambda h: hour_counts.get(h, 0)) if least_busy_hours else 0
        collections["Estadisticas"].update_one(
            {"_id": "least_busy_hours", "empresa": empresa},
            {"$set": {
                f"data.{day_of_week}": least_busy_hour,
                f"daily_counts.{day_of_week}": {str(h): c for h, c in hour_counts.items()},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_least_busy_hours: {e}")

def update_busy_days(day_of_week: str, empresa: str):
    try:
        most_busy = collections["Estadisticas"].find_one({"_id": "most_busy_day", "empresa": empresa})
        if not most_busy:
            logger.warning(f"Documento de estadísticas 'most_busy_day' no encontrado para empresa {empresa}")
            return
        weekly_counts = most_busy.get("weekly_counts", {})
        weekly_counts[day_of_week] = weekly_counts.get(day_of_week, 0) + 1
        most_busy_day = max(weekly_counts.items(), key=lambda x: x[1])
        collections["Estadisticas"].update_one(
            {"_id": "most_busy_day", "empresa": empresa},
            {"$set": {
                "data": {"day": most_busy_day[0], "count": most_busy_day[1]},
                "weekly_counts": weekly_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        least_busy = collections["Estadisticas"].find_one({"_id": "least_busy_day", "empresa": empresa})
        if not least_busy:
            logger.warning(f"Documento de estadísticas 'least_busy_day' no encontrado para empresa {empresa}")
            return
        weekly_counts = least_busy.get("weekly_counts", {})
        weekly_counts[day_of_week] = weekly_counts.get(day_of_week, 0) + 1
        least_busy_day = min(weekly_counts.items(), key=lambda x: x[1])
        collections["Estadisticas"].update_one(
            {"_id": "least_busy_day", "empresa": empresa},
            {"$set": {
                "data": {"day": least_busy_day[0], "count": least_busy_day[1]},
                "weekly_counts": weekly_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_busy_days: {e}")

def update_visited_categories(category: str, date_str: str, monday_of_week: str, month_str: str, empresa: str):
    try:
        most_visited = collections["Estadisticas"].find_one({"_id": "most_visited_category", "empresa": empresa})
        least_visited = collections["Estadisticas"].find_one({"_id": "least_visited_category", "empresa": empresa})
        historical = collections["Estadisticas"].find_one({"_id": "historical_categories", "empresa": empresa})
        if not all([most_visited, least_visited, historical]):
            logger.warning(f"Documentos de categorías visitadas no encontrados para empresa {empresa}")
            return
        for doc in [most_visited, least_visited, historical]:
            category_counts = doc.get("category_counts", {})
            category_counts[category] = category_counts.get(category, 0) + 1
            collections["Estadisticas"].update_one(
                {"_id": doc["_id"], "empresa": empresa},
                {"$set": {"category_counts": category_counts, "last_updated": datetime.utcnow().isoformat()}}
            )
        most_cat_counts = most_visited["category_counts"]
        most_cat = max(most_cat_counts.items(), key=lambda x: x[1]) if most_cat_counts else ("", 0)
        collections["Estadisticas"].update_one(
            {"_id": "most_visited_category", "empresa": empresa},
            {"$set": {
                f"daily.{date_str}": {"category": most_cat[0], "count": most_cat[1]},
                f"weekly.{monday_of_week}": {"category": most_cat[0], "count": most_cat[1]},
                f"monthly.{month_str}": {"category": most_cat[0], "count": most_cat[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        least_cat_counts = least_visited["category_counts"]
        active_categories = {k: v for k, v in least_cat_counts.items() if v > 0}
        least_cat = min(active_categories.items(), key=lambda x: x[1]) if active_categories else ("", 0)
        collections["Estadisticas"].update_one(
            {"_id": "least_visited_category", "empresa": empresa},
            {"$set": {
                f"daily.{date_str}": {"category": least_cat[0], "count": least_cat[1]},
                f"weekly.{monday_of_week}": {"category": least_cat[0], "count": least_cat[1]},
                f"monthly.{month_str}": {"category": least_cat[0], "count": least_cat[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        hist_counts = historical["category_counts"]
        most_hist = max(hist_counts.items(), key=lambda x: x[1]) if hist_counts else ("", 0)
        active_hist = {k: v for k, v in hist_counts.items() if v > 0}
        least_hist = min(active_hist.items(), key=lambda x: x[1]) if active_hist else ("", 0)
        collections["Estadisticas"].update_one(
            {"_id": "historical_categories", "empresa": empresa},
            {"$set": {
                "most_visited": {"category": most_hist[0], "count": most_hist[1]},
                "least_visited": {"category": least_hist[0], "count": least_hist[1]},
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_visited_categories: {e}")

def update_emotion_percentage_by_category(category: str, emotion: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotion_percentage_by_category", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'emotion_percentage_by_category' no encontrado para empresa {empresa}")
            return
        raw_counts = stats.get("raw_counts", {})
        category_emotions = raw_counts.get(category, {})
        category_emotions[emotion] = category_emotions.get(emotion, 0) + 1
        raw_counts[category] = category_emotions
        data = {}
        for cat, emotions in raw_counts.items():
            total = sum(emotions.values())
            data[cat] = {emotion: round((count / total) * 100, 2) for emotion, count in emotions.items()}
        collections["Estadisticas"].update_one(
            {"_id": "emotion_percentage_by_category", "empresa": empresa},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotion_percentage_by_category: {e}")

def update_most_frequent_emotions(emotion: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "most_frequent_emotions", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'most_frequent_emotions' no encontrado para empresa {empresa}")
            return
        data = stats.get("data", {})
        data[emotion] = data.get(emotion, 0) + 1
        collections["Estadisticas"].update_one(
            {"_id": "most_frequent_emotions", "empresa": empresa},
            {"$set": {
                "data": data,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_most_frequent_emotions: {e}")

def update_age_distribution(age_group: str, monday_of_week: str, month_str: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "age_distribution", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'age_distribution' no encontrado para empresa {empresa}")
            return
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        overall = stats.get("overall", {})
        week_data = weekly.get(monday_of_week, {})
        week_data[age_group] = week_data.get(age_group, 0) + 1
        weekly[monday_of_week] = week_data
        month_data = monthly.get(month_str, {})
        month_data[age_group] = month_data.get(age_group, 0) + 1
        monthly[month_str] = month_data
        overall[age_group] = overall.get(age_group, 0) + 1
        collections["Estadisticas"].update_one(
            {"_id": "age_distribution", "empresa": empresa},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "overall": overall,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_age_distribution: {e}")

def update_gender_distribution(gender: str, monday_of_week: str, month_str: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "gender_distribution", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'gender_distribution' no encontrado para empresa {empresa}")
            return
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        overall = stats.get("overall", {})
        week_data = weekly.get(monday_of_week, {})
        week_data[gender] = week_data.get(gender, 0) + 1
        weekly[monday_of_week] = week_data
        month_data = monthly.get(month_str, {})
        month_data[gender] = month_data.get(gender, 0) + 1
        monthly[month_str] = month_data
        overall[gender] = overall.get(gender, 0) + 1
        collections["Estadisticas"].update_one(
            {"_id": "gender_distribution", "empresa": empresa},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "overall": overall,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_gender_distribution: {e}")

def update_emotion_comparison(emotion: str, day_of_week: str, monday_of_week: str, month_str: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotion_comparison", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'emotion_comparison' no encontrado para empresa {empresa}")
            return
        weekly = stats.get("weekly", {})
        monthly = stats.get("monthly", {})
        if emotion not in ["HAPPY", "SAD"]:
            return
        week_data = weekly.get(monday_of_week, {})
        week_data["day"] = day_of_week
        week_data[emotion] = week_data.get(emotion, 0) + 1
        weekly[monday_of_week] = week_data
        month_data = monthly.get(month_str, {})
        month_data[emotion] = month_data.get(emotion, 0) + 1
        monthly[month_str] = month_data
        collections["Estadisticas"].update_one(
            {"_id": "emotion_comparison", "empresa": empresa},
            {"$set": {
                "weekly": weekly,
                "monthly": monthly,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotion_comparison: {e}")

def update_preferred_category_by_gender(gender: str, category: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "preferred_category_by_gender", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'preferred_category_by_gender' no encontrado para empresa {empresa}")
            return
        raw_counts = stats.get("raw_counts", {})
        if gender not in raw_counts:
            raw_counts[gender] = {}
        gender_categories = raw_counts[gender]
        gender_categories[category] = gender_categories.get(category, 0) + 1
        data = stats.get("data", {})
        for g, categories in raw_counts.items():
            if categories:
                preferred = max(categories.items(), key=lambda x: x[1])
                data[g] = {"category": preferred[0], "count": preferred[1]}
        collections["Estadisticas"].update_one(
            {"_id": "preferred_category_by_gender", "empresa": empresa},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_preferred_category_by_gender: {e}")

def update_top_successful_categories(category: str, emotion: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "top_successful_categories", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'top_successful_categories' no encontrado para empresa {empresa}")
            return
        raw_counts = stats.get("raw_counts", {})
        if category not in raw_counts:
            raw_counts[category] = {"HAPPY": 0, "total": 0}
        category_counts = raw_counts[category]
        if emotion == "HAPPY":
            category_counts["HAPPY"] = category_counts.get("HAPPY", 0) + 1
        category_counts["total"] = category_counts.get("total", 0) + 1
        data = []
        for cat, counts in raw_counts.items():
            if counts["total"] > 0:
                happy_percentage = round((counts["HAPPY"] / counts["total"]) * 100, 2)
                data.append({"category": cat, "happy_percentage": happy_percentage})
        data.sort(key=lambda x: x["happy_percentage"], reverse=True)
        collections["Estadisticas"].update_one(
            {"_id": "top_successful_categories", "empresa": empresa},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_top_successful_categories: {e}")

def update_emotional_differences_by_category(category: str, gender: str, emotion: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "emotional_differences_by_category", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'emotional_differences_by_category' no encontrado para empresa {empresa}")
            collections["Estadisticas"].insert_one({
                "_id": "emotional_differences_by_category",
                "empresa": empresa,
                "description": "Emociones por género en cada categoría de productos",
                "data": {},
                "last_updated": datetime.utcnow().isoformat()
            })
            stats = collections["Estadisticas"].find_one({"_id": "emotional_differences_by_category", "empresa": empresa})
        gender_key = gender.lower()
        emotion_key = emotion.upper()
        data = stats.get("data", {})
        if category not in data:
            data[category] = {
                "male": {},
                "female": {}
            }
        if gender_key not in data[category]:
            data[category][gender_key] = {}
        if emotion_key not in data[category][gender_key]:
            data[category][gender_key][emotion_key] = 0
        data[category][gender_key][emotion_key] += 1
        collections["Estadisticas"].update_one(
            {"_id": "emotional_differences_by_category", "empresa": empresa},
            {"$set": {
                "data": data,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_emotional_differences_by_category: {e}")

def update_age_gender_distribution_by_category(category: str, gender: str, age_group: str, empresa: str):
    try:
        stats = collections["Estadisticas"].find_one({"_id": "age_gender_distribution_by_category", "empresa": empresa})
        if not stats:
            logger.warning(f"Documento 'age_gender_distribution_by_category' no encontrado para empresa {empresa}")
            return
        raw_counts = stats.get("raw_counts", {})
        if category not in raw_counts:
            raw_counts[category] = {"Male": {}, "Female": {}}
        if gender not in raw_counts[category]:
            raw_counts[category][gender] = {}
        gender_ages = raw_counts[category][gender]
        gender_ages[age_group] = gender_ages.get(age_group, 0) + 1
        data = {}
        for cat, genders in raw_counts.items():
            cat_combinations = []
            for g, ages in genders.items():
                for age, count in ages.items():
                    cat_combinations.append({"gender": g, "age_range": age, "count": count})
            cat_combinations.sort(key=lambda x: x["count"], reverse=True)
            data[cat] = cat_combinations
        collections["Estadisticas"].update_one(
            {"_id": "age_gender_distribution_by_category", "empresa": empresa},
            {"$set": {
                "data": data,
                "raw_counts": raw_counts,
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
    except Exception as e:
        logger.error(f"Error en update_age_gender_distribution_by_category: {e}") 