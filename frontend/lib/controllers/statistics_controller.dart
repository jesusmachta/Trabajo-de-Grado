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
  final Map<String, dynamic> _cache = {};

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
      {Map<String, String>? params, required String token}) async {
    try {
      // Construir la URL base
      String url = '$baseUrl/api/statistics/$endpoint/';

      // Generar parámetros predeterminados
      Map<String, String> defaultParams = {};
      if (_endpointRequiresParams(endpoint)) {
        // Caso especial para emotion-comparison
        if (endpoint == 'emotion-comparison') {
          clearCache(endpoint);

          final now = DateTime.now();

          if (params == null || !params.containsKey('period')) {
            defaultParams['period'] = 'week';
            final formatter = DateFormat('yyyy-MM-dd');
            defaultParams['end_date'] = formatter.format(now);
            final startDate = now.subtract(const Duration(days: 6));
            defaultParams['date'] = formatter.format(startDate);
          } else if (params != null &&
              params['period'] == 'month' &&
              (!params.containsKey('month') || !params.containsKey('year'))) {
            defaultParams['month'] = now.month.toString();
            defaultParams['year'] = now.year.toString();
          }
        } else {
          // Period is 'historic' for gender/age stats when requesting overall data
          if (params != null &&
              params['period'] == 'historic' &&
              (endpoint == 'gender-distribution' ||
                  endpoint == 'age-distribution')) {
            defaultParams['period'] = 'historic';
          } else {
            defaultParams['period'] = 'week';
            if (params == null || !params.containsKey('date')) {
              final now = DateTime.now();
              final formatter = DateFormat('yyyy-MM-dd');
              defaultParams['date'] = formatter.format(now);
            }
          }
        }
      }

      // Combinar parámetros predeterminados con los proporcionados
      final Map<String, String> finalParams = {...defaultParams};
      if (params != null) {
        finalParams.addAll(params);
      }

      // Agregar parámetros a la URL
      if (finalParams.isNotEmpty) {
        url += '?';
        String queryParams = finalParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += queryParams;
      }

      print('Fetching statistics from: $url');

      // Generar clave de caché
      final cacheKey = _generateCacheKey(endpoint, finalParams);
      if (_isCacheValid(cacheKey)) {
        print('Using cached data for $cacheKey');
        return _cache[cacheKey]!;
      }

      // Realizar la solicitud con el token JWT
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Actualizar la caché
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
      rethrow;
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
  Future<Map<String, dynamic>> getBusyDaysStatistics(
      {required String token}) async {
    try {
      final mostBusyDaysResponse =
          await getStatistics('busy-days', token: token);
      final leastBusyDaysResponse =
          await getStatistics('least-days', token: token);

      // Extraer los datos teniendo en cuenta la estructura actual:
      // data: {"day": "Wednesday", "count": 11}
      String mostBusyDay =
          mostBusyDaysResponse['data']?['day'] ?? 'No disponible';
      String leastBusyDay =
          leastBusyDaysResponse['data']?['day'] ?? 'No disponible';

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
  Future<Map<String, dynamic>> getVisitedCategoriesStatistics(
      {Map<String, String>? params, required String token}) async {
    try {
      final mostVisitedResponse =
          await getStatistics('most-visited', params: params, token: token);
      final leastVisitedResponse =
          await getStatistics('least-visited', params: params, token: token);

      // Extract category and count data
      String mostVisitedCategory = mostVisitedResponse['data']
              ['most_visited_category'] ??
          'No disponible';
      int mostVisitedCount = mostVisitedResponse['data']['count'] ?? 0;

      String leastVisitedCategory =
          leastVisitedResponse['data']['category'] ?? 'No disponible';
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
  Future<Map<String, dynamic>> getHistoricalVisitedCategoriesStatistics(
      {required String token}) async {
    try {
      final response =
          await getStatistics('visited-categories-historical', token: token);

      // The response already contains both most and least visited categories
      return response;
    } catch (e) {
      print(
          'Error al obtener estadísticas históricas de categorías visitadas: $e');
      rethrow;
    }
  }

  // Método para obtener las categorías Top Visitadas
  Future<List<dynamic>> getTopSuccessfulCategories(
      {required String token}) async {
    try {
      // Endpoint ahora devuelve Top por Visitas Totales
      const endpoint = 'top-successful-categories';
      final url = '$baseUrl/api/statistics/$endpoint/';
      print('Fetching top categories with happy emotions from: $url');

      const cacheKey = endpoint;
      if (_isCacheValid(cacheKey)) {
        print('Using cached data for $cacheKey');
        // Cache should store List<dynamic> directly now
        final cachedData = _cache[cacheKey];
        if (cachedData is List) {
          return cachedData;
        } else {
          print(
              'Cache for $cacheKey has unexpected format (expected List). Clearing cache.');
          clearCache(endpoint);
        }
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
      });

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);

        // El backend devuelve un Map con una clave 'data' que contiene la Lista
        if (decodedBody is Map &&
            decodedBody.containsKey('data') &&
            decodedBody['data'] is List) {
          final List<dynamic> dataList = decodedBody['data'];
          // Store the List directly in the cache
          _cache[cacheKey] = dataList; // Store List, not Map
          _lastFetchTime[cacheKey] = DateTime.now();
          return dataList;
        } else {
          print(
              'Error: Unexpected response format for $endpoint. Expected Map with data List.');
          throw Exception('Formato de respuesta inesperado del servidor.');
        }
      } else {
        print(
            'Error fetching $endpoint: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Error al cargar top categorías. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getTopSuccessfulCategories: $e');
      rethrow;
    }
  }

  // Método para obtener diferencias emocionales por categoría
  Future<Map<String, dynamic>> getEmotionalDifferencesByCategory() async {
    try {
      // Llamar al endpoint que ahora devuelve directamente raw_counts
      final response =
          await getStatistics('emotional-differences-by-category', token: '');

      // Verificar que la respuesta tenga el formato esperado
      if (response.containsKey('data')) {
        return response;
      } else {
        print('Error: La respuesta no contiene el campo "data"');
        throw Exception('Formato de respuesta inesperado del servidor.');
      }
    } catch (e) {
      print('Error al obtener diferencias emocionales por categoría: $e');
      rethrow;
    }
  }

  // Fetch both gender and age distribution in one call
  Future<Map<String, dynamic>> getGenderAgeDistributionStatistics(
      {Map<String, String>? params, required String token}) async {
    try {
      print('Fetching gender distribution with params: $params');
      final genderResponse = await getStatistics('gender-distribution',
          params: params, token: token);

      print('Fetching age distribution with same params: $params');
      final ageResponse =
          await getStatistics('age-distribution', params: params, token: token);

      print('Gender Response: $genderResponse');
      print('Age Response: $ageResponse');

      // Fix: Extract complete response for debugging
      print('Full Gender Response Structure: ${jsonEncode(genderResponse)}');
      print('Full Age Response Structure: ${jsonEncode(ageResponse)}');

      // Ensure both responses exist
      if (genderResponse == null || ageResponse == null) {
        throw Exception('One or both API responses are null');
      }

      // Extract gender data - default values
      Map<String, dynamic> genderData = {'male': 0, 'female': 0};

      // Check if data exists directly in the response
      if (genderResponse.containsKey('data')) {
        var responseData = genderResponse['data'];

        // Direct format with male/female
        if (responseData is Map) {
          // Check for capitalized keys (Male/Female)
          if (responseData.containsKey('Male')) {
            genderData['male'] = responseData['Male'] ?? 0;
          }
          if (responseData.containsKey('Female')) {
            genderData['female'] = responseData['Female'] ?? 0;
          }

          // Check for lowercase keys (male/female)
          if (responseData.containsKey('male')) {
            genderData['male'] = responseData['male'] ?? 0;
          }
          if (responseData.containsKey('female')) {
            genderData['female'] = responseData['female'] ?? 0;
          }

          // Check for monthly data
          if (responseData.containsKey('monthly')) {
            var monthlyData = responseData['monthly'];

            if (params != null &&
                params.containsKey('month') &&
                params.containsKey('year')) {
              final month = params['month'] ?? '';
              final monthPadded =
                  month.isNotEmpty ? month.padLeft(2, '0') : '00';
              final monthKey = "${params['year']}-$monthPadded";

              print('Looking for month key: $monthKey in monthly data');

              if (monthlyData is Map && monthlyData.containsKey(monthKey)) {
                var monthData = monthlyData[monthKey];
                print('Found month data: $monthData');

                if (monthData is Map) {
                  // Check for capitalized keys in monthly data
                  if (monthData.containsKey('Male')) {
                    genderData['male'] = monthData['Male'] ?? 0;
                  }
                  if (monthData.containsKey('Female')) {
                    genderData['female'] = monthData['Female'] ?? 0;
                  }
                }
              }
            }
          }

          // Check overall data
          if (responseData.containsKey('overall')) {
            var overallData = responseData['overall'];

            if (overallData is Map) {
              if (overallData.containsKey('Male')) {
                genderData['male'] = overallData['Male'] ?? 0;
              }
              if (overallData.containsKey('Female')) {
                genderData['female'] = overallData['Female'] ?? 0;
              }
            }
          }
        }
      }

      print('Extracted gender data: $genderData');

      // Extract age data with a similar approach
      Map<String, dynamic> ageData = {'ages': {}};

      if (ageResponse.containsKey('data')) {
        var responseData = ageResponse['data'];

        if (responseData is Map) {
          // Check if ages is directly in the data
          if (responseData.containsKey('ages')) {
            ageData['ages'] = responseData['ages'];
          }

          // Check for monthly data
          if (responseData.containsKey('monthly')) {
            var monthlyData = responseData['monthly'];

            if (params != null &&
                params.containsKey('month') &&
                params.containsKey('year')) {
              final month = params['month'] ?? '';
              final monthPadded =
                  month.isNotEmpty ? month.padLeft(2, '0') : '00';
              final monthKey = "${params['year']}-$monthPadded";

              print('Looking for month key: $monthKey in age monthly data');

              if (monthlyData is Map && monthlyData.containsKey(monthKey)) {
                ageData['ages'] = monthlyData[monthKey];
                print('Found age month data: ${ageData['ages']}');
              }
            }
          }

          // Check overall data
          if (responseData.containsKey('overall')) {
            ageData['ages'] = responseData['overall'];
          }

          // Last resort: if we found nothing in standard places, use direct data
          if (ageData['ages'] == null ||
              (ageData['ages'] is Map && (ageData['ages'] as Map).isEmpty)) {
            ageData['ages'] = responseData;
          }
        }
      }

      print('Extracted age data: $ageData');

      // Return combined data
      return {
        'message': 'Success',
        'data': {'gender': genderData, 'age': ageData}
      };
    } catch (e) {
      print('Error al obtener estadísticas de sexo y edad: $e');
      rethrow;
    }
  }

  // Obtener las opciones para el selector de estadísticas
  List<Map<String, String>> getStatisticsOptions() {
    return [
      // Estadísticas básicas
      {'value': 'peak-hours', 'label': 'Horas pico', 'emoji': '🕒'},
      {
        'value': 'least-hours',
        'label': 'Horas menos concurridas',
        'emoji': '⏱️'
      },
      {
        'value': 'busy-days-combined',
        'label': 'Días de la semana con más y menos afluencia',
        'emoji': '📆'
      },
      {
        'value': 'visited-categories-combined',
        'label': 'Categorías más y menos visitadas',
        'emoji': '🛒'
      },
      {
        'value': 'most-frequent-emotions',
        'label': 'Emociones más frecuentes',
        'emoji': '😊'
      },
      {
        'value': 'emotion-percentage',
        'label': 'Porcentaje de emociones',
        'emoji': '📊'
      },

      // Estadísticas que requieren parámetros adicionales
      {
        'value': 'gender-age-combined',
        'label': 'Distribución por sexo y edad',
        'emoji': '👥'
      },

      // Estadísticas históricas
      {
        'value': 'preferred-category-by-gender',
        'label': 'Categorías preferidas por sexo',
        'emoji': '👫'
      },
      {
        'value': 'top-successful-categories',
        'label': 'Categorías mejor evaluadas',
        'emoji': '🏆'
      },
      {
        'value': 'emotional-differences-by-category',
        'label': 'Diferencias emocionales por categoría',
        'emoji': '😌'
      },
      {
        'value': 'age-gender-distribution-by-category',
        'label': 'Distribución edad-sexo por categoría',
        'emoji': '📊'
      },
    ];
  }

  // Obtener semanas disponibles para estadísticas demográficas (edad/sexo)
  Future<List<String>> getAvailableWeeks({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/statistics/age-distribution/dates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Error getting weeks: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final weeks = (data['data']?['weekly'] as List?)?.cast<String>() ?? [];
      // Ordenar descendente (más reciente primero)
      weeks.sort((a, b) => b.compareTo(a));
      print('Available weeks: $weeks');
      return weeks;
    } catch (e) {
      print('Error fetching available weeks: $e');
      return [];
    }
  }

  // Obtener meses disponibles para estadísticas demográficas (edad/sexo)
  Future<List<String>> getAvailableMonths({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/statistics/age-distribution/dates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Error getting months: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final months = (data['data']?['monthly'] as List?)?.cast<String>() ?? [];
      // Ordenar descendente (más reciente primero)
      months.sort((a, b) => b.compareTo(a));
      print('Available months: $months');
      return months;
    } catch (e) {
      print('Error fetching available months: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableDays({required String token}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/statistics/most-visited/dates'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('Error getting days: ${response.statusCode}');
      return [];
    }

    final data = jsonDecode(response.body);
    final days = (data['data']?['daily'] as List?)?.cast<String>() ?? [];
    days.sort((a, b) => b.compareTo(a));
    return days;
  }
}
