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

  // Get aggregated heatmap data
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
}
