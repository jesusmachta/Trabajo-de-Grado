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
    half=False  # Mantener en False para mejor precisión de color
)

def enhance_image(image_bytes):
    try:
        logger.info("Starting image enhancement process")

        # Cargar la imagen desde los bytes
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert('RGB')  # Asegurarse de que la imagen esté en formato RGB
        logger.info("Image loaded and converted to RGB")

        # Guardar información de color original
        original_img = np.array(image)
        logger.info(f"Image converted to numpy array with shape {original_img.shape}")

        # Usar el método enhance de RealESRGANer con un factor de escala menor
        try:
            # Usar un factor de escala menor (2 en lugar de 4) para preservar mejor los colores
            # Desactivar face_enhance para evitar cambios de color no deseados
            output, _ = upsampler.enhance(original_img, outscale=2, face_enhance=False)
            logger.info("Successfully enhanced image using upsampler.enhance method")
        except Exception as e:
            logger.warning(f"Error using upsampler.enhance: {e}, falling back to manual approach")
            
            # Enfoque manual si el anterior falla
            # Convertir a tensor PyTorch con la forma correcta
            img_tensor = torch.from_numpy(original_img.astype(np.float32) / 255.0)
            # Cambiar de [H, W, C] a [1, C, H, W] - formato que espera PyTorch
            img_tensor = img_tensor.permute(2, 0, 1).unsqueeze(0)
            
            logger.info(f"Tensor shape after permute: {img_tensor.shape}")
            
            # Aplicar el modelo
            with torch.no_grad():
                output_tensor = upsampler.model(img_tensor)
            
            # Convertir de vuelta a numpy
            output = output_tensor.squeeze().permute(1, 2, 0).cpu().numpy()
            # Escalar de vuelta a 0-255
            output = (output * 255.0).round()

        logger.info("Image enhancement completed")

        # Asegurarse de que los valores estén en el rango correcto [0, 255]
        output = np.clip(output, 0, 255).astype(np.uint8)
        
        # Crear una imagen desde el array
        output_image = Image.fromarray(output)
        
        # Verificar si es necesario ajustar los colores por comparación
        if output_image.size != image.size:
            # Redimensionar la original para comparación si los tamaños difieren
            image = image.resize(output_image.size, Image.LANCZOS)
        
        # Convertir la imagen mejorada a bytes
        buffer = io.BytesIO()
        output_image.save(buffer, format='JPEG', quality=95)  # Usar calidad alta para preservar detalles
        enhanced_image_bytes = buffer.getvalue()
        logger.info("Enhanced image converted to bytes")

        # Liberar memoria
        del image, original_img, output, output_image, buffer
        if 'img_tensor' in locals():
            del img_tensor
            if 'output_tensor' in locals():
                del output_tensor
        torch.cuda.empty_cache()
        logger.info("Memory cleared")

        return enhanced_image_bytes
    except Exception as e:
        logger.error(f"Error enhancing image: {e}")
        raise