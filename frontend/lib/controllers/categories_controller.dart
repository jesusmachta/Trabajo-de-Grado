import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoriesController {
  static final CategoriesController _instance =
      CategoriesController._internal();

  factory CategoriesController() {
    return _instance;
  }

  CategoriesController._internal();

  // Base URL for API calls
  final String baseUrl = 'http://127.0.0.1:8000';

  // Improved client with timeout
  final http.Client _client = http.Client();

  // Cache for categories data to avoid excessive calls
  List<Map<String, dynamic>>? _cachedCategories;
  DateTime? _lastFetchTime;

  // Cache invalidation time (5 minutes)
  final Duration _cacheInvalidationTime = const Duration(minutes: 5);

  // Fetch categories from the API
  Future<List<Map<String, dynamic>>> getCategories() async {
    // Check if cache is valid
    if (_cachedCategories != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheInvalidationTime) {
      print('Using cached categories');
      return _cachedCategories!;
    }

    try {
      final url = Uri.parse('$baseUrl/api/categories/');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception(
            'La solicitud tomó demasiado tiempo. Verifica tu conexión.');
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> categoryData = jsonResponse['data']['data'];

        // Cache the data
        _cachedCategories = List<Map<String, dynamic>>.from(categoryData);
        _lastFetchTime = DateTime.now();

        return _cachedCategories!;
      } else {
        throw Exception(
            'Error al cargar categorías. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getCategories: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  // Clear the cache
  void clearCache() {
    _cachedCategories = null;
    _lastFetchTime = null;
  }
}
