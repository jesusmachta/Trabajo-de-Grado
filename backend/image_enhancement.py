import os
import numpy as np
from PIL import Image
import io
import torch
from backend.real_esrgan.rrdbnet_arch import RRDBNet
from backend.real_esrgan.realesrgan import RealESRGANer
import logging
import requests

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Directorio donde se almacenará el modelo
model_dir = "Real-ESRGAN-weights"
model_path = os.path.join(model_dir, "RealESRGAN_x4plus.pth")

# Verificar si el modelo existe, si no, descargarlo
if not os.path.exists(model_path):
    logger.info("Modelo no encontrado. Descargando...")
    os.makedirs(model_dir, exist_ok=True)
    url = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
    r = requests.get(url, allow_redirects=True)
    with open(model_path, 'wb') as f:
        f.write(r.content)
    logger.info("Modelo descargado exitosamente.")

# Configurar el modelo de Real-ESRGAN
model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
netscale = 4

upsampler = RealESRGANer(
    scale=netscale,
    model_path=model_path,
    model=model,
    tile=512,  # prueba para reducir el consumo de memoria
    tile_pad=10,
    pre_pad=0,
    half=False  
)

def enhance_image(image_bytes):
    try:
        logger.info("Starting image enhancement process")

        # Cargar la imagen desde los bytes
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert('RGB')  # Asegurarse de que la imagen esté en formato RGB
        logger.info("Image loaded and converted to RGB")

        # Convertir la imagen a un array de numpy
        img = np.array(image)
        logger.info("Image converted to numpy array")

        # Mejorar la imagen utilizando Real-ESRGAN
        output, _ = upsampler.enhance(img, outscale=4)
        logger.info("Image enhancement completed")

        output_image = Image.fromarray(output)

        # Convertir la imagen mejorada a bytes
        buffer = io.BytesIO()
        output_image.save(buffer, format='JPEG')
        enhanced_image_bytes = buffer.getvalue()
        logger.info("Enhanced image converted to bytes")

        # Liberar memoria
        del image, img, output, output_image, buffer
        torch.cuda.empty_cache()
        logger.info("Memory cleared")

        return enhanced_image_bytes
    except Exception as e:
        logger.error(f"Error enhancing image: {e}")
        raise