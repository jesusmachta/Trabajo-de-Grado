import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/heatmap_controller.dart';
import '../models/heatmap_data.dart';
import '../widgets/heatmap_legend.dart';
import '../controllers/categories_controller.dart';

class HeatmapView extends StatefulWidget {
  const HeatmapView({Key? key}) : super(key: key);

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  late HeatmapController _controller;
  List<HeatmapLocation> _heatmapData = [];
  List<StoreCategory> _categories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Store layout
  StoreLayout? _storeLayout;

  // Maximum activity value for scaling
  double _maxActivity = 0;

  @override
  void initState() {
    super.initState();
    // El controller se inicializará en didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar el controlador una vez que el context esté disponible
    _controller = HeatmapController(context);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Load categories first
      final categories = await _controller.getStoreCategories();

      // 2. Then load heatmap data
      final heatmapData = await _controller.getAggregatedHeatmapData();

      // Find max activity for scaling
      double maxVal = 0;
      for (var location in heatmapData) {
        if (location.avgCount > maxVal) {
          maxVal = location.avgCount;
        }
      }

      // 3. Generate store layout from categories
      final storeLayout = StoreLayout.fromCategories(categories);

      setState(() {
        _categories = categories;
        _heatmapData = heatmapData;
        _storeLayout = storeLayout;
        _maxActivity = maxVal > 0 ? maxVal : 1; // Avoid division by zero
        _isLoading = false;
      });

      // Debug logs
      print('Loaded ${_categories.length} categories');
      print('Loaded ${_heatmapData.length} heatmap data points');
      print('Max activity value: $_maxActivity');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Calor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text('Error: $_errorMessage'))
              : _storeLayout == null
                  ? const Center(child: Text('No hay categorías disponibles'))
                  : Column(
                      children: [
                        Expanded(
                          child: InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(20),
                            minScale: 0.1,
                            maxScale: 3.0,
                            child: Center(
                              child: Container(
                                width: _storeLayout!.width,
                                height: _storeLayout!.height,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  color: Colors.grey[200],
                                ),
                                child: Stack(
                                  children: [
                                    // Draw store zones
                                    ..._storeLayout!.zones
                                        .map((zone) => Positioned(
                                              left: zone.x,
                                              top: zone.y,
                                              width: zone.width,
                                              height: zone.height,
                                              child: _buildZone(zone),
                                            )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Add legend at bottom
                        const HeatmapLegend(),
                      ],
                    ),
    );
  }

  Widget _buildZone(ZoneDefinition zone) {
    // Find the heatmap data for this zone
    // The locationId in heatmap data should match the category ID (Tipo_Producto)
    final zoneData = _heatmapData.firstWhere(
      (element) => element.locationId == zone.id,
      orElse: () => HeatmapLocation(
        locationId: zone.id,
        avgCount: 0,
        maxCount: 0,
        totalReadings: 0,
        lastUpdate: DateTime.now(),
      ),
    );

    // Calculate intensity between 0.0 and 1.0
    final intensity = _maxActivity > 0
        ? (zoneData.avgCount / _maxActivity).clamp(0.0, 1.0)
        : 0.0;

    // For debugging
    print(
        'Zone ${zone.id} (${zone.name}): avgCount=${zoneData.avgCount}, intensity=$intensity');

    // Choose color based on zone type and intensity
    Color zoneColor;
    if (zone.id == 'entrance') {
      // Entrance is always red regardless of intensity
      zoneColor = Colors.red.withOpacity(0.7);
    } else {
      zoneColor = _getHeatColor(intensity);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black45),
        color: zoneColor,
      ),
      child: Stack(
        children: [
          // Zone name
          Positioned(
            top: 5,
            left: 5,
            child: Text(
              zone.name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Icon
          Positioned(
            top: 5,
            right: 5,
            child: Icon(
              IconDataHelper.getIconByName(zone.icon),
              color: Colors.black54,
              size: 20,
            ),
          ),
          // Activity level
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Actividad: ${zoneData.avgCount.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to get color based on intensity
  Color _getHeatColor(double intensity) {
    // Clamp intensity between 0.0 and 1.0
    intensity = intensity.clamp(0.0, 1.0);

    if (intensity < 0.3) {
      // Blue to green (cold)
      return Color.lerp(
        Colors.blue.withOpacity(0.5),
        Colors.green.withOpacity(0.5),
        intensity / 0.3,
      )!;
    } else if (intensity < 0.7) {
      // Green to yellow (moderate)
      return Color.lerp(
        Colors.green.withOpacity(0.5),
        Colors.yellow.withOpacity(0.7),
        (intensity - 0.3) / 0.4,
      )!;
    } else {
      // Yellow to red (hot)
      return Color.lerp(
        Colors.yellow.withOpacity(0.7),
        Colors.red.withOpacity(0.8),
        (intensity - 0.7) / 0.3,
      )!;
    }
  }
}

// Helper class for icon conversion
class IconDataHelper {
  static IconData getIconByName(String name) {
    // Map of icon names to IconData objects
    Map<String, IconData> iconMap = {
      'category': Icons.category,
      'shopping_basket': Icons.shopping_basket,
      'fastfood': Icons.fastfood,
      'local_drink': Icons.local_drink,
      'bakery_dining': Icons.bakery_dining,
      'restaurant': Icons.restaurant,
      'liquor': Icons.liquor,
      'local_mall': Icons.local_mall,
      'checkroom': Icons.checkroom,
      'diamond': Icons.diamond,
      'watch': Icons.watch,
      'devices': Icons.devices,
      'phone_android': Icons.phone_android,
      'tv': Icons.tv,
      'laptop': Icons.laptop,
      'headphones': Icons.headphones,
      'camera_alt': Icons.camera_alt,
      'sports_basketball': Icons.sports_basketball,
      'sports_soccer': Icons.sports_soccer,
      'sports_tennis': Icons.sports_tennis,
      'fitness_center': Icons.fitness_center,
      'home': Icons.home,
      'bed': Icons.bed,
      'chair': Icons.chair,
      'kitchen': Icons.kitchen,
      'format_paint': Icons.format_paint,
      'toys': Icons.toys,
      'pets': Icons.pets,
      'child_friendly': Icons.child_friendly,
      'book': Icons.book,
      'auto_stories': Icons.auto_stories,
      'medical_services': Icons.medical_services,
      'spa': Icons.spa,
      'storefront': Icons.storefront,
    };

    return iconMap[name] ?? Icons.category;
  }
}
