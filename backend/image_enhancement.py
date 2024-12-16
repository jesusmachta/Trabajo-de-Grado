import tensorflow as tf
import tensorflow_hub as hub
import numpy as np
from PIL import Image
import io
import os

# Cargar el modelo preentrenado de superresolución de imágenes desde el sistema de archivos
model = hub.load("models/esrgan-tf2")

def enhance_image(image_bytes):
    # Cargar la imagen desde los bytes
    image = Image.open(io.BytesIO(image_bytes))
    image = image.convert('RGB')  # Asegurarse de que la imagen esté en formato RGB

    # Convertir la imagen a un tensor
    image_tensor = tf.convert_to_tensor(np.array(image), dtype=tf.float32)
    image_tensor = tf.expand_dims(image_tensor, axis=0)  # Añadir una dimensión para el batch

    # Normalizar la imagen
    image_tensor = (image_tensor / 127.5) - 1.0

    # Aplicar el modelo a la imagen
    enhanced_image_tensor = model(image_tensor)

    # Desnormalizar la imagen
    enhanced_image_tensor = (enhanced_image_tensor + 1.0) * 127.5
    enhanced_image_tensor = tf.clip_by_value(enhanced_image_tensor, 0, 255)
    enhanced_image_tensor = tf.cast(enhanced_image_tensor, tf.uint8)

    # Convertir el tensor mejorado de vuelta a bytes
    enhanced_image = Image.fromarray(tf.squeeze(enhanced_image_tensor).numpy())
    buffer = io.BytesIO()
    enhanced_image.save(buffer, format='JPEG')
    enhanced_image_bytes = buffer.getvalue()

    return enhanced_image_bytes