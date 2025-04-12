import os

# Deshabilitar el uso del proxy
os.environ['http_proxy'] = ''
os.environ['https_proxy'] = ''

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.routes import initialize_routes

app = FastAPI(docs_url="/docs", redoc_url="/redoc")

# Configurar CORS para permitir peticiones desde el frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especificar dominios exactos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inicializar las rutas
initialize_routes(app)

if __name__ == '__main__':
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host='0.0.0.0', port=port)