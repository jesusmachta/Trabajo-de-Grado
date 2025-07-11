import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart'; // Import the config file

class CamerasController {
  static final CamerasController _instance = CamerasController._internal();

  factory CamerasController() {
    return _instance;
  }

  CamerasController._internal();

  // URL base para llamadas a la API - use AppConfig
  String get baseUrl => AppConfig.apiBaseUrl;

  // Cliente HTTP para las llamadas a la API
  final http.Client _client = http.Client();

  // Obtener todas las cámaras
  Future<List<Map<String, dynamic>>> getCameras(String token) async {
    final url = Uri.parse('$baseUrl/api/cameras');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> camerasData =
            json.decode(utf8.decode(response.bodyBytes));
        return List<Map<String, dynamic>>.from(camerasData);
      } else {
        throw Exception(
            'Error al cargar cámaras. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getCameras: $e');
      rethrow;
    }
  }

  // Obtener categorías activas
  Future<List<Map<String, dynamic>>> getActiveCategories(String token) async {
    final url = Uri.parse('$baseUrl/api/categories');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> allCategories = jsonResponse['data'];

        // Filtrar solo categorías activas
        final activeCategories = allCategories
            .where((category) =>
                category['isActive'] == true ||
                category['isActive'] == 'true' ||
                category['isActive'] == 1)
            .toList();

        return List<Map<String, dynamic>>.from(activeCategories);
      } else {
        throw Exception(
            'Error al cargar categorías. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getActiveCategories: $e');
      rethrow;
    }
  }

  // Añadir una nueva cámara
  Future<void> addCamera(int idCamara, int categoryId, String token) async {
    final url = Uri.parse('$baseUrl/api/cameras');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'Id_Camara': idCamara,
          'Tipo_Producto': categoryId,
          'isActive': true,
        }),
      );

      if (response.statusCode != 201) {
        String errorMessage = 'Error al añadir cámara';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error en addCamera: $e');
      rethrow;
    }
  }

  // Actualizar estado de cámara
  Future<void> toggleCameraStatus(
      String mongoId, bool newStatus, String token) async {
    final url = Uri.parse('$baseUrl/api/cameras/$mongoId');

    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'isActive': newStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Error al actualizar estado de la cámara: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error en toggleCameraStatus: $e');
      rethrow;
    }
  }

  // Editar una cámara existente
  Future<void> editCamera(
      String mongoId, int idCamara, int categoryId, String token) async {
    final url = Uri.parse('$baseUrl/api/cameras/$mongoId');

    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'Id_Camara': idCamara,
          'Tipo_Producto': categoryId,
        }),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Error al actualizar cámara';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error en editCamera: $e');
      rethrow;
    }
  }

  // Eliminar una cámara
  Future<void> deleteCamera(String mongoId, String token) async {
    final url = Uri.parse('$baseUrl/api/cameras/$mongoId');

    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception(
            'Error al eliminar cámara: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error en deleteCamera: $e');
      rethrow;
    }
  }
}
