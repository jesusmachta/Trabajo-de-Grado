import os
import numpy as np
from PIL import Image
import io
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer

# Configurar el modelo de Real-ESRGAN
model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
netscale = 4
model_path = os.path.join("Real-ESRGAN-weights", "RealESRGAN_x4plus.pth")  # Actualiza la ruta del modelo
upsampler = RealESRGANer(
    scale=netscale,
    model_path=model_path,
    model=model,
    tile=0,
    tile_pad=10,
    pre_pad=0,
    half=True
)

def enhance_image(image_bytes):
    # Cargar la imagen desde los bytes
    image = Image.open(io.BytesIO(image_bytes))
    image = image.convert('RGB')  # Asegurarse de que la imagen esté en formato RGB

    # Convertir la imagen a un array de numpy
    img = np.array(image)

    # Mejorar la imagen utilizando Real-ESRGAN
    output, _ = upsampler.enhance(img, outscale=4)
    output_image = Image.fromarray(output)

    # Convertir la imagen mejorada a bytes
    buffer = io.BytesIO()
    output_image.save(buffer, format='JPEG')
    enhanced_image_bytes = buffer.getvalue()

    return enhanced_image_bytes