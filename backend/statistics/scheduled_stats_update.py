"""
Módulo para actualizar estadísticas de forma programada.
Este módulo se integra con FastAPI para ejecutar actualizaciones periódicas en segundo plano.
"""

import logging
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from backend.database import collections
from backend.statistics.incremental_stats import initialize_statistics

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Crear scheduler
scheduler = BackgroundScheduler()

def update_daily_stats():
    """
    Actualiza estadísticas diarias al final del día.
    Esta función es útil para recalcular estadísticas agregadas o realizar
    limpieza/mantenimiento en la colección Estadisticas.
    """
    try:
        logger.info("Ejecutando actualización programada de estadísticas diarias...")
        
        # Actualizar la fecha de última actualización en todas las estadísticas
        current_time = datetime.utcnow().isoformat()
        collections["Estadisticas"].update_many(
            {},  # Actualizar todos los documentos
            {"$set": {"last_updated": current_time}}
        )
        
        # Aquí puedes añadir cualquier lógica adicional para actualización programada
        # Por ejemplo, calcular agregaciones o limpiar datos antiguos
        
        logger.info("Actualización programada de estadísticas diarias completada.")
    except Exception as e:
        logger.error(f"Error en update_daily_stats: {e}")

def update_weekly_stats():
    """
    Actualiza estadísticas semanales cada domingo a medianoche.
    Útil para calcular tendencias semanales o limpiar datos antiguos.
    """
    try:
        logger.info("Ejecutando actualización programada de estadísticas semanales...")
        
        # Implementar lógica de actualización semanal aquí
        
        logger.info("Actualización programada de estadísticas semanales completada.")
    except Exception as e:
        logger.error(f"Error en update_weekly_stats: {e}")

def update_monthly_stats():
    """
    Actualiza estadísticas mensuales el primer día de cada mes.
    """
    try:
        logger.info("Ejecutando actualización programada de estadísticas mensuales...")
        
        # Implementar lógica de actualización mensual aquí
        
        logger.info("Actualización programada de estadísticas mensuales completada.")
    except Exception as e:
        logger.error(f"Error en update_monthly_stats: {e}")

def refresh_all_stats():
    """
    Comprueba la integridad y reinicializa estadísticas si es necesario.
    """
    try:
        logger.info("Comprobando integridad de las estadísticas...")
        
        # Verificar que todos los documentos de estadísticas existen
        initialize_statistics()
        
        # Aquí podrías añadir lógica para detectar y corregir inconsistencias en los datos
        
        logger.info("Comprobación de integridad de estadísticas completada.")
    except Exception as e:
        logger.error(f"Error en refresh_all_stats: {e}")

def start_scheduler():
    """Inicia el programador de tareas."""
    # Actualización diaria a medianoche
    scheduler.add_job(
        update_daily_stats,
        CronTrigger(hour=0, minute=0),
        id="daily_stats_update",
        replace_existing=True
    )
    
    # Actualización semanal los domingos a la 01:00
    scheduler.add_job(
        update_weekly_stats,
        CronTrigger(day_of_week="sun", hour=1, minute=0),
        id="weekly_stats_update",
        replace_existing=True
    )
    
    # Actualización mensual el primer día de cada mes a las 02:00
    scheduler.add_job(
        update_monthly_stats,
        CronTrigger(day=1, hour=2, minute=0),
        id="monthly_stats_update",
        replace_existing=True
    )
    
    # Comprobación de integridad cada día a las 03:00
    scheduler.add_job(
        refresh_all_stats,
        CronTrigger(hour=3, minute=0),
        id="stats_integrity_check",
        replace_existing=True
    )
    
    # Iniciar el scheduler
    if not scheduler.running:
        scheduler.start()
        logger.info("Programador de actualizaciones de estadísticas iniciado.")

def shutdown_scheduler():
    """Detiene el programador de tareas."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("Programador de actualizaciones de estadísticas detenido.") 