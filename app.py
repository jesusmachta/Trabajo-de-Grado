from flask import Flask
from backend.routes import initialize_routes

app = Flask(__name__)

# Inicializar las rutas
initialize_routes(app)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)