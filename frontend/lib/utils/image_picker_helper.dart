import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  static bool _initialized = false;

  /// Initialize the image picker
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        // For web platform, make a dummy call to initialize the plugin
        await _picker
            .pickImage(
          source: ImageSource.gallery,
          maxWidth: 1,
        )
            .then((_) {
          // Just discard the result
        }).catchError((_) {
          // Silently handle error
        });
      }
      _initialized = true;
    } catch (e) {
      // Silently handle initialization error
      print('Image picker initialization error: $e');
    }
  }

  /// Pick an image from the specified source
  static Future<PickedImageResult?> pickImage({
    required ImageSource source,
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 85,
  }) async {
    try {
      await initialize();

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        return PickedImageResult(
          file: pickedFile,
          bytes: bytes,
          base64String: base64Encode(bytes),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      throw ImagePickerException(
        e.toString().contains('MissingPluginException')
            ? 'No se pudo inicializar el selector de imágenes. Por favor, reinicie la aplicación o utilice un navegador diferente.'
            : 'Error al seleccionar imagen: $e',
      );
    }
    return null;
  }
}

/// Result object for picked images
class PickedImageResult {
  final XFile file;
  final Uint8List bytes;
  final String base64String;

  PickedImageResult({
    required this.file,
    required this.bytes,
    required this.base64String,
  });
}

/// Custom exception for image picker
class ImagePickerException implements Exception {
  final String message;

  ImagePickerException(this.message);

  @override
  String toString() => message;
}
