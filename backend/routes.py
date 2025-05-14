from backend.statistics.apis.categories_api import get_categories
from backend.statistics.apis.categories_api import router as categories_router
from backend.statistics.apis.update_category_api import update_category
from backend.statistics.apis.update_category_api import router as update_category_router
from backend.statistics.apis.delete_category_api import router as delete_category_router
from backend.statistics.apis.create_category_api import router as create_category_router
from backend.statistics.incremental_stats import initialize_statistics, update_statistics_on_insert
from backend.statistics.scheduled_stats_update import start_scheduler, shutdown_scheduler
from backend.auth.dependencies import get_empresa, get_current_user
from backend.auth.create_user import create_user, hash_password, validate_password, get_next_sequence_value
from backend.auth.login_user import login_user, create_access_token, verify_password
from backend.auth.read_user import get_user_by_id, get_all_users, verify_security_info, get_current_user_profile
from backend.auth.update_user import (
    update_user_profile, reset_password, update_profile_picture,
    upload_profile_picture_base64, upload_profile_picture_file, upload_profile_picture_web
)
from backend.auth.delete_user import delete_user
from backend.auth.create_company import create_company
from backend.auth.delete_company import delete_company
from backend.auth.auth_models import (  # Import models from auth_models.py
    UserCreate, UserLogin, Token, UserUpdate, ProfileUpdatePayload,
    ProfilePicturePayload, WebProfilePicturePayload
)
from backend.chat.chat_service import chat_router  # Import chat_router from new module
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

# User models
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = "user"  # default role
    date_of_birth: str  # Add date of birth field
    security_question: str  # Add security question field
    security_answer: str  # Add security answer field
    rif: Optional[int] = None  # <-- AGREGADO

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    email: str
    full_name: str
    role: str
    profile_picture: Optional[str] = None

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
    app.include_router(update_category_router, prefix="/api")
    app.include_router(delete_category_router, prefix="/api")
    app.include_router(create_category_router, prefix="/api")
    app.include_router(chat_router, prefix="/api", tags=["Chat"]) # Import chat_router from the new module
    app.include_router(categories_router, prefix="/api", tags=["Categories"])
    
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
        data = get_least_visited_category(empresa, period, date)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/least-visited-historical/")
def least_visited_category_historical(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto menos visitada utilizando todos los datos históricos.
    """
    try:
        data = get_least_visited_category_historical(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching historical categories for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching historical_categories.")

@router.get("/statistics/most-visited/")
def most_visited_category(period: str, date: Optional[str] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto más visitada en un rango de tiempo (día, semana o mes).
    """
    try:
        data = get_most_visited_category(empresa, period, date)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/most-visited-historical/")
def most_visited_category_historical(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la categoría de producto más visitada utilizando todos los datos históricos.
    """
    try:
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
        # Obtenemos tanto la categoría más visitada como la menos visitada históricamente
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
def emotion_percentage(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el porcentaje de emociones por categoría.
    """
    try:
        data = get_emotion_percentage_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching emotion percentage for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching emotion percentage.")

@router.get("/statistics/most-frequent-emotions/")
def most_frequent_emotions(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las emociones más frecuentes.
    """
    try:
        data = get_most_frequent_emotions(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error fetching emotion percentage for de company '{empresa}': {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching emotion percentage.")

@router.get("/statistics/age-distribution/")
def age_distribution(period: str = None, date: Optional[str] = None, end_date: Optional[str] = None, 
                     month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la distribución de visitantes por edad.
    """
    try:
        data = get_age_distribution(empresa, period, date, month, year)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/gender-distribution/")
def gender_distribution(period: str = None, date: Optional[str] = None, end_date: Optional[str] = None, 
                        month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener la distribución de visitantes por género.
    """
    try:
        data = get_gender_distribution(empresa, period, date, month, year)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/emotion-comparison/")
def emotion_comparison(period: str = "week", date: Optional[str] = None, end_date: Optional[str] = None, 
                      month: Optional[int] = None, year: Optional[int] = None, empresa: str = Depends(get_empresa)):
    """
    Endpoint para comparar emociones positivas (HAPPY) y negativas (SAD) por día de la semana.
    """
    try:
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
def preferred_category_by_gender(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las categorías de productos preferidas por género (hombres y mujeres).
    """
    try:
        data = get_preferred_category_by_gender(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error en preferred_category_by_gender: {e}")
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/top-successful-categories/")
def top_successful_categories(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener el top 3 de categorías más exitosas según emociones positivas (HAPPY count).
    """
    try:
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
def emotional_differences_by_category(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las emociones por género en cada categoría de productos.
    """
    try:
        data = get_emotional_differences_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.get("/statistics/age-gender-distribution-by-category/")
def age_gender_distribution_by_category(empresa: str = Depends(get_empresa)):
    """
    Endpoint para obtener las combinaciones de género y rango de edad más frecuentes por categoría de producto.
    """
    try:
        data = get_age_gender_distribution_by_category(empresa)
        return {"message": "Success", "data": data}
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        return {"message": "Error", "error": str(e)}

@router.post("/upload-image/")
async def upload_image_endpoint(background_tasks: BackgroundTasks, payload: ImagePayload):
    try:
        logger.info("Starting upload_image_endpoint")
        # Leer la imagen en formato Base64
        image_base64 = payload.image_base64
        id_camara = payload.id_camara
        empresa = payload.empresa  # Get the empresa parameter

        # --- VALIDACIÓN DE CÁMARA ACTIVA ---
        camera = collections['Tipo_Producto_Zona_Camara'].find_one({
            "Id_Camara": id_camara,
            "empresa": empresa
        })
        if not camera or not camera.get("isActive", False):
            raise HTTPException(status_code=403, detail="La cámara no está habilitada o está apagada (isActive = False)")
        # --- FIN VALIDACIÓN ---

        if not image_base64:
            raise HTTPException(status_code=400, detail="Empty image file provided")

        # Convertir la imagen de Base64 a bytes
        image_bytes = base64.b64decode(image_base64)

        # Convertir los bytes a formato JPEG
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert("RGB")  # Asegurarse de que esté en formato RGB
        jpeg_buffer = io.BytesIO()
        image.save(jpeg_buffer, format="JPEG")
        jpeg_bytes = jpeg_buffer.getvalue()

        # Mejorar la imagen utilizando OpenCV
        logger.info("Starting image enhancement with OpenCV")
        np_image = np.frombuffer(jpeg_bytes, np.uint8)
        cv_image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
        
        # Convertir BGR a RGB (OpenCV carga imágenes en BGR por defecto)
        cv_image_rgb = cv2.cvtColor(cv_image, cv2.COLOR_BGR2RGB)
        
        # Escalar la imagen (opcional, dependiendo de los requisitos)
        scale_factor = 1.0  # Sin escala para preservar la imagen original
        if scale_factor != 1.0:
            new_width = int(cv_image_rgb.shape[1] * scale_factor)
            new_height = int(cv_image_rgb.shape[0] * scale_factor)
            cv_image_rgb = cv2.resize(cv_image_rgb, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
            logger.info(f"Image resized to {new_width}x{new_height}")
        
        # Separar la imagen en canales L*a*b para preservar el color mientras mejoramos el brillo
        lab_image = cv2.cvtColor(cv_image_rgb, cv2.COLOR_RGB2LAB)
        l_channel, a_channel, b_channel = cv2.split(lab_image)
        
        # Aplicar CLAHE solo al canal L (luminosidad) para mejorar el contraste
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced_l_channel = clahe.apply(l_channel)
        
        # Reducir ruido manteniendo bordes en el canal de luminosidad
        enhanced_l_channel = cv2.bilateralFilter(enhanced_l_channel, 5, 50, 50)
        
        # Ajuste sutil de contraste en el canal L
        alpha = 1.1  # Contraste (1.0 = sin cambio)
        beta = 0     # Brillo (0 = sin cambio)
        enhanced_l_channel = cv2.convertScaleAbs(enhanced_l_channel, alpha=alpha, beta=beta)
        
        # Mejorar nitidez en el canal de luminosidad
        kernel = np.array([[-0.5, -0.5, -0.5], 
                          [-0.5,  5.0, -0.5], 
                          [-0.5, -0.5, -0.5]])
        enhanced_l_channel = cv2.filter2D(enhanced_l_channel, -1, kernel)
        
        # Reconstruir la imagen LAB con los canales de color originales
        enhanced_lab_image = cv2.merge([enhanced_l_channel, a_channel, b_channel])
        
        # Convertir de vuelta a RGB
        enhanced_rgb_image = cv2.cvtColor(enhanced_lab_image, cv2.COLOR_LAB2RGB)
        
        # Convertir a BGR para guardar con OpenCV
        enhanced_bgr_image = cv2.cvtColor(enhanced_rgb_image, cv2.COLOR_RGB2BGR)
        
        # Ajuste final de calidad
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 95]
        _, enhanced_image_bytes = cv2.imencode('.jpg', enhanced_bgr_image, encode_param)
        logger.info("Image enhancement with OpenCV completed")

        # Subir la imagen mejorada a S3 - Sin ACL para imágenes de cámara
        current_time = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        file_name = f"{current_time}_{id_camara}.jpeg"
        s3_url = upload_image_to_s3(enhanced_image_bytes.tobytes(), file_name)  # Sin ACL para imágenes normales
        logger.info(f"Image uploaded to S3: {s3_url}")

        # Llamar al siguiente endpoint para analizar la imagen
        background_tasks.add_task(analyze_image_endpoint, enhanced_image_bytes.tobytes(), id_camara, empresa)  # Pass empresa to the next function

        return {"message": "Image uploaded successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in upload_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def analyze_image_endpoint(image_bytes: bytes, id_camara: int, empresa: str):  # Add empresa parameter
    try:
        logger.info("Starting analyze_image_endpoint")

        # Analizar la imagen con AWS Rekognition
        response = analyze_image(image_bytes)
        logger.info("Image analyzed successfully")

        # Guardar los resultados del análisis en un archivo temporal
        analysis_result_path = "analysis_result.json"
        with open(analysis_result_path, "w") as f:
            json.dump(response, f)
        logger.info("Analysis results saved to temporary file")

        logger.info("Image analysis completed, calling save_to_db_endpoint")

        # Llamar al siguiente endpoint
        await save_to_db_endpoint(analysis_result_path, id_camara, empresa)  # Pass empresa to the next function
        logger.info("save_to_db_endpoint called successfully")

        return {"message": "Image analysis completed successfully, processing started."}

    except Exception as e:
        logger.error(f"Unexpected error in analyze_image_endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def save_to_db_endpoint(result_path: str, id_camara: int, empresa: str):  # Add empresa parameter
    try:
        logger.info("Starting save_to_db_endpoint")

        # Leer los resultados del análisis desde el archivo temporal
        with open(result_path, "r") as f:
            response = json.load(f)
        logger.info("Analysis results loaded from temporary file")

        # Filtrando los resultados para solo obtener AgeRange, Gender y Emotions
        filtered_faces = []
        for face_detail in response['FaceDetails']:
            filtered_face = {
                'AgeRange': face_detail.get('AgeRange'),
                'Gender': face_detail.get('Gender'),
                'Emotions': face_detail.get('Emotions')
            }
            filtered_faces.append(filtered_face)

        logger.info(f"Filtered faces: {filtered_faces}")
        
        # Obtener el tipo_producto correspondiente al id_camara
        tipo_producto_zona_camara = collections['Tipo_Producto_Zona_Camara'].find_one({"Id_Camara": id_camara})
        if not tipo_producto_zona_camara:
            raise HTTPException(status_code=404, detail="Id_Camara not found in Tipo_Producto_Zona_Camara")

        tipo_producto = tipo_producto_zona_camara['Tipo_Producto']
        logger.info(f"Found tipo_producto: {tipo_producto}")

        # Obtener el Categoria_Producto correspondiente al tipo_producto
        tipo_producto_doc = collections['Tipo_Producto'].find_one({"Tipo_Producto": tipo_producto})
        if not tipo_producto_doc:
            raise HTTPException(status_code=404, detail="Tipo_Producto not found in Tipo_Producto")

        categoria_producto = tipo_producto_doc['Categoria_Producto']
        logger.info(f"Found categoria_producto: {categoria_producto}")

        # Zona horaria de Venezuela
        venezuela_tz = timezone('America/Caracas')

        # Contador para documentos procesados correctamente
        documents_processed = 0
        stats_update_errors = 0

        # Insertar en MongoDB
        for face in filtered_faces:
            try:
                emotions = face['Emotions']
                primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
                
                # Obtener la hora actual en la zona horaria de Venezuela
                now_venezuela = datetime.now(venezuela_tz)
                
                document = {
                    "id": get_next_sequence_value("persona_id"),  # Obtener un ID único
                    "date": now_venezuela.strftime("%Y-%m-%d"),  # Fecha como cadena en formato YYYY-MM-DD
                    "time": now_venezuela.strftime("%H:%M:%S"),  # Hora en formato HH:MM:SS
                    "id_camara": id_camara,
                    "categoria_producto": categoria_producto,  # Agregar categoria_producto
                    "empresa": empresa,  # Add empresa to the document
                    "gender": face['Gender']['Value'],
                    "age_range": {
                        "low": face['AgeRange']['Low'],
                        "high": face['AgeRange']['High']
                    },
                    "emotions": primary_emotion
                }
                logger.info(f"Inserting document into MongoDB: {document}")
                
                # Insertar en Persona_AR
                insert_result = collections['Persona_AR'].insert_one(document)
                
                # Verificar que la inserción fue exitosa
                if insert_result.acknowledged:
                    logger.info(f"Document inserted successfully with ID: {document['id']}")
                    
                    # Actualizar las estadísticas de forma incremental
                    try:
                        logger.info(f"Updating statistics for document ID: {document['id']}")
                        from backend.statistics.incremental_stats import update_statistics_on_insert
                        update_statistics_on_insert(document)
                        logger.info(f"Statistics updated successfully for document ID: {document['id']}")
                        documents_processed += 1
                    except Exception as stats_error:
                        logger.error(f"Error updating statistics for document ID {document['id']}: {stats_error}")
                        stats_update_errors += 1
                        # Continuar con el siguiente documento, no interrumpir el proceso
                else:
                    logger.warning(f"Document insertion not acknowledged for face: {face['Gender']['Value']}")
            except Exception as face_error:
                logger.error(f"Error processing face {face.get('Gender',{}).get('Value', 'unknown')}: {face_error}")
                continue

        # Construir respuesta basada en los resultados
        if documents_processed > 0:
            status_msg = f"Procesados {documents_processed} documentos exitosamente"
            if stats_update_errors > 0:
                status_msg += f", pero hubo {stats_update_errors} errores al actualizar estadísticas"
            
            logger.info(status_msg)
            return {"message": status_msg}
        else:
            error_msg = "No se pudo procesar ningún documento correctamente"
            logger.error(error_msg)
            raise HTTPException(status_code=500, detail=error_msg)

    except Exception as e:
        logger.error(f"Unexpected error in save_to_db_endpoint: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

# Helper functions for auth
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a stored password against provided password."""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_access_token(data: dict, expires_delta: timedelta = None):
    """Create JWT token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def validate_password(password: str) -> tuple[bool, str]:
    """
    Validates a password against the following criteria:
    - Minimum 6 characters
    - Minimum 1 uppercase letter
    - Minimum 1 lowercase letter
    - Minimum 1 special character
    - Minimum 1 number
    
    Returns:
    - (True, "") if password is valid
    - (False, error_message) if not valid
    """
    # Check minimum length
    if len(password) < 6:
        return False, "La contraseña debe tener al menos 6 caracteres"
    
    # Check if contains at least one uppercase letter
    if not re.search(r'[A-Z]', password):
        return False, "La contraseña debe contener al menos una letra mayúscula"
    
    # Check if contains at least one lowercase letter
    if not re.search(r'[a-z]', password):
        return False, "La contraseña debe contener al menos una letra minúscula"
    
    # Check if contains at least one special character
    if not re.search(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]', password):
        return False, "La contraseña debe contener al menos un carácter especial"
    
    # Check if contains at least one number
    if not re.search(r'[0-9]', password):
        return False, "La contraseña debe contener al menos un número"
    
    return True, ""

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
class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    profile_picture: Optional[str] = None
    is_active: Optional[bool] = None  # <-- AGREGADO

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
class ProfileUpdatePayload(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None

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
class ProfilePicturePayload(BaseModel):
    image_base64: str

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

class WebProfilePicturePayload(BaseModel):
    image_base64: str
    file_name: Optional[str] = None

@router.post("/users/profile/picture/upload/web", response_model=dict)
async def upload_profile_picture_web_endpoint(
    payload: WebProfilePicturePayload,
    current_user: dict = Depends(get_current_user)
):
    """Upload a profile picture from web using base64."""
    user_id = str(current_user.get("_id"))
    
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

@router.post("/statistics/regenerate/")
async def regenerate_statistics():
    """
    Endpoint para regenerar todas las estadísticas desde cero usando los datos históricos.
    Este es un proceso costoso que puede tomar tiempo, dependiendo de la cantidad de datos.
    """
    try:
        # Importar función de recálculo
        from backend.statistics.incremental_stats import recalculate_all_statistics
        
        # Regenerar estadísticas en segundo plano
        background_tasks = BackgroundTasks()
        background_tasks.add_task(recalculate_all_statistics)
        
        return {
            "message": "Success", 
            "detail": "Iniciado proceso de regeneración de estadísticas en segundo plano"
        }
    except Exception as e:
        logger.error(f"Error iniciando regeneración de estadísticas: {e}")
        return {"message": "Error", "error": str(e)}

@router.post("/statistics/regenerate-preferred-gender/")
async def regenerate_preferred_gender_stats():
    """
    Endpoint para regenerar solo las estadísticas de categorías preferidas por género.
    """
    try:
        logger.info("Iniciando regeneración de estadísticas de categorías preferidas por género...")
        
        # 1. Eliminar el documento actual
        collections["Estadisticas"].delete_one({"_id": "preferred_category_by_gender"})
        
        # 2. Crear nuevo documento limpio
        preferred_doc = {
            "_id": "preferred_category_by_gender",
            "description": "Categorías preferidas por género",
            "data": {
                "Male": {"category": "", "count": 0},
                "Female": {"category": "", "count": 0}
            },
            "raw_counts": {
                "Male": {},
                "Female": {}
            },
            "last_updated": datetime.utcnow().isoformat()
        }
        collections["Estadisticas"].insert_one(preferred_doc)
        
        # 3. Procesar todos los documentos de Persona_AR para esta estadística específica
        total_docs = collections["Persona_AR"].count_documents({})
        processed = 0
        male_categories = {}
        female_categories = {}
        
        cursor = collections["Persona_AR"].find({})
        for document in cursor:
            try:
                gender = document.get("gender")
                category = document.get("categoria_producto")
                
                if gender and category:
                    if gender == "Male":
                        male_categories[category] = male_categories.get(category, 0) + 1
                    elif gender == "Female":
                        female_categories[category] = female_categories.get(category, 0) + 1
                
                processed += 1
            except Exception as e:
                logger.error(f"Error procesando documento: {e}")
                continue
        
        # 4. Calcular categorías preferidas
        male_preferred = {"category": "", "count": 0}
        if male_categories:
            max_male = max(male_categories.items(), key=lambda x: x[1])
            male_preferred = {"category": max_male[0], "count": max_male[1]}
        
        female_preferred = {"category": "", "count": 0}
        if female_categories:
            max_female = max(female_categories.items(), key=lambda x: x[1])
            female_preferred = {"category": max_female[0], "count": max_female[1]}
        
        # 5. Actualizar documento con resultados
        collections["Estadisticas"].update_one(
            {"_id": "preferred_category_by_gender"},
            {"$set": {
                "data": {
                    "Male": male_preferred,
                    "Female": female_preferred
                },
                "raw_counts": {
                    "Male": male_categories,
                    "Female": female_categories
                },
                "last_updated": datetime.utcnow().isoformat()
            }}
        )
        
        logger.info(f"Regeneración completada. Procesados {processed} documentos.")
        
        return {
            "message": "Success", 
            "detail": "Estadísticas de categorías preferidas por género regeneradas correctamente",
            "data": {
                "Male": male_preferred,
                "Female": female_preferred
            }
        }
    except Exception as e:
        logger.error(f"Error en regeneración de estadísticas preferred_category_by_gender: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {"message": "Error", "error": str(e)}

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

# En la regeneración, eliminar por _id que termine con :empresa
@router.post("/statistics/regenerate-for-company/")
async def regenerate_statistics_for_company(empresa: str):
    """
    Endpoint para regenerar todas las estadísticas para una empresa específica.
    Este es un proceso que puede tomar tiempo según la cantidad de datos.
    """
    try:
        # Eliminar todos los documentos de estadísticas existentes para esta empresa
        deleted = collections["Estadisticas"].delete_many({"_id": {"$regex": f":{empresa}$"}})
        logger.info(f"Se eliminaron {deleted.deleted_count} documentos de estadísticas para la empresa '{empresa}'")
        # Inicializar nuevos documentos de estadísticas para la empresa
        initialize_statistics_for_company(empresa)
        # Recalcular las estadísticas usando los datos históricos de esta empresa
        count = 0
        cursor = collections["Persona_AR"].find({"empresa": empresa})
        for document in cursor:
            try:
                from backend.statistics.incremental_stats import update_statistics_on_insert
                update_statistics_on_insert(document)
                count += 1
            except Exception as doc_error:
                logger.error(f"Error al procesar documento {document.get('id', 'unknown')}: {str(doc_error)}")
                continue
        return {
            "message": "Success", 
            "detail": f"Se regeneraron las estadísticas para la empresa '{empresa}'. Procesados {count} documentos."
        }
    except Exception as e:
        logger.error(f"Error al regenerar estadísticas para empresa '{empresa}': {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"Error al regenerar estadísticas: {str(e)}"
        )

# Add password recovery endpoints
@router.post("/forgot-password/verify", status_code=200)
async def verify_security_info_endpoint(
    data: dict = Body(...)
):
    """
    Endpoint to verify email, date of birth, and security question/answer for password recovery.
    """
    required_fields = ["email", "date_of_birth", "security_question", "security_answer"]
    for field in required_fields:
        if field not in data:
            raise HTTPException(
                status_code=400,
                detail=f"El campo '{field}' es requerido"
            )
    
    # Use the verify_security_info function from the model
    verification_result = verify_security_info(
        email=data["email"],
        date_of_birth=data["date_of_birth"],
        security_question=data["security_question"],
        security_answer=data["security_answer"]
    )
    
    # Generate token for password reset
    reset_token = create_access_token(
        data={"sub": verification_result["user_id"], "purpose": "password_reset"},
        expires_delta=timedelta(minutes=15)
    )
    
    return {
        "message": "Verificación exitosa",
        "reset_token": reset_token,
        "user_id": verification_result["user_id"]
    }

@router.post("/reset-password", status_code=200)
async def reset_password_endpoint(
    data: dict = Body(...)
):
    """
    Endpoint to change password after security verification.
    """
    if "reset_token" not in data or "new_password" not in data:
        raise HTTPException(
            status_code=400,
            detail="Se requieren 'reset_token' y 'new_password'"
        )
    
    reset_token = data["reset_token"]
    new_password = data["new_password"]
    
    try:
        # Verify the token
        payload = jwt.decode(reset_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        purpose = payload.get("purpose")
        
        if not user_id or purpose != "password_reset":
            raise HTTPException(
                status_code=401,
                detail="Token de restablecimiento inválido"
            )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401,
            detail="Token de restablecimiento inválido o expirado"
        )
    
    # Use the reset_password function from the model
    result = reset_password(user_id, new_password)
    
    return {
        "message": "Contraseña actualizada exitosamente"
    }

@router.post("/migrate-companies")
async def migrate_existing_companies():
    """
    Endpoint para migrar las empresas existentes a la colección Empresas.
    Este es un endpoint de uso único para migración de datos.
    """
    try:
        # Obtener todas las empresas únicas de la colección Users
        pipeline = [
            {"$group": {"_id": {"empresa": "$empresa", "rif": "$rif"}}},
            {"$project": {"nombre": "$_id.empresa", "rif": "$_id.rif", "_id": 0}}
        ]
        
        unique_companies = list(collections['Users'].aggregate(pipeline))
        
        # Contador de empresas migradas y empresas ya existentes
        migrated_count = 0
        already_exists_count = 0
        
        for company in unique_companies:
            nombre = company.get("nombre")
            rif = company.get("rif")
            
            # Validar que tengamos nombre y RIF
            if not nombre:
                logger.warning(f"Empresa sin nombre encontrada, omitiendo: {company}")
                continue
                
            # Verificar si ya existe en la colección Empresas
            existing = collections['Empresas'].find_one({"nombre": nombre})
            if existing:
                already_exists_count += 1
                continue
                
            # Crear documento de empresa
            empresa_doc = {
                "nombre": nombre,
                "rif": rif,
                "created_at": datetime.utcnow().isoformat(),
                "migrated": True  # Marcar como migrada para referencia
            }
            
            # Insertar en la colección Empresas
            collections['Empresas'].insert_one(empresa_doc)
            migrated_count += 1
            
        return {
            "message": "Migración completada",
            "migrated_count": migrated_count,
            "already_exists_count": already_exists_count,
            "total_processed": len(unique_companies)
        }
    
    except Exception as e:
        logger.error(f"Error al migrar empresas: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error al migrar empresas: {str(e)}")