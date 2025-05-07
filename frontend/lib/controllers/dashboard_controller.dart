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
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    try {
      final url = '$baseUrl/api/dashboard/summary';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Error al cargar el resumen del dashboard. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getDashboardSummary: $e');
      throw Exception('Error al cargar el resumen del dashboard: $e');
    }
  }

  // Obtener todas las estadísticas del dashboard
  Future<Map<String, dynamic>> getAllDashboardStatistics(String token) async {
    try {
      Map<String, dynamic> dashboardData = {};

      // Fetch peak hours statistics
      final peakHoursResponse = await getStatisticById('peak-hours', token);
      dashboardData['peakHours'] = peakHoursResponse;

      // Fetch least busy hours statistics
      final leastHoursResponse = await getStatisticById('least-hours', token);
      dashboardData['leastHours'] = leastHoursResponse;

      // Fetch busy days combined statistics
      final busyDaysResponse = await getBusyDaysStatistics(token: token);
      dashboardData['busyDays'] = busyDaysResponse;

      // Fetch visited categories statistics
      final visitedCategoriesResponse =
          await getStatisticById('visited-categories-historical', token);
      dashboardData['visitedCategories'] = visitedCategoriesResponse;

      // Fetch emotion percentage statistics
      final emotionResponse =
          await getStatisticById('most-frequent-emotions', token);
      dashboardData['emotionPercentage'] = emotionResponse;

      // Fetch emotion percentage by category
      final emotionByCategoryResponse =
          await getStatisticById('emotion-percentage', token);
      dashboardData['emotionPercentageByCategory'] = emotionByCategoryResponse;

      // Fetch preferred categories by gender
      final preferredCategoriesByGenderResponse =
          await getStatisticById('preferred-category-by-gender', token);
      dashboardData['preferredCategoriesByGender'] =
          preferredCategoriesByGenderResponse;

      // Fetch top categories
      final topCategoriesResponse =
          await getStatisticById('top-successful-categories', token);
      dashboardData['topCategories'] = topCategoriesResponse;

      return dashboardData;
    } catch (e) {
      print('Error en getAllDashboardStatistics: $e');
      throw Exception('Error al cargar las estadísticas del dashboard: $e');
    }
  }

  // Obtener datos de estadísticas por ID específico
  Future<Map<String, dynamic>> getStatisticById(
      String endpoint, String token) async {
    try {
      final url = '$baseUrl/api/statistics/$endpoint/';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // No hay datos aún, retornar empty state
        return {'empty': true};
      } else {
        throw Exception(
            'Error al cargar estadísticas. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getStatisticById: $e');
      rethrow;
    }
  }

  // Obtener estadísticas de días más y menos concurridos
  Future<Map<String, dynamic>> getBusyDaysStatistics({
    required String token,
  }) async {
    try {
      final mostBusyDaysResponse = await getStatisticById('busy-days', token);
      final leastBusyDaysResponse = await getStatisticById('least-days', token);

      return {
        'most_busy_day':
            mostBusyDaysResponse['data']?['day'] ?? 'No disponible',
        'most_busy_count': mostBusyDaysResponse['data']?['count'] ?? 0,
        'least_busy_day':
            leastBusyDaysResponse['data']?['day'] ?? 'No disponible',
        'least_busy_count': leastBusyDaysResponse['data']?['count'] ?? 0,
      };
    } catch (e) {
      print('Error en getBusyDaysStatistics: $e');
      rethrow;
    }
  }
}
