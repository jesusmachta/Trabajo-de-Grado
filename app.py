from fastapi import FastAPI
from backend.routes import initialize_routes

app = FastAPI()

# Inicializar las rutas
initialize_routes(app)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=5001)