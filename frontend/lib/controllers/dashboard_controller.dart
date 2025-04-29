import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DashboardController {
  static final DashboardController _instance = DashboardController._internal();

  factory DashboardController() {
    return _instance;
  }

  DashboardController._internal();

  // Base URL for API calls
  final String baseUrl = 'http://127.0.0.1:8000';

  // Improved client with timeout
  final http.Client _client = http.Client();

  // Verificar conexión con la API
  Future<String> testApiConnection() async {
    try {
      // Use relative URL for production, absolute for development
      final response = await http.get(Uri.parse('/api/hello'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        print('API connection failed with status: ${response.statusCode}');
        throw Exception(
            'API connection failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error connecting to API: $e');
      throw Exception('Error connecting to API: $e');
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

  // Get all statistics for the dashboard
  Future<Map<String, dynamic>> getAllDashboardStatistics() async {
    try {
      // Create a map to hold all statistics data
      Map<String, dynamic> dashboardData = {};

      // Fetch peak hours statistics with specific document ID
      final peakHoursResponse =
          await getStatisticById('peak-hours', 'peak_hours');
      dashboardData['peakHours'] = peakHoursResponse;

      // Fetch least busy hours statistics with specific document ID
      final leastHoursResponse =
          await getStatisticById('least-hours', 'least_busy_hours');
      dashboardData['leastHours'] = leastHoursResponse;

      // Fetch busy days combined statistics with specific document IDs
      final busyDaysResponse = await getBusyDaysStatistics(
          mostBusyDayId: 'most_busy_day', leastBusyDayId: 'least_busy_day');
      dashboardData['busyDays'] = busyDaysResponse;

      // Fetch visited categories statistics with specific document ID
      final visitedCategoriesResponse = await getStatisticById(
          'visited-categories-historical', 'historical_categories');
      dashboardData['visitedCategories'] = visitedCategoriesResponse;

      // Fetch emotion percentage statistics with specific document ID
      final emotionResponse = await getStatisticById(
          'emotion-percentage', 'most_frequent_emotions');
      dashboardData['emotionPercentage'] = emotionResponse;

      // Fetch emotion percentage by category (para la gráfica de emociones por categoría)
      final emotionByCategoryResponse = await getStatisticById(
          'emotion-percentage', 'emotion_percentage_by_category');
      dashboardData['emotionPercentageByCategory'] = emotionByCategoryResponse;

      // Fetch preferred categories by gender with specific document ID
      final preferredCategoriesByGenderResponse = await getStatisticById(
          'preferred-category-by-gender', 'preferred_category_by_gender');
      dashboardData['preferredCategoriesByGender'] =
          preferredCategoriesByGenderResponse;

      // Fetch top categories with specific document ID
      final topCategoriesResponse = await getStatisticById(
          'top-successful-categories', 'top_successful_categories');
      dashboardData['topCategories'] = topCategoriesResponse;

      return dashboardData;
    } catch (e) {
      print('Error getting all dashboard statistics: $e');
      throw Exception('Error al cargar las estadísticas del dashboard: $e');
    }
  }

  // Obtener datos de estadísticas por ID específico
  Future<Map<String, dynamic>> getStatisticById(
      String endpoint, String documentId) async {
    try {
      // Construir la URL con el ID del documento
      String url = '$baseUrl/api/statistics/$endpoint/?id=$documentId';
      print('Fetching statistics from: $url');

      // Make the request with timeout
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 422) {
        throw Exception(
            'Error de validación: asegúrate de seleccionar parámetros válidos.');
      } else {
        throw Exception(
            'Error al cargar estadísticas. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getStatisticById: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  // Make sure getBusyDaysStatistics fetches using document IDs
  Future<Map<String, dynamic>> getBusyDaysStatistics({
    required String mostBusyDayId,
    required String leastBusyDayId,
  }) async {
    try {
      final mostBusyDaysResponse =
          await getStatisticById('busy-days', mostBusyDayId);
      final leastBusyDaysResponse =
          await getStatisticById('least-days', leastBusyDayId);

      // Extraer los datos teniendo en cuenta la estructura actual:
      // data: {"day": "Wednesday", "count": 11}
      String mostBusyDay =
          mostBusyDaysResponse['data']?['day'] ?? 'No disponible';
      int mostBusyCount = mostBusyDaysResponse['data']?['count'] ?? 0;

      String leastBusyDay =
          leastBusyDaysResponse['data']?['day'] ?? 'No disponible';
      int leastBusyCount = leastBusyDaysResponse['data']?['count'] ?? 0;

      return {
        'message': 'Success',
        'data': {
          'most_busy_day': mostBusyDay,
          'most_busy_count': mostBusyCount,
          'least_busy_day': leastBusyDay,
          'least_busy_count': leastBusyCount
        }
      };
    } catch (e) {
      print('Error al obtener estadísticas de días: $e');
      rethrow;
    }
  }

  // Método para obtener las categorías Top Visitadas
  Future<dynamic> getTopSuccessfulCategories() async {
    try {
      return await getStatisticById(
          'top-successful-categories', 'top_successful_categories');
    } catch (e) {
      print('Error en getTopSuccessfulCategories: $e');
      rethrow;
    }
  }
}
