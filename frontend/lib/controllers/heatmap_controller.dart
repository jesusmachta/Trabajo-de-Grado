import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/heatmap_data.dart';
import '../utils/api_constants.dart';
import 'auth_controller.dart';

class HeatmapController {
  final BuildContext context;

  HeatmapController(this.context);

  // Get store categories from Tipo_Producto collection
  Future<List<StoreCategory>> getStoreCategories() async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['message'] == 'Success' &&
            responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          final categories = data
              .where((category) => category['isActive'] == true)
              .map((category) => StoreCategory.fromJson(category))
              .toList();

          print('Fetched ${categories.length} active categories');
          return categories;
        } else {
          throw Exception(
              'Failed to load categories: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getStoreCategories: $e');
      throw Exception('Failed to load store categories: $e');
    }
  }

  // Get aggregated heatmap data by sensors
  Future<List<HeatmapLocation>> getAggregatedHeatmapData() async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/heatmap/aggregated'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['message'] == 'Success' &&
            responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          return data.map((item) => HeatmapLocation.fromJson(item)).toList();
        } else {
          throw Exception(
              'Failed to load heatmap data: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to load heatmap data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAggregatedHeatmapData: $e');
      throw Exception('Failed to load heatmap data: $e');
    }
  }

  // Get raw heatmap data for a specific time period
  Future<List<dynamic>> getHeatmapData({int hours = 24}) async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/heatmap/data?hours=$hours'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['message'] == 'Success' &&
            responseData['data'] != null) {
          return responseData['data'];
        } else {
          throw Exception(
              'Failed to load heatmap data: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to load heatmap data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getHeatmapData: $e');
      throw Exception('Failed to load heatmap data: $e');
    }
  }

  // Get sensor settings for the current company
  Future<Map<String, dynamic>> getSensorSettings() async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/sensor-settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['message'] == 'Success' &&
            responseData['data'] != null) {
          return responseData['data'];
        } else {
          throw Exception(
              'Failed to load sensor settings: ${responseData['message']}');
        }
      } else {
        throw Exception(
            'Failed to load sensor settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getSensorSettings: $e');
      throw Exception('Failed to load sensor settings: $e');
    }
  }

  // Update sensor settings for the current company
  Future<Map<String, dynamic>> updateSensorSettings({
    required int tipoPrincipal,
    required int tipoMedium,
    required int tipoFar,
  }) async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final Map<String, dynamic> requestData = {
        'tipo_producto_principal': tipoPrincipal,
        'tipo_producto_medium': tipoMedium,
        'tipo_producto_far': tipoFar,
      };

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/sensor-settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['message'] == 'Sensor settings updated successfully' &&
            responseData['data'] != null) {
          return responseData['data'];
        } else {
          throw Exception(
              'Failed to update sensor settings: ${responseData['message']}');
        }
      } else {
        throw Exception(
            'Failed to update sensor settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateSensorSettings: $e');
      throw Exception('Failed to update sensor settings: $e');
    }
  }
}
