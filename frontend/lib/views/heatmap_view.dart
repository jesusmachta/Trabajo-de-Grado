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

  // Track hovered card
  String? _hoveredZoneId;

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      // Removed AppBar for a cleaner look
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(child: Text('Error: $_errorMessage'))
                : _storeLayout == null
                    ? const Center(child: Text('No hay categorías disponibles'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom title bar with refresh button
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mapa de Calor',
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF223A5E),
                                  ),
                                ),
                                // Floating refresh button with nicer styling
                                FloatingActionButton.small(
                                  tooltip: 'Actualizar',
                                  onPressed: _loadData,
                                  elevation: 2,
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  child: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          ),

                          // Brief description
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              'Visualización de la actividad en cada zona de la tienda en tiempo real',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),

                          // The actual heatmap
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Card(
                                elevation: 2,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildCategoryGrid(isDarkMode),
                                ),
                              ),
                            ),
                          ),

                          // Simplified legend at bottom as in image
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: HeatmapLegend(),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildCategoryGrid(bool isDarkMode) {
    final filteredZones = _storeLayout!.zones
        .where((zone) => zone.id != 'entrance') // Filter out entrance
        .toList();

    if (filteredZones.isEmpty) {
      return Center(
        child: Text(
          'No hay categorías disponibles',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.5, // Make cards shorter in height
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredZones.length,
      itemBuilder: (context, index) {
        final zone = filteredZones[index];
        return _buildZoneCard(zone, isDarkMode);
      },
    );
  }

  Widget _buildZoneCard(ZoneDefinition zone, bool isDarkMode) {
    // Find the heatmap data for this zone
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

    // Choose color based on zone type and intensity
    Color zoneColor = _getHeatColor(intensity);

    final isHovered = _hoveredZoneId == zone.id;

    // Better looking container with hover effect
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredZoneId = zone.id),
      onExit: (_) => setState(() => _hoveredZoneId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: isHovered
            ? Matrix4.translationValues(0, -5, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          color: zoneColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category name
                  Expanded(
                    child: Text(
                      zone.name,
                      style: TextStyle(
                        color: isDarkMode || intensity > 0.7
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Category icon
                  Icon(
                    IconDataHelper.getIconByName(zone.icon),
                    color: isDarkMode || intensity > 0.7
                        ? Colors.white70
                        : Colors.black54,
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to get color based on intensity with more attractive colors
  Color _getHeatColor(double intensity) {
    // Clamp intensity between 0.0 and 1.0
    intensity = intensity.clamp(0.0, 1.0);

    if (intensity < 0.3) {
      // Low activity (blue)
      return Colors.blue.shade200;
    } else if (intensity < 0.7) {
      // Medium activity (yellow)
      return Colors.amber.shade300;
    } else {
      // High activity (red)
      return Colors.red.shade400;
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
