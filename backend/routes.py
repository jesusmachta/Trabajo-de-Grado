from backend.statistics.apis.regenerate_stats_api import router as regenerate_stats_router
from backend.statistics.incremental_stats import initialize_statistics, update_statistics_on_insert
from backend.statistics.scheduled_stats_update import start_scheduler, shutdown_scheduler
from backend.auth.dependencies import get_empresa, get_current_user
from backend.auth.create_user import create_user, get_next_sequence_value, UserCreate, validate_password
from backend.auth.login_user import login_user, verify_password, UserLogin, Token
from backend.auth.jwt_settings import create_access_token, SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES
from backend.heatmap.apis.heatmap_api import router as heatmap_router
from backend.auth.read_user import get_user_by_id, get_all_users, verify_security_info, get_current_user_profile
from backend.auth.update_user import (
    update_user_profile, reset_password, update_profile_picture,
    upload_profile_picture_base64, upload_profile_picture_file, upload_profile_picture_web,
    UserUpdate, ProfileUpdatePayload, ProfilePicturePayload, WebProfilePicturePayload,
    PasswordResetRequest, PasswordResetConfirm
)
from backend.auth.delete_user import delete_user
from backend.auth.create_company import create_company, CompanyRegistration
from backend.auth.delete_company import delete_company
from backend.auth.password_recovery import router as password_recovery_router
from backend.auth.company_migration import router as company_migration_router
from backend.chat.chat_service import chat_router  # Import chat_router from new module
# Import sensor settings CRUD modules
from backend.sensorSettings.create_sensorsetting import create_sensor_setting
from backend.sensorSettings.read_sensorsetting import get_sensor_setting_by_empresa
from backend.sensorSettings.update_sensorsetting import update_sensor_setting
import re
from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, Path, Body, File, UploadFile, Form
from pydantic import BaseModel, EmailStr, Field # Added Field
from backend.aws import analyze_image, upload_image_to_s3
from datetime import datetime, timedelta
from backend.database import collections
import pymongo
import os
import io
import logging
import json # Added json import
import requests # Added requests import
import numpy as np
from PIL import Image
import base64
import cv2
from typing import List, Optional, Dict, Any # Added Dict, Any
from bson import ObjectId, json_util # Added ObjectId import and json_util
from pytz import timezone
from backend.statistics.peak_hours import get_peak_hours
from backend.statistics.least_busy_hours import get_least_busy_hours
from backend.statistics.most_busy_day import get_most_busy_day
from backend.statistics.least_busy_day import get_least_busy_day
from backend.statistics.least_visited_category import get_least_visited_category
from backend.statistics.most_visited_category import get_most_visited_category
from backend.statistics.emotion_percentage_by_category import get_emotion_percentage_by_category
from backend.statistics.most_frequent_emotions import get_most_frequent_emotions
from backend.statistics.age_distribution import get_age_distribution
from backend.statistics.gender_distribution import get_gender_distribution
from backend.statistics.most_visited_category_historical import get_most_visited_category_historical
from backend.statistics.least_visited_category_historical import get_least_visited_category_historical
from backend.statistics.emotion_comparison import get_emotion_comparison
from backend.statistics.preferred_category_by_gender import get_preferred_category_by_gender
from backend.statistics.top_successful_categories import get_top_successful_categories as calculate_top_categories_by_visits
from backend.statistics.emotional_differences_by_category import get_emotional_differences_by_category
from backend.statistics.age_gender_distribution_by_category import get_age_gender_distribution_by_category
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
import bcrypt
import jwt
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
# Import camera CRUD modules
from backend.cameras.create_camera import create_camera
from backend.cameras.read_camera import get_cameras_with_details, get_camera_by_id
from backend.cameras.update_camera import update_camera
from backend.cameras.delete_camera import delete_camera
from backend.analysis import handle_image_upload
from backend.categories.category_model import CategoryModel
from backend.categories.schemas import CategoryCreate, CategoryUpdate, CategoryResponse
# Import sensor CRUD modules
from backend.sensor.create_sensor import create_sensor
from backend.sensor.read_sensor import get_sensors_with_details, get_sensor_by_id, get_available_categories
from backend.sensor.update_sensor import update_sensor
from backend.sensor.delete_sensor import delete_sensor



router = APIRouter()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ruta al directorio de archivos estáticos de Flutter web
# Adjusted path to work from within routes.py
FLUTTER_WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend", "build", "web")
# Debug: verificar la existencia del directorio
print(f"FLUTTER_WEB_DIR: {FLUTTER_WEB_DIR}")
print(f"Directory exists: {os.path.exists(FLUTTER_WEB_DIR)}")

# JWT settings
SECRET_KEY = "d5ce1e8ca2d3c30ba1c6bfd87fb14943f7e75dbea2d33ca4cf54de94cb906add"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/login")

class ImagePayload(BaseModel):
    image_base64: str
    id_camara: int
    empresa: str  # Added empresa field

# router.include_router(categories_router, prefix="/api", tags=["Categories"])

def get_next_sequence_value(sequence_name):
    try:
        sequence_document = collections['counters'].find_one_and_update(
            {"_id": sequence_name},
            {"$inc": {"seq": 1}},
            return_document=pymongo.ReturnDocument.AFTER
        )
        if sequence_document is None:
            raise Exception("Sequence document not found")
        return sequence_document["seq"]
    except Exception as e:
        logger.error(f"Error al obtener el siguiente valor de secuencia: {e}")
        raise HTTPException(status_code=500, detail=f"Error al obtener el siguiente valor de secuencia: {e}")

def initialize_routes(app):
    # Inicializar documentos de estadísticas (ya no se hace aquí, solo al registrar empresa)
    # initialize_statistics()  # ELIMINADO: ahora requiere argumento 'empresa'
    
    # Iniciar el programador de actualizaciones
    start_scheduler()
    
    # Incluir rutas API
    app.include_router(router, prefix="/api")
    app.include_router(regenerate_stats_router, prefix="/api", tags=["Statistics"])
    app.include_router(password_recovery_router, prefix="/api", tags=["Auth"])
    app.include_router(company_migration_router, prefix="/api", tags=["Auth"])
    app.include_router(chat_router, prefix="/api", tags=["Chat"]) # Import chat_router from the new module
    app.include_router(heatmap_router, prefix="/api", tags=["HeatMap"])
    
    # Configurar evento de apagado para detener el programador
    @app.on_event("shutdown")
    def shutdown_event():
        shutdown_scheduler()
    
    # Verificar si el directorio de Flutter web existe
    flutter_web_exists = os.path.exists(FLUTTER_WEB_DIR) and os.path.isdir(FLUTTER_WEB_DIR)
    
    # Montar los archivos estáticos solo si existen
    if flutter_web_exists:
        try:
            if os.path.exists(os.path.join(FLUTTER_WEB_DIR, "assets")):
                app.mount("/assets", StaticFiles(directory=os.path.join(FLUTTER_WEB_DIR, "assets")), name="assets")
            
            # Montar todos los archivos estáticos de Flutter
            app.mount("/", StaticFiles(directory=FLUTTER_WEB_DIR, html=True), name="flutter_web")
            
            # No es necesario definir rutas adicionales si los estáticos están montados
        except RuntimeError as e:
            print(f"Error mounting static files: {e}")
            flutter_web_exists = False
    
    # Si no hay archivos estáticos de Flutter, definir las rutas para mostrar la página de API
    if not flutter_web_exists:
        # Ruta principal y dashboard muestran la misma página informativa
        @app.get("/", response_class=HTMLResponse)
        @app.get("/dashboard", response_class=HTMLResponse)
        async def api_info():
            return HTMLResponse(content="""
            <!DOCTYPE html>
            <html>
            <head>
                <title>StoreSense API</title>
                <style>
                    body { font-family: Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
                    h1 { color: #0277BD; text-align: center; }
                    .header { text-align: center; margin-bottom: 30px; }
                    .endpoint { background: #f4f4f4; padding: 15px; margin-bottom: 15px; border-radius: 8px; }
                    code { background: #e0e0e0; padding: 2px 6px; border-radius: 4px; }
                    .api-container { margin-top: 40px; }
                    .status { color: #4CAF50; font-weight: bold; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>StoreSense API Server</h1>
                    <p class="status">✅ API ACTIVA Y FUNCIONANDO</p>
                    <p>La interfaz web de Flutter no está disponible en este entorno. Sin embargo, todos los endpoints de la API están operativos.</p>
                </div>
                
                <div class="api-container">
                    <h2>Endpoints disponibles:</h2>
                    <div class="endpoint">
                        <h3>Documentación de la API</h3>
                        <p>Accede a la documentación completa de la API:</p>
                        <p><a href="/docs"><code>GET /docs</code></a> - Documentación con Swagger UI</p>
                        <p><a href="/redoc"><code>GET /redoc</code></a> - Documentación con ReDoc</p>
                    </div>
                    
                    <div class="endpoint">
                        <h3>Probar conexión</h3>
                        <p><a href="/api/hello"><code>GET /api/hello</code></a></p>
                    </div>
                    
                    <div class="endpoint">
                        <h3>Estadísticas</h3>
                        <p><code>GET /api/statistics/*</code></p>
                        <p>Accede a todos los endpoints de estadísticas disponibles.</p>
                    </div>
                     <div class="endpoint">
                        <h3>Cámaras</h3>
                        <p><code>GET /api/cameras</code></p>
                        <p><code>POST /api/cameras</code></p>
                        <p><code>PUT /api/cameras/{camera_id_mongo}</code></p>
                        <p><code>DELETE /api/cameras/{camera_id_mongo}</code></p>
                    </div>
                </div>
            </body>
            </html>
            """)
    
    # Las otras rutas dinámicas se agregan después de las rutas estáticas

@router.get("/hello")
def hello_world():
    return {"message": "Hola Mundo s3!!"}

@router.get("/statistics/peak-hours/")
def daily_traffic(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las horas pico de los clientes por día de la semana, filtrado por empresa.
    """
    try:
        # Call model function to get data
        data = get_peak_hours(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching peak hours for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching peak hours.")

@router.get("/statistics/least-hours/")
def daily_traffic_least(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las horas menos concurridas por día de la semana.
    """
    try:
        # Call model function to get data
        data = get_least_busy_hours(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching least busy hours for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching least busy hours.")

@router.get("/statistics/busy-days/")
def daily_traffic_busy_days(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el día más concurrido de la semana.
    """
    try:
        # Call model function to get data
        data = get_most_busy_day(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching most busy days for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching most busy days.")

@router.get("/statistics/least-days/")
def daily_traffic_least_days(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el día menos concurrido de la semana.
    """
    try:
        # Call model function to get data
        data = get_least_busy_day(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching least busy days for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching least busy days.")

@router.get("/statistics/least-visited/")
def least_visited_category(period: str, date: Optional[str] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto menos visitada en un rango de tiempo (día, semana o mes).
    """
    try:
        # Call model function to get data
        data = get_least_visited_category(empresa, period, date)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/least-visited-historical/")
def least_visited_category_historical_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto menos visitada utilizando todos los datos históricos.
    """
    try:
        # Call model function to get data
        data = get_least_visited_category_historical(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching historical categories for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching historical_categories.")

@router.get("/statistics/most-visited/")
def most_visited_category_endpoint(period: str, date: Optional[str] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto más visitada en un rango de tiempo (día, semana o mes).
    """
    try:
        # Call model function to get data
        data = get_most_visited_category(empresa, period, date)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/most-visited-historical/")
def most_visited_category_historical_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto más visitada utilizando todos los datos históricos.
    """
    try:
        # Call model function to get data
        data = get_most_visited_category_historical(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching historical categories for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching historical_categories.")

@router.get("/statistics/visited-categories-historical/")
def visited_categories_historical(empresa: str= Depends(get_empresa)):
    """
    Endpoint para obtener las categorías de producto más y menos visitadas utilizando todos los datos históricos.
    """
    try:
        # Call model functions to get data
        most_visited = get_most_visited_category_historical(empresa)
        least_visited = get_least_visited_category_historical(empresa)
        
        # Combinamos los datos en una sola respuesta
        combined_data = {
            "most_visited_category": most_visited.get("most_visited_category", ""),
            "most_visited_count": most_visited.get("count", 0),
            "least_visited_category": least_visited.get("least_visited_category", ""),
            "least_visited_count": least_visited.get("count", 0)
        }
        
        return {"message": "Success", "data": combined_data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching historical categories for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching historical_categories.")

@router.get("/statistics/emotion-percentage/")
def emotion_percentage_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el porcentaje de emociones por categoría.
    """
    try:
        # Call model function to get data
        data = get_emotion_percentage_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching emotion percentage for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching emotion percentage.")

@router.get("/statistics/most-frequent-emotions/")
def most_frequent_emotions_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las emociones más frecuentes.
    """
    try:
        # Call model function to get data
        data = get_most_frequent_emotions(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching emotion percentage for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching emotion percentage.")

@router.get("/statistics/age-distribution/")
def age_distribution_endpoint(period: str = None, date: Optional[str] = None, end_date: Optional[str] = None, 
                     month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la distribución de visitantes por edad.
    """
    try:
        # Call model function to get data
        data = get_age_distribution(empresa, period, date, month, year)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/gender-distribution/")
def gender_distribution_endpoint(period: str = None, date: Optional[str] = None, end_date: Optional[str] = None, 
                        month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la distribución de visitantes por género.
    """
    try:
        # Call model function to get data
        data = get_gender_distribution(empresa, period, date, month, year)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/emotion-comparison/")
def emotion_comparison_endpoint(period: str = "week", date: Optional[str] = None, end_date: Optional[str] = None, 
                      month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para comparar emociones positivas (HAPPY) y negativas (SAD) por día de la semana.
    """
    try:
        # Call model function to get data
        data = get_emotion_comparison(empresa, period, date, month, year)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc   
    except Exception as e:
        print(f"Exception in emotion_comparison endpoint: {e}")
        import traceback
        traceback.print_exc()
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/preferred-category-by-gender/")
def preferred_category_by_gender_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las categorías de productos preferidas por género (hombres y mujeres).
    """
    try:
        # Call model function to get data
        data = get_preferred_category_by_gender(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error en preferred_category_by_gender: {e}")
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/top-successful-categories/")
def top_successful_categories_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el top 3 de categorías más exitosas según emociones positivas (HAPPY count).
    """
    try:
        # Call model function to get data
        data = calculate_top_categories_by_visits(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        logger.error(f"HTTPException en top_successful_categories: {http_exc.detail}")
        raise http_exc
    except Exception as e:
        logger.error(f"Error calculando top successful categories: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to calculate top categories: {str(e)}")

@router.get("/statistics/emotional-differences-by-category/")
def emotional_differences_by_category_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las emociones por género en cada categoría de productos.
    """
    try:
        # Call model function to get data
        data = get_emotional_differences_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/age-gender-distribution-by-category/")
def age_gender_distribution_by_category_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las combinaciones de género y rango de edad más frecuentes por categoría de producto.
    """
    try:
        # Call model function to get data
        data = get_age_gender_distribution_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.post("/upload-image/")
async def upload_image_endpoint(background_tasks: BackgroundTasks, payload: ImagePayload):
    """
    Endpoint to receive camera images, process them, and analyze them.
    The images are enhanced, uploaded to S3, and analyzed with AWS Rekognition.
    Analysis results are saved to the database for statistics.
    """
    try:
        # Call the controller function that orchestrates the entire process
        return await handle_image_upload(
            background_tasks=background_tasks,
            image_base64=payload.image_base64,
            id_camara=payload.id_camara,
            empresa=payload.empresa
        )
    except Exception as e:
        logger.error(f"Error in upload_image_endpoint: {e}")
        # If an HTTPException was raised by the controller, it will propagate up
        # For other exceptions, wrap them in a 500 error
        if not isinstance(e, HTTPException):
            raise HTTPException(status_code=500, detail=str(e))
        raise

@router.post("/signup", response_model=Token)
async def signup(user_data: UserCreate, empresa: str = Depends(get_empresa)):
    """Endpoint for user registration."""
    # Use the create_user function from the auth module
    user = create_user(
        email=user_data.email,
        password=user_data.password,
        full_name=user_data.full_name,
        role=user_data.role,
        empresa=empresa,
        date_of_birth=user_data.date_of_birth,
        security_question=user_data.security_question,
        security_answer=user_data.security_answer,
        rif=user_data.rif
    )
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["user_id"], "empresa": empresa}, 
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user["user_id"],
        "email": user["email"],
        "full_name": user["full_name"],
        "role": user["role"],
        "empresa": empresa,
        "profile_picture": None  # New users don't have a profile picture
    }

@router.post("/login", response_model=Token)
async def login_endpoint(user_data: UserLogin):
    """Endpoint for user login."""
    # Use the login_user function from the model
    login_result = login_user(
        email=user_data.email,
        password=user_data.password
    )
    
    return login_result

# User management endpoints
@router.get("/users", response_model=dict)
async def get_users(current_user: dict = Depends(get_current_user)):
    """
    Endpoint to get all users. Admin only, filtered by company.
    """
    # Verificar si el usuario tiene el rol de administrador
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Access forbidden: Admin only")

    # Obtener la empresa del usuario autenticado
    empresa = current_user.get("empresa")
    if not empresa:
        raise HTTPException(status_code=400, detail="User does not belong to any company")

    try:
        # Use the get_all_users function from the auth module
        users = get_all_users(empresa)
        return {"message": "Success", "data": users}
    except HTTPException as http_exc:
        # Re-lanzar excepciones HTTP específicas
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching users for company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching users.")

@router.get("/users/me", response_model=dict)
async def get_current_user_profile_endpoint(current_user: dict = Depends(get_current_user)):
    """Get the current user's profile."""
    # Use the get_current_user_profile function from the auth module
    user_profile = get_current_user_profile(current_user)
    return {"message": "Success", "data": user_profile}

# --- Profile Management Routes ---
@router.put("/users/profile", response_model=dict)
async def update_profile_endpoint(payload: ProfileUpdatePayload, current_user: dict = Depends(get_current_user)):
    """Update the current user's profile information."""
    user_id = str(current_user.get("_id"))
    
    # Prepare update data
    update_data = {}
    if payload.email is not None:
        update_data["email"] = payload.email
    
    # Build full name from first and last name
    if payload.first_name is not None or payload.last_name is not None:
        current_full_name = current_user.get("full_name", "")
        name_parts = current_full_name.split(" ", 1)
        
        current_first = name_parts[0] if len(name_parts) > 0 else ""
        current_last = name_parts[1] if len(name_parts) > 1 else ""
        
        new_first = payload.first_name if payload.first_name is not None else current_first
        new_last = payload.last_name if payload.last_name is not None else current_last
        
        update_data["full_name"] = f"{new_first} {new_last}".strip()
    
    if payload.password is not None:
        update_data["password"] = payload.password
    
    # Use the update_user_profile function from the model
    updated_user = update_user_profile(user_id, update_data)
    
    return {
        "message": "Profile updated successfully",
        "data": updated_user
    }

@router.put("/users/{user_id}", response_model=dict)
async def update_user_endpoint(
    user_id: str,
    user_data: UserUpdate,
    current_user: dict = Depends(get_current_user),
    empresa: str = Depends(get_empresa)
):
    """
    Endpoint to update a user. Admin or self only, filtered by company.
    """
    # Verificar si el usuario es administrador o está actualizando su propio perfil
    if current_user.get("role") != "admin" and str(current_user.get("_id")) != user_id:
        raise HTTPException(status_code=403, detail="Access forbidden: Admin or self only")

    try:
        # Buscar el usuario a actualizar y verificar que pertenezca a la misma empresa
        user = collections['Users'].find_one({"_id": int(user_id), "empresa": empresa})
        if user is None:
            raise HTTPException(status_code=404, detail="User not found or does not belong to your company")

        # Preparar los datos para la actualización
        update_data = {}
        if user_data.email is not None:
            update_data["email"] = user_data.email

        if user_data.full_name is not None:
            update_data["full_name"] = user_data.full_name

        # Solo los administradores pueden cambiar roles
        if user_data.role is not None:
            if current_user.get("role") != "admin":
                raise HTTPException(status_code=403, detail="Only admin can change roles")
            update_data["role"] = user_data.role

        # Incluir el campo password si se proporciona
        if user_data.password is not None:
            update_data["password"] = user_data.password

        # Incluir el campo profile_picture si se proporciona
        if user_data.profile_picture is not None:
            update_data["profile_picture"] = user_data.profile_picture

        # Incluir el campo is_active si se proporciona
        if user_data.is_active is not None:
            update_data["is_active"] = user_data.is_active

        # Use the update_user_profile function from the model
        updated_user = update_user_profile(user_id, update_data)

        return {"message": "User updated successfully", "data": updated_user}

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error updating user: {str(e)}")
        raise HTTPException(status_code=500, detail="Error updating user.")

@router.delete("/users/{user_id}", response_model=dict)
async def delete_user_endpoint(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    empresa: str = Depends(get_empresa)
):
    """
    Endpoint to delete a user. Admin only, filtered by company.
    """
    # Verificar si el usuario tiene el rol de administrador
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Access forbidden: Admin only")
    
    try:
        # Prevenir que un usuario elimine su propia cuenta
        if str(current_user.get("_id")) == user_id:
            raise HTTPException(status_code=400, detail="Cannot delete your own account")
        
        # Use the delete_user function from the model
        result = delete_user(user_id, empresa)
        
        return {"message": "User deleted successfully"}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error deleting user: {str(e)}")
        raise HTTPException(status_code=500, detail="Error deleting user.")

# --- Profile Picture Management ---
@router.post("/users/profile/picture", response_model=dict)
async def upload_profile_picture_endpoint(payload: ProfilePicturePayload, current_user: dict = Depends(get_current_user)):
    """Upload a profile picture for the current user."""
    user_id = str(current_user.get("_id"))
    
    # Use the upload_profile_picture_base64 function from the model
    result = upload_profile_picture_base64(user_id, payload.image_base64)
    
    return result

@router.post("/users/profile/picture/upload", response_model=dict)
async def upload_profile_picture_file_endpoint(
    file: UploadFile = File(...), 
    current_user: dict = Depends(get_current_user)
):
    """Upload a profile picture file for the current user."""
    try:
        # Check if the file is an image
        content_type = file.content_type
        if not content_type or not content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Read the file
        image_bytes = await file.read()
        user_id = str(current_user.get("_id"))
        
        # Use the upload_profile_picture_file function from the model
        result = upload_profile_picture_file(user_id, image_bytes, content_type)
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading profile picture: {str(e)}")

@router.post("/users/profile/picture/upload/web", response_model=dict)
async def upload_profile_picture_web_endpoint(
    payload: WebProfilePicturePayload,
    current_user: dict = Depends(get_current_user)
):
    """Upload a profile picture from web using base64."""
    user_id = str(current_user.get("_id"))
    
    # Check if a specific user_id was provided and if current user is admin
    if hasattr(payload, 'user_id') and payload.user_id and current_user.get("role") == "admin":
        # Admin is updating someone else's profile picture
        user_id = payload.user_id
    
    # Use the upload_profile_picture_web function from the model
    result = upload_profile_picture_web(user_id, payload.image_base64, payload.file_name)
    
    return result

# --- Camera Routes ---

# Helper function to serialize MongoDB ObjectId (already defined above, but good practice)
def serialize_doc(doc):
    if doc and '_id' in doc:
        doc['_id'] = str(doc['_id'])
    return doc

@router.get("/cameras", response_model=List[Dict[str, Any]], tags=["Cameras"])
async def get_cameras_endpoint(empresa: str = Depends(get_empresa)):
    """
    Retrieves all cameras from Tipo_Producto_Zona_Camara and joins them
    with their corresponding product category from Tipo_Producto, filtered by empresa.
    """
    try:
        # Call the model function to get cameras
        cameras_list = get_cameras_with_details(empresa)
        return cameras_list
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching cameras: {str(e)}")


@router.post("/cameras", response_model=Dict[str, Any], status_code=201, tags=["Cameras"])
async def create_camera_endpoint(
    camera_data: Dict[str, Any] = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Creates a new camera entry in Tipo_Producto_Zona_Camara.
    Expects a body like: {"Id_Camara": <int>, "Tipo_Producto": <int>, "isActive": <bool>}
    """
    try:
        # Call the model function to create camera
        created_camera = create_camera(camera_data, empresa)
        return created_camera
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating camera: {str(e)}")

@router.put("/cameras/{camera_id_mongo}", response_model=Dict[str, Any], tags=["Cameras"])
async def update_camera_endpoint(
    camera_id_mongo: str = Path(..., title="The MongoDB ObjectId of the camera to update"),
    update_data: Dict[str, Any] = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Updates an existing camera's status or associated fields.
    Expects a body like: {"isActive": <bool>, "Id_Camara": <int>, "Tipo_Producto": <int>}
    """
    try:
        # Call the model function to update camera
        updated_camera = update_camera(camera_id_mongo, update_data, empresa)
        return updated_camera
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating camera: {str(e)}")


@router.delete("/cameras/{camera_id_mongo}", status_code=204, tags=["Cameras"])
async def delete_camera_endpoint(
    camera_id_mongo: str = Path(..., title="The MongoDB ObjectId of the camera to delete"),
    empresa: str = Depends(get_empresa)
):
    """
    Deletes a camera entry by its MongoDB ObjectId, ensuring it belongs to the authenticated user's company.
    """
    try:
        # Call the model function to delete camera
        delete_camera(camera_id_mongo, empresa)
        # Return 204 No Content on successful deletion
        return None
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting camera: {str(e)}")

@router.post("/register-company", status_code=201)
async def register_company_endpoint(
    background_tasks: BackgroundTasks,
    company_data: dict = Body(...)
):
    """
    Endpoint to register a new company and its admin user.
    """
    try:
        # Validate required fields
        required_fields = [
            "nombre_empresa", "rif", "nombre_responsable", 
            "apellido_responsable", "email", "password",
            "date_of_birth", "security_question", "security_answer"
        ]
        
        for field in required_fields:
            if field not in company_data or not company_data[field]:
                raise HTTPException(
                    status_code=400, 
                    detail=f"El campo '{field}' es requerido"
                )
        
        # Use the create_company function from the model
        company_result = create_company(
            nombre_empresa=company_data["nombre_empresa"],
            rif=company_data["rif"],
            nombre_responsable=company_data["nombre_responsable"],
            apellido_responsable=company_data["apellido_responsable"],
            email=company_data["email"],
            password=company_data["password"],
            date_of_birth=company_data["date_of_birth"],
            security_question=company_data["security_question"],
            security_answer=company_data["security_answer"]
        )
        
        # Create default sensor settings for the new company
        try:
            # Initialize with default values
            create_sensor_setting(
                empresa=company_result["empresa"],
                tipo_producto_principal=15,  # Default high threshold
                tipo_producto_medium=10,     # Default medium threshold
                tipo_producto_far=5          # Default low threshold
            )
            logger.info(f"Created default sensor settings for company {company_result['empresa']}")
        except Exception as e:
            logger.error(f"Error creating default sensor settings: {str(e)}")
            # Do not stop the registration process if this fails
        
        # Create access token for the new admin user
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": company_result["admin_user"]["user_id"], "empresa": company_result["empresa"]},
            expires_delta=access_token_expires
        )
        
        return {
            "message": "Empresa registrada exitosamente",
            "access_token": access_token,
            "token_type": "bearer",
            "user_id": company_result["admin_user"]["user_id"],
            "email": company_result["admin_user"]["email"],
            "full_name": company_result["admin_user"]["full_name"],
            "role": "admin",
            "is_active": True,
            "empresa": company_result["empresa"]
        }
    
    except HTTPException as he:
        # Re-raise HTTP exceptions
        raise he
    except Exception as e:
        logger.error(f"Error al registrar empresa: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error interno al registrar la empresa: {str(e)}"
        )

@router.delete("/delete-company")
async def delete_company_endpoint(current_user: dict = Depends(get_current_user)):
    """
    Endpoint to delete the current user's company and all related data.
    Only company administrators can perform this action.
    """
    # Use the delete_company function from the model
    result = delete_company(
        empresa=current_user.get("empresa"),
        admin_user_id=str(current_user.get("_id"))
    )
    
    return result

def initialize_statistics_for_company(empresa: str):
    """
    Inicializa los documentos de estadísticas para una nueva empresa.
    Esta función puede ser llamada como una tarea en segundo plano.
    """
    # Esta función ya no es necesaria, la inicialización se hace directamente con initialize_statistics
    pass

# Category endpoints
@router.get("/categories", tags=["Categories"], response_model=dict)
def get_categories_endpoint(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener todas las categorías tal como están en la base de datos (sincrónico).
    """
    category_model = CategoryModel()
    categories = category_model.get_all_categories(empresa)
    return {"message": "Success", "data": categories}

@router.post("/categories/create", tags=["Categories"], response_model=dict)
async def create_category_endpoint(request: CategoryCreate, empresa: str = Depends(get_empresa)):
    """
    Endpoint para crear una nueva categoría.
    """
    category_model = CategoryModel()
    category_id = category_model.create_category(
        tipo_producto=request.Tipo_Producto,
        categoria_producto=request.Categoria_Producto,
        is_active=request.isActive,
        icon=request.icon,
        empresa=empresa
    )
    return {"message": "Categoría creada exitosamente", "id": category_id}

@router.put("/categories/{category_id}", tags=["Categories"], response_model=dict)
def update_category_endpoint(category_id: str, request: CategoryUpdate, empresa: str = Depends(get_empresa)):
    """
    Endpoint para actualizar una categoría por su ID, asociada a la empresa del usuario autenticado.
    """
    category_model = CategoryModel()
    category_model.update_category(
        category_id=category_id,
        categoria_producto=request.Categoria_Producto,
        is_active=request.isActive,
        icon=request.icon,
        empresa=empresa
    )
    return {"message": "Categoría actualizada exitosamente"}

@router.delete("/categories/{category_id}", tags=["Categories"], response_model=dict)
async def delete_category_endpoint(category_id: str, empresa: str = Depends(get_empresa)):
    """
    Endpoint para eliminar una categoría por su ID, asociada a la empresa del usuario autenticado.
    """
    category_model = CategoryModel()
    category_model.delete_category(category_id=category_id, empresa=empresa)
    return {"message": "Categoría eliminada exitosamente"}

@router.get("/sensors", tags=["Sensors"], response_model=List[Dict[str, Any]])
async def get_sensors_endpoint(empresa: str = Depends(get_empresa)):
    """
    Retrieve all sensors for the authenticated company.
    """
    try:
        sensors = get_sensors_with_details(empresa)
        return sensors
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching sensors: {str(e)}")

@router.get("/sensors/available-categories", tags=["Sensors"], response_model=Dict[str, List[Dict[str, Any]]])
async def get_available_categories_endpoint(
    sensor_id: Optional[str] = None,
    empresa: str = Depends(get_empresa)
):
    """
    Get all categories available for assignment to sensors
    (categories not already assigned to other sensors).
    """
    try:
        available_categories = get_available_categories(empresa, sensor_id)
        return available_categories
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching available categories: {str(e)}")

@router.get("/sensors/{sensor_id}", tags=["Sensors"], response_model=Dict[str, Any])
async def get_sensor_by_id_endpoint(
    sensor_id: str = Path(..., title="The MongoDB ObjectId of the sensor to retrieve"),
    empresa: str = Depends(get_empresa)
):
    """
    Retrieve a specific sensor by its ID.
    """
    try:
        sensor = get_sensor_by_id(sensor_id, empresa)
        return sensor
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching sensor: {str(e)}")

@router.post("/sensors", tags=["Sensors"], response_model=Dict[str, Any], status_code=201)
async def create_sensor_endpoint(
    sensor_data: Dict[str, Any] = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Create a new sensor.
    """
    try:
        created_sensor = create_sensor(sensor_data, empresa)
        return created_sensor
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating sensor: {str(e)}")

@router.put("/sensors/{sensor_id}", tags=["Sensors"], response_model=Dict[str, Any])
async def update_sensor_endpoint(
    sensor_id: str = Path(..., title="The MongoDB ObjectId of the sensor to update"),
    update_data: Dict[str, Any] = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Update an existing sensor.
    """
    try:
        updated_sensor = update_sensor(sensor_id, update_data, empresa)
        return updated_sensor
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating sensor: {str(e)}")

@router.delete("/sensors/{sensor_id}", tags=["Sensors"], status_code=204)
async def delete_sensor_endpoint(
    sensor_id: str = Path(..., title="The MongoDB ObjectId of the sensor to delete"),
    empresa: str = Depends(get_empresa)
):
    """
    Delete a sensor.
    """
    try:
        delete_sensor(sensor_id, empresa)
        return None
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting sensor: {str(e)}")

# Add sensor settings endpoints
@router.get("/sensor-settings", tags=["SensorSettings"], response_model=dict)
async def get_sensor_settings_endpoint(empresa: str = Depends(get_empresa)):
    """
    Get sensor settings for the current company.
    """
    try:
        sensor_settings = get_sensor_setting_by_empresa(empresa)
        return {"message": "Success", "data": sensor_settings}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/sensor-settings", tags=["SensorSettings"], response_model=dict, status_code=201)
async def create_sensor_settings_endpoint(
    sensor_data: dict = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Create sensor settings for the current company.
    """
    try:
        # Extract threshold values from request body
        tipo_producto_principal = sensor_data.get("tipo_producto_principal", 15)
        tipo_producto_medium = sensor_data.get("tipo_producto_medium", 10)
        tipo_producto_far = sensor_data.get("tipo_producto_far", 5)
        
        # Create sensor settings
        doc_id = create_sensor_setting(
            empresa=empresa,
            tipo_producto_principal=tipo_producto_principal,
            tipo_producto_medium=tipo_producto_medium,
            tipo_producto_far=tipo_producto_far
        )
        
        return {
            "message": "Sensor settings created successfully",
            "id": doc_id
        }
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/sensor-settings", tags=["SensorSettings"], response_model=dict)
async def update_sensor_settings_endpoint(
    sensor_data: dict = Body(...),
    empresa: str = Depends(get_empresa)
):
    """
    Update sensor settings for the current company.
    """
    try:
        # Extract threshold values from request body
        tipo_producto_principal = sensor_data.get("tipo_producto_principal", 15)
        tipo_producto_medium = sensor_data.get("tipo_producto_medium", 10)
        tipo_producto_far = sensor_data.get("tipo_producto_far", 5)
        
        # Update sensor settings
        updated_doc = update_sensor_setting(
            empresa=empresa,
            tipo_producto_principal=tipo_producto_principal,
            tipo_producto_medium=tipo_producto_medium,
            tipo_producto_far=tipo_producto_far
        )
        
        return {
            "message": "Sensor settings updated successfully",
            "data": updated_doc
        }
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))