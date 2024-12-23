#!/bin/bash

# Inicializar y actualizar el submódulo
git submodule update --init --recursive

# Descargar el archivo del modelo
curl -L -o Real-ESRGAN/weights/RealESRGAN_x4plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth

# Iniciar la aplicación
uvicorn app:app --host 0.0.0.0 --port $PORT