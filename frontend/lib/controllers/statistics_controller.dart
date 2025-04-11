import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class StatisticsController {
  static final StatisticsController _instance =
      StatisticsController._internal();

  factory StatisticsController() {
    return _instance;
  }

  StatisticsController._internal();

  // Base URL for API calls
  final String baseUrl = 'http://127.0.0.1:8000';

  // Improved client with timeout
  final http.Client _client = http.Client();

  // Cache for statistics data to avoid excessive calls
  final Map<String, Map<String, dynamic>> _cache = {};

  // Invalidate cache after 5 minutes to ensure fresh data
  final Duration _cacheInvalidationTime = const Duration(minutes: 5);
  final Map<String, DateTime> _lastFetchTime = {};

  // Verifica si un endpoint requiere parámetros adicionales
  bool _endpointRequiresParams(String endpoint) {
    return [
      'gender-distribution',
      'age-distribution',
      'most-visited',
      'least-visited',
      'emotion-comparison'
    ].contains(endpoint);
  }

  // Generate cache key based on endpoint and parameters
  String _generateCacheKey(String endpoint, Map<String, String>? params) {
    String key = endpoint;
    if (params != null && params.isNotEmpty) {
      List<String> paramPairs = [];
      for (var entry in params.entries) {
        paramPairs.add('${entry.key}=${entry.value}');
      }
      paramPairs.sort(); // Sort to ensure consistent keys
      key += '?' + paramPairs.join('&');
    }
    return key;
  }

  // Check if cache is valid
  bool _isCacheValid(String cacheKey) {
    if (!_cache.containsKey(cacheKey)) return false;

    final lastFetch = _lastFetchTime[cacheKey];
    if (lastFetch == null) return false;

    // For emotion-comparison, don't use cache
    if (cacheKey.startsWith('emotion-comparison')) return false;

    return DateTime.now().difference(lastFetch) < _cacheInvalidationTime;
  }

  // Obtener datos de estadísticas
  Future<Map<String, dynamic>> getStatistics(String endpoint,
      {Map<String, String>? params}) async {
    try {
      // Construir la URL base
      String url = '$baseUrl/api/statistics/$endpoint/';

      // Generate default parameters
      Map<String, String> defaultParams = {};
      if (_endpointRequiresParams(endpoint)) {
        // Caso especial para emotion-comparison
        if (endpoint == 'emotion-comparison') {
          // Always clear cache for emotion-comparison to ensure fresh data
          clearCache(endpoint);

          final now = DateTime.now();

          // Si no hay parámetros, usar período semanal por defecto
          if (params == null || !params.containsKey('period')) {
            defaultParams['period'] = 'week';

            // Fecha actual como fecha de fin
            final formatter = DateFormat('yyyy-MM-dd');
            defaultParams['end_date'] = formatter.format(now);

            // Una semana antes como fecha de inicio
            final startDate = now.subtract(const Duration(days: 6));
            defaultParams['date'] = formatter.format(startDate);
          }
          // Si el período es 'month' y no se especifica mes/año
          else if (params != null &&
              params['period'] == 'month' &&
              (!params.containsKey('month') || !params.containsKey('year'))) {
            defaultParams['month'] = now.month.toString();
            defaultParams['year'] = now.year.toString();
          }
        } else {
          defaultParams['period'] = 'week';

          // Incluir la fecha actual en formato YYYY-MM-DD si no se proporciona
          if (params == null || !params.containsKey('date')) {
            final now = DateTime.now();
            final formatter = DateFormat('yyyy-MM-dd');
            defaultParams['date'] = formatter.format(now);
          }
        }
      }

      // Combine default params with provided ones
      final Map<String, String> finalParams = {...defaultParams};
      if (params != null) {
        finalParams.addAll(params);
      }

      // Add parameters to URL
      if (finalParams.isNotEmpty) {
        url += '?';
        String queryParams = finalParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += queryParams;
      }

      print('Fetching statistics from: $url');

      // Check cache before making the request
      final cacheKey = _generateCacheKey(endpoint, finalParams);
      if (_isCacheValid(cacheKey)) {
        print('Using cached data for $cacheKey');
        return _cache[cacheKey]!;
      }

      // Make the request with timeout
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update cache
        _cache[cacheKey] = data;
        _lastFetchTime[cacheKey] = DateTime.now();

        return data;
      } else if (response.statusCode == 422) {
        throw Exception(
            'Error de validación: asegúrate de seleccionar parámetros válidos.');
      } else {
        throw Exception(
            'Error al cargar estadísticas. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getStatistics: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  // Clear cache for a specific endpoint or all if endpoint is null
  void clearCache([String? endpoint]) {
    if (endpoint != null) {
      // Clear only entries for this endpoint
      _cache.removeWhere((key, _) => key.startsWith(endpoint));
      _lastFetchTime.removeWhere((key, _) => key.startsWith(endpoint));
    } else {
      // Clear all cache
      _cache.clear();
      _lastFetchTime.clear();
    }
  }

  // Fetch both busy days statistics in one call
  Future<Map<String, dynamic>> getBusyDaysStatistics() async {
    try {
      final mostBusyDaysResponse = await getStatistics('busy-days');
      final leastBusyDaysResponse = await getStatistics('least-days');

      // Extraer directamente el día de la semana de la respuesta
      String mostBusyDay =
          mostBusyDaysResponse['data']['most_busy_day'] ?? 'No disponible';
      String leastBusyDay =
          leastBusyDaysResponse['data']['least_busy_day'] ?? 'No disponible';

      return {
        'message': 'Success',
        'data': {'most_busy_day': mostBusyDay, 'least_busy_day': leastBusyDay}
      };
    } catch (e) {
      print('Error al obtener estadísticas de días: $e');
      rethrow;
    }
  }

  // Fetch both most-visited and least-visited categories in one call
  Future<Map<String, dynamic>> getVisitedCategoriesStatistics() async {
    try {
      final mostVisitedResponse = await getStatistics('most-visited');
      final leastVisitedResponse = await getStatistics('least-visited');

      // Extract category and count data
      String mostVisitedCategory = mostVisitedResponse['data']
              ['most_visited_category'] ??
          'No disponible';
      int mostVisitedCount = mostVisitedResponse['data']['count'] ?? 0;

      String leastVisitedCategory = leastVisitedResponse['data']
              ['least_visited_category'] ??
          'No disponible';
      int leastVisitedCount = leastVisitedResponse['data']['count'] ?? 0;

      return {
        'message': 'Success',
        'data': {
          'most_visited_category': mostVisitedCategory,
          'most_visited_count': mostVisitedCount,
          'least_visited_category': leastVisitedCategory,
          'least_visited_count': leastVisitedCount
        }
      };
    } catch (e) {
      print('Error al obtener estadísticas de categorías visitadas: $e');
      rethrow;
    }
  }

  // Fetch historical visited categories (both most and least) in one call
  Future<Map<String, dynamic>>
      getHistoricalVisitedCategoriesStatistics() async {
    try {
      final response = await getStatistics('visited-categories-historical');

      // The response already contains both most and least visited categories
      return response;
    } catch (e) {
      print(
          'Error al obtener estadísticas históricas de categorías visitadas: $e');
      rethrow;
    }
  }

  // Fetch top successful categories data for podium display
  Future<List<Map<String, dynamic>>> getTopSuccessfulCategories() async {
    try {
      final response = await getStatistics('top-successful-categories');

      // Print detailed information about the response
      print('API Response for top-successful-categories:');
      print('Response type: ${response.runtimeType}');
      print('Response keys: ${response.keys.toList()}');
      print('Full response: $response');

      List<Map<String, dynamic>> topCategories = [];

      // Extract data from the response
      if (response is Map && response.containsKey('data')) {
        final rawData = response['data'];
        print('Raw data type: ${rawData.runtimeType}');

        if (rawData is List) {
          // Convert each item to a proper Map with required fields
          for (var item in rawData) {
            if (item is Map) {
              final category = item['category']?.toString() ?? 'Sin nombre';
              final happyCount = item['happy_count'] is int
                  ? item['happy_count']
                  : int.tryParse(item['happy_count'].toString()) ?? 0;

              topCategories.add({
                'category': category,
                'happy_count': happyCount,
                'emoji': _getCategoryEmoji(category)
              });
            }
          }
        }
      }

      print('Final processed categories: $topCategories');
      return topCategories;
    } catch (e) {
      print('Error al obtener categorías mejor evaluadas: $e');
      return []; // Return empty list instead of throwing to avoid crashes
    }
  }

  // Helper method to assign emojis to categories
  String _getCategoryEmoji(String category) {
    final Map<String, String> categoryEmojis = {
      'Snacks': '🍿',
      'Alcohol': '🍷',
      'Bebidas': '🥤',
      'Frutas': '🍎',
      'Verduras': '🥦',
      'Lácteos': '🥛',
      'Carnes': '🥩',
      'Panadería': '🍞',
      'Dulces': '🍬',
      'Limpieza': '🧹',
      'Electrónicos': '📱',
      'Ropa': '👕',
      // Add more categories as needed
    };

    return categoryEmojis[category] ??
        '🏆'; // Default trophy emoji if category not found
  }

  // Fetch both gender and age distribution in one call
  Future<Map<String, dynamic>> getGenderAgeDistributionStatistics(
      {Map<String, String>? params}) async {
    try {
      final genderResponse =
          await getStatistics('gender-distribution', params: params);
      final ageResponse =
          await getStatistics('age-distribution', params: params);

      // Extract data
      final genderData = genderResponse['data'] ?? {'male': 0, 'female': 0};
      final ageData = ageResponse['data'] ??
          {'0-18': 0, '19-25': 0, '26-35': 0, '36-50': 0, '51+': 0};

      return {
        'message': 'Success',
        'data': {'gender': genderData, 'age': ageData}
      };
    } catch (e) {
      print('Error al obtener estadísticas de género y edad: $e');
      rethrow;
    }
  }

  // Obtener las opciones para el selector de estadísticas
  List<Map<String, String>> getStatisticsOptions() {
    return [
      // Estadísticas básicas
      {'value': 'peak-hours', 'label': 'Horas pico'},
      {'value': 'least-hours', 'label': 'Horas valle'},
      {
        'value': 'busy-days-combined',
        'label': 'Días de la semana con más y menos afluencia'
      },
      {
        'value': 'visited-categories-combined',
        'label': 'Categorías más y menos visitadas'
      },
      {'value': 'most-frequent-emotions', 'label': 'Emociones más frecuentes'},
      {'value': 'emotion-percentage', 'label': 'Porcentaje de emociones'},

      // Estadísticas que requieren parámetros adicionales
      {
        'value': 'gender-age-combined',
        'label': 'Distribución por género y edad'
      },
      {'value': 'emotion-comparison', 'label': 'Comparación de emociones'},

      // Estadísticas históricas
      {
        'value': 'visited-categories-historical',
        'label': 'Histórico de categorías más y menos visitadas'
      },
      {
        'value': 'preferred-category-by-gender',
        'label': 'Categorías preferidas por género'
      },
      {
        'value': 'top-successful-categories',
        'label': 'Categorías mejor evaluadas'
      },
      {
        'value': 'emotional-differences-by-category',
        'label': 'Diferencias emocionales por categoría'
      },
      {
        'value': 'age-gender-distribution-by-category',
        'label': 'Distribución edad-género por categoría'
      },
    ];
  }
}
