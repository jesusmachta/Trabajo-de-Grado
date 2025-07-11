import 'package:flutter/material.dart';
import 'heatmap_view.dart';

// Routes for the application
class Routes {
  static const String heatmap = '/heatmap';

  // Method to define all routes in the app
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      heatmap: (context) => const HeatmapView(),
    };
  }

  // Method to navigate to heatmap screen
  static void navigateToHeatmap(BuildContext context) {
    Navigator.pushNamed(context, heatmap);
  }
}
