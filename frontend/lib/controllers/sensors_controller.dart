import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorsController {
  static final SensorsController _instance = SensorsController._internal();

  factory SensorsController() {
    return _instance;
  }

  SensorsController._internal();

  // URL base para llamadas a la API
  final String baseUrl = 'http://127.0.0.1:8000';

  // Cliente HTTP para las llamadas a la API
  final http.Client _client = http.Client();

  // Obtener todos los sensores
  Future<List<Map<String, dynamic>>> getSensors(String token) async {
    final url = Uri.parse('$baseUrl/api/sensors');

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
        final List<dynamic> sensorsData =
            json.decode(utf8.decode(response.bodyBytes));
        return List<Map<String, dynamic>>.from(sensorsData);
      } else {
        throw Exception(
            'Error al cargar sensores. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getSensors: $e');
      rethrow;
    }
  }

  // Obtener categorías disponibles (no asignadas a sensores)
  Future<List<Map<String, dynamic>>> getAvailableCategories(String token,
      [String? sensorId]) async {
    try {
      String url = '$baseUrl/api/sensors/available-categories';
      if (sensorId != null) {
        url += '?sensor_id=$sensorId';
      }

      print('Fetching available categories from: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Timeout getting available categories');
          throw Exception(
              'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
        },
      );

      print('Available categories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse.containsKey('available_categories')) {
          final List<dynamic> availableCategories =
              jsonResponse['available_categories'];
          final result = List<Map<String, dynamic>>.from(availableCategories);
          print('Loaded ${result.length} available categories');
          return result;
        } else {
          print(
              'Response does not contain available_categories: ${response.body}');
          return [];
        }
      } else {
        print('Error response: ${response.body}');
        throw Exception(
            'Error al cargar categorías disponibles. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getAvailableCategories: $e');
      // Return empty list instead of throwing to prevent UI blocking
      return [];
    }
  }

  // Añadir un nuevo sensor
  Future<void> addSensor(int idSensor, int tipoPrincipal, int? tipoMedium,
      int? tipoFar, String token) async {
    final url = Uri.parse('$baseUrl/api/sensors');

    try {
      final Map<String, dynamic> sensorData = {
        'id_sensor': idSensor,
        'tipo_producto_principal': tipoPrincipal,
        'isActive': true,
      };

      if (tipoMedium != null) {
        sensorData['tipo_producto_medium'] = tipoMedium;
      }

      if (tipoFar != null) {
        sensorData['tipo_producto_far'] = tipoFar;
      }

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(sensorData),
      );

      if (response.statusCode != 201) {
        String errorMessage = 'Error al añadir sensor';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error en addSensor: $e');
      rethrow;
    }
  }

  // Actualizar estado de un sensor
  Future<void> toggleSensorStatus(
      String mongoId, bool newStatus, String token) async {
    final url = Uri.parse('$baseUrl/api/sensors/$mongoId');

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
            'Error al actualizar estado del sensor: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error en toggleSensorStatus: $e');
      rethrow;
    }
  }

  // Editar un sensor existente
  Future<void> editSensor(String mongoId, int idSensor, int tipoPrincipal,
      int? tipoMedium, int? tipoFar, String token) async {
    final url = Uri.parse('$baseUrl/api/sensors/$mongoId');

    try {
      final Map<String, dynamic> updateData = {
        'id_sensor': idSensor,
        'tipo_producto_principal': tipoPrincipal,
      };

      if (tipoMedium != null) {
        updateData['tipo_producto_medium'] = tipoMedium;
      } else {
        updateData['tipo_producto_medium'] = null;
      }

      if (tipoFar != null) {
        updateData['tipo_producto_far'] = tipoFar;
      } else {
        updateData['tipo_producto_far'] = null;
      }

      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Error al actualizar sensor';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error en editSensor: $e');
      rethrow;
    }
  }

  // Eliminar un sensor
  Future<void> deleteSensor(String mongoId, String token) async {
    final url = Uri.parse('$baseUrl/api/sensors/$mongoId');

    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception(
            'Error al eliminar sensor: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error en deleteSensor: $e');
      rethrow;
    }
  }
}
