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

  // Create a new category
  Future<void> createCategory(
      int tipoProducto, String categoriaProducto, bool isActive) async {
    final url = Uri.parse('$baseUrl/api/categories/create');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "Tipo_Producto": tipoProducto,
          "Categoria_Producto": categoriaProducto,
          "isActive": isActive,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al crear categoría: ${response.body}');
      }
    } catch (e) {
      print('Error en createCategory: $e');
      rethrow; // Re-throw para manejar en la UI
    }
  }

  // Update a category
  Future<void> updateCategory(String id, String name, bool isActive) async {
    final url = Uri.parse('$baseUrl/api/categories/$id');
    try {
      final response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "Categoria_Producto": name,
          "isActive": isActive,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar categoría: ${response.body}');
      }
    } catch (e) {
      print('Error en updateCategory: $e');
      rethrow; // Re-throw para manejar en la UI
    }
  }

  // Delete a category
  Future<void> deleteCategory(String id) async {
    final url = Uri.parse('$baseUrl/api/categories/$id');
    try {
      final response = await _client.delete(url);

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar categoría: ${response.body}');
      }
    } catch (e) {
      print('Error en deleteCategory: $e');
      rethrow; // Re-throw para manejar en la UI
    }
  }

  // Obtener cámaras asociadas a un Tipo_Producto (categoría)
  Future<List<Map<String, dynamic>>> getCamerasByTipoProducto(
      int tipoProducto) async {
    final url = Uri.parse('$baseUrl/api/cameras');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> cameras =
            json.decode(utf8.decode(response.bodyBytes));
        // Filtrar cámaras por Tipo_Producto
        return cameras
            .where((cam) =>
                cam['Tipo_Producto_Id'] == tipoProducto ||
                cam['Tipo_Producto'] == tipoProducto)
            .map<Map<String, dynamic>>((cam) => Map<String, dynamic>.from(cam))
            .toList();
      } else {
        throw Exception('Error al obtener cámaras: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getCamerasByTipoProducto: $e');
      rethrow;
    }
  }
}
