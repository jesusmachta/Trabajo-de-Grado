import os
import logging

# Deshabilitar el uso del proxy
os.environ['http_proxy'] = ''
os.environ['https_proxy'] = ''

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.routes import initialize_routes
from backend.aws import configure_cors_for_s3_bucket

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="StoreSense API",
    description="API para StoreSense",
    version="1.0.0",
)

# Configurar CORS para permitir peticiones desde el frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especificar dominios exactos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure S3 bucket CORS
try:
    cors_configured = configure_cors_for_s3_bucket()
    if cors_configured:
        logger.info("S3 bucket CORS configured successfully")
    else:
        logger.warning("S3 bucket CORS configuration may not have been applied")
except Exception as e:
    logger.error(f"Error configuring S3 bucket CORS: {e}")

# Inicializar las rutas
initialize_routes(app)

if __name__ == '__main__':
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host='0.0.0.0', port=port)