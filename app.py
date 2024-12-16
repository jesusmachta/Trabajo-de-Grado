import os
from fastapi import FastAPI
from backend.routes import initialize_routes

app = FastAPI()

# Inicializar las rutas
initialize_routes(app)

if __name__ == '__main__':
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host='0.0.0.0', port=port)