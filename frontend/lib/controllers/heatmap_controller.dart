import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/heatmap_data.dart';
import '../utils/api_constants.dart';
import '../utils/auth_service.dart';

class HeatmapController {
  final AuthService _authService = AuthService();

  // Get aggregated heatmap data
  Future<List<HeatmapLocation>> getAggregatedHeatmapData() async {
    try {
      final token = await _authService.getToken();

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
      final token = await _authService.getToken();

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
}
