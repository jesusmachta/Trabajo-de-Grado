import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardController {
  static final DashboardController _instance = DashboardController._internal();

  factory DashboardController() {
    return _instance;
  }

  DashboardController._internal();

  // Verificar conexión con la API
  Future<String> testApiConnection() async {
    try {
      final response = await http.get(Uri.parse('/api/hello'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        throw Exception(
            'Failed to connect to API. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener resumen del dashboard
  Future<Map<String, dynamic>> getDashboardSummary() async {
    // En un futuro, aquí se pueden agregar llamadas a más endpoints para obtener datos de resumen
    return {
      'title': 'Bienvenido al Sistema de Análisis de Clientes',
      'description':
          'Este sistema te permite visualizar estadísticas sobre el comportamiento de clientes en tiempo real.'
    };
  }
}
