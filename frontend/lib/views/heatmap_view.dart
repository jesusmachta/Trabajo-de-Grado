import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/heatmap_controller.dart';
import '../models/heatmap_data.dart';
import '../widgets/heatmap_legend.dart';
import '../controllers/categories_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Threshold values for tier classification
  int _lowThreshold = 5; // Default value
  int _mediumThreshold = 10; // Default value
  int _highThreshold = 15; // Default value

  // Loading state for sensor settings
  bool _isLoadingSettings = false;

  @override
  void initState() {
    super.initState();
    // The controller will be initialized in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the controller once the context is available
    _controller = HeatmapController(context);
    _loadData();
    _loadSensorSettings();
  }

  Future<void> _loadSensorSettings() async {
    setState(() {
      _isLoadingSettings = true;
    });

    try {
      final settings = await _controller.getSensorSettings();

      setState(() {
        _lowThreshold = settings['tipo_producto_far'] ?? 5;
        _mediumThreshold = settings['tipo_producto_medium'] ?? 10;
        _highThreshold = settings['tipo_producto_principal'] ?? 15;
        _isLoadingSettings = false;
      });

      print(
          'Loaded sensor settings - Low: $_lowThreshold, Medium: $_mediumThreshold, High: $_highThreshold');
    } catch (e) {
      setState(() {
        _isLoadingSettings = false;
      });
      print('Error loading sensor settings: $e');
    }
  }

  Future<void> _updateSensorSettings(int low, int medium, int high) async {
    try {
      await _controller.updateSensorSettings(
        tipoPrincipal: high,
        tipoMedium: medium,
        tipoFar: low,
      );

      // Update local state
      setState(() {
        _lowThreshold = low;
        _mediumThreshold = medium;
        _highThreshold = high;
      });

      print(
          'Updated sensor settings - Low: $low, Medium: $medium, High: $high');
    } catch (e) {
      print('Error updating sensor settings: $e');
      rethrow; // Re-throw to handle in the calling function
    }
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
        if (location.avgPrincipal > maxVal) {
          maxVal = location.avgPrincipal;
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

  void _showSettingsDialog() {
    int tempLow = _lowThreshold;
    int tempMedium = _mediumThreshold;
    int tempHigh = _highThreshold;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Configuración del Mapa de Calor'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            content: SizedBox(
              width: 500, // Make the dialog wider
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Threshold settings content
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configure los umbrales para cada nivel de actividad:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 24),

                          // Bajo Threshold
                          const Text('Bajo:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Umbral Bajo',
                              hintText: 'Ingrese cantidad de personas',
                              isDense: false,
                              border: OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            controller:
                                TextEditingController(text: tempLow.toString()),
                            onChanged: (value) {
                              tempLow = int.tryParse(value) ?? tempLow;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Medio Threshold
                          const Text('Medio:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Umbral Medio',
                              hintText: 'Ingrese cantidad de personas',
                              isDense: false,
                              border: OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            controller: TextEditingController(
                                text: tempMedium.toString()),
                            onChanged: (value) {
                              tempMedium = int.tryParse(value) ?? tempMedium;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Alto Threshold
                          const Text('Alto:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Umbral Alto',
                              hintText: 'Ingrese cantidad de personas',
                              isDense: false,
                              border: OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            controller: TextEditingController(
                                text: tempHigh.toString()),
                            onChanged: (value) {
                              tempHigh = int.tryParse(value) ?? tempHigh;
                            },
                          ),

                          // Rules guidance
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reglas de configuración',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Los umbrales deben seguir la regla: Bajo ≤ Medio ≤ Alto',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  bool isValid = true;
                  String errorMessage = '';

                  // Validate threshold values
                  if (!(tempLow <= tempMedium && tempMedium <= tempHigh)) {
                    isValid = false;
                    errorMessage =
                        'Los umbrales deben seguir la regla: Bajo ≤ Medio ≤ Alto';
                  }

                  if (isValid) {
                    // Update thresholds via API
                    _updateSensorSettings(tempLow, tempMedium, tempHigh)
                        .then((_) {
                      // Close the dialog on success
                      Navigator.of(context).pop();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Configuración actualizada con éxito'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Reload data to apply changes
                      _loadData();
                    }).catchError((error) {
                      // Show error on failure but keep dialog open
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  } else {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  // Method to show the help dialog for Activity Ranking
  void _showActivityRankingHelpDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Ranking de Actividad'),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: 500), // Ensure dialog is not too wide
            child: SingleChildScrollView(
              // Added SingleChildScrollView for potentially longer content
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Visualización de la actividad en cada zona de la tienda en tiempo real.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const HeatmapLegend(), // The legend content
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
                          // Custom title bar with refresh and settings buttons
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
                                // Action buttons
                                Row(
                                  children: [
                                    // Settings button
                                    FloatingActionButton.small(
                                      tooltip: 'Configuración',
                                      onPressed: _showSettingsDialog,
                                      elevation: 2,
                                      backgroundColor:
                                          theme.colorScheme.secondary,
                                      foregroundColor:
                                          theme.colorScheme.onSecondary,
                                      child: const Icon(Icons.settings),
                                    ),
                                    const SizedBox(width: 8),
                                    // Help button for Ranking de Actividad
                                    FloatingActionButton.small(
                                      tooltip: 'Ayuda Ranking de Actividad',
                                      onPressed: _showActivityRankingHelpDialog,
                                      elevation: 2,
                                      backgroundColor:
                                          theme.colorScheme.tertiary,
                                      foregroundColor:
                                          theme.colorScheme.onTertiary,
                                      child: const Icon(Icons.help_outline),
                                    ),
                                    const SizedBox(width: 8),
                                    // Refresh button
                                    FloatingActionButton.small(
                                      tooltip: 'Actualizar',
                                      onPressed: _loadData,
                                      elevation: 2,
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                      child: const Icon(Icons.refresh),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Brief description - REMOVED
                          // Padding(
                          //   padding: const EdgeInsets.symmetric(
                          //       horizontal: 16.0, vertical: 8.0),
                          //   child: Text(
                          //     'Visualización de la actividad en cada zona de la tienda en tiempo real',
                          //     style: theme.textTheme.bodyMedium,
                          //   ),
                          // ),

                          // Tier list visualization
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildTierList(isDarkMode),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildTierList(bool isDarkMode) {
    if (_heatmapData.isEmpty || _storeLayout == null) {
      return Center(
        child: Text(
          'No hay datos de tráfico disponibles',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    // Group zones by tier based on activity level
    final Map<String, List<ZoneDefinition>> tierGroups = {
      'S': [], // Super high activity
      'A': [], // High activity
      'B': [], // Medium-high activity
      'C': [], // Medium activity
      'D': [], // Low activity
    };

    // Filter out entrance zone
    final filteredZones =
        _storeLayout!.zones.where((zone) => zone.id != 'entrance').toList();

    // Categorize zones into tiers based on count
    for (var zone in filteredZones) {
      // Find corresponding heatmap data and value to use for tierization
      int valueToUse = 0;

      // Debug para cada zona
      print('Evaluando zona: ID=${zone.id}, nombre=${zone.name}');

      try {
        // Check if this zone is the main category
        if (zone.id == 'principal') {
          HeatmapLocation zoneData = _heatmapData.firstWhere(
            (data) => data.sensorId == zone.id,
          );
          valueToUse = zoneData.avgPrincipal.round();
          print(
              'Categoría Principal (${zone.name}) - Count Value: $valueToUse');
        }
        // Check if this zone is the medium distance category AND mainCategoryData is available
        else if (zone.id == 'medium') {
          valueToUse = _heatmapData
              .firstWhere((data) => data.sensorId == 'principal')
              .avgMedium
              .round();
          print(
              'Categoría Media (${zone.name}) - Medium Value (from Principal): $valueToUse');
        }
        // Check if this zone is the far distance category AND mainCategoryData is available
        else if (zone.id == 'far') {
          valueToUse = _heatmapData
              .firstWhere((data) => data.sensorId == 'principal')
              .avgFar
              .round();
          print(
              'Categoría Lejana (${zone.name}) - Far Value (from Principal): $valueToUse');
        } else {
          // Para otras categorías, usar su count normal si existe
          HeatmapLocation? zoneData = _heatmapData.firstWhere(
            (data) => data.sensorId == zone.id,
            orElse: () => HeatmapLocation(
              sensorId: zone.id,
              avgPrincipal: 0,
              avgMedium: 0,
              avgFar: 0,
              maxPrincipal: 0,
              totalReadings: 0,
              lastUpdate: DateTime.now(),
            ),
          );
          valueToUse = zoneData.avgPrincipal.round();
        }
      } catch (e) {
        print('Error al obtener valor para zona ${zone.id}: $e');
        // Si hay un error, asignamos 0
        valueToUse = 0;
      }

      print('Valor final para clasificar: $valueToUse');

      // Assign to tier based on assigned value
      if (valueToUse >= _highThreshold) {
        tierGroups['S']!.add(zone);
      } else if (valueToUse >= (_highThreshold + _mediumThreshold) ~/ 2) {
        tierGroups['A']!.add(zone);
      } else if (valueToUse >= _mediumThreshold) {
        tierGroups['B']!.add(zone);
      } else if (valueToUse >= _lowThreshold) {
        tierGroups['C']!.add(zone);
      } else {
        tierGroups['D']!.add(zone);
      }
    }

    return ListView(
      children: [
        // S Tier (Red)
        _buildTierRow('S', tierGroups['S']!, Colors.red.shade400, isDarkMode),

        // A Tier (Orange)
        _buildTierRow(
            'A', tierGroups['A']!, Colors.orange.shade300, isDarkMode),

        // B Tier (Yellow)
        _buildTierRow('B', tierGroups['B']!, Colors.amber.shade300, isDarkMode),

        // C Tier (Green)
        _buildTierRow('C', tierGroups['C']!, Colors.green.shade300, isDarkMode),

        // D Tier (Blue)
        _buildTierRow('D', tierGroups['D']!, Colors.blue.shade200, isDarkMode),
      ],
    );
  }

  Widget _buildTierRow(
      String tier, List<ZoneDefinition> zones, Color color, bool isDarkMode) {
    // Show the row even if empty to maintain the tier list structure
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier label
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                tier,
                style: TextStyle(
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Zone cards
          Expanded(
            child: zones.isEmpty
                ? Container(
                    height: 50,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No hay categorías en este nivel',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: zones.length,
                      itemBuilder: (context, index) =>
                          _buildZoneCard(zones[index], color, isDarkMode),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(
      ZoneDefinition zone, Color backgroundColor, bool isDarkMode) {
    // Determinar qué valor mostrar basado en qué categoría de distancia es
    int valueToShow = 0;
    String labelText = '';

    // Print para debug
    print(
        'Zona actual: ID=${zone.id}, nombre=${zone.name}, tipoProducto=${zone.tipoProducto}');

    // Find main category data and details first
    HeatmapLocation? mainHeatmapDataForDistances;
    StoreCategory? mainCategoryDetails;
    StoreCategory? mediumCategoryDetails;
    StoreCategory? farCategoryDetails;

    if (zone.id == 'principal') {
      try {
        mainCategoryDetails =
            _categories.firstWhere((cat) => cat.id == 'principal');
        mainHeatmapDataForDistances = _heatmapData.firstWhere(
            (data) =>
                data.sensorId == mainCategoryDetails!.tipoProducto.toString(),
            orElse: () => HeatmapLocation(
                sensorId: mainCategoryDetails!.tipoProducto.toString(),
                avgPrincipal: 0,
                avgMedium: 0,
                avgFar: 0,
                maxPrincipal: 0,
                totalReadings: 0,
                lastUpdate: DateTime.now()));
        print(
            'Datos de heatmap de categoría principal para distancias: count=${mainHeatmapDataForDistances.avgPrincipal}, medium=${mainHeatmapDataForDistances.avgMedium}, far=${mainHeatmapDataForDistances.avgFar}');
      } catch (e) {
        print('Error buscando categoría principal o sus datos de heatmap: $e');
      }
    }
    if (zone.id == 'medium') {
      try {
        mediumCategoryDetails =
            _categories.firstWhere((cat) => cat.id == 'medium');
      } catch (e) {
        print('Error buscando detalles de categoría media: $e');
      }
    }
    if (zone.id == 'far') {
      try {
        farCategoryDetails = _categories.firstWhere((cat) => cat.id == 'far');
      } catch (e) {
        print('Error buscando detalles de categoría lejana: $e');
      }
    }

    // Comparamos usando zona.id que es el tipoProducto como string
    // Check if current zone is the main category
    if (mainCategoryDetails != null &&
        zone.id == mainCategoryDetails.tipoProducto.toString()) {
      final zoneData = _heatmapData.firstWhere(
        (element) => element.sensorId == zone.id,
        orElse: () => HeatmapLocation(
            sensorId: zone.id,
            avgPrincipal: 0,
            avgMedium: 0,
            avgFar: 0,
            maxPrincipal: 0,
            totalReadings: 0,
            lastUpdate: DateTime.now()),
      );
      valueToShow = zoneData.avgPrincipal.round();
      labelText = 'Principal';
      print('Categoría Principal (${zone.name}) - Valor: $valueToShow');
    }
    // Check if current zone is the medium distance category and main heatmap data is available
    else if (mediumCategoryDetails != null &&
        zone.id == mediumCategoryDetails.tipoProducto.toString() &&
        mainHeatmapDataForDistances != null) {
      valueToShow = mainHeatmapDataForDistances.avgMedium.round();
      labelText = 'Distancia Media';
      print(
          'Categoría Media (${zone.name}) - Valor (de ${mainCategoryDetails?.name}): $valueToShow');
    }
    // Check if current zone is the far distance category and main heatmap data is available
    else if (farCategoryDetails != null &&
        zone.id == farCategoryDetails.tipoProducto.toString() &&
        mainHeatmapDataForDistances != null) {
      valueToShow = mainHeatmapDataForDistances.avgFar.round();
      labelText = 'Distancia Lejana';
      print(
          'Categoría Lejana (${zone.name}) - Valor (de ${mainCategoryDetails?.name}): $valueToShow');
    } else {
      // Otra categoría no asignada
      final zoneData = _heatmapData.firstWhere(
        (element) => element.sensorId == zone.id,
        orElse: () => HeatmapLocation(
          sensorId: zone.id,
          avgPrincipal: 0,
          avgMedium: 0,
          avgFar: 0,
          maxPrincipal: 0,
          totalReadings: 0,
          lastUpdate: DateTime.now(),
        ),
      );
      valueToShow = zoneData.avgPrincipal.round();
    }

    final isHovered = _hoveredZoneId == zone.id;
    final textColor = backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredZoneId = zone.id),
      onExit: (_) => setState(() => _hoveredZoneId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: 220,
        transform: isHovered
            ? Matrix4.translationValues(0, -5, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          color: backgroundColor,
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
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Category icon
                  Icon(
                    IconDataHelper.getIconByName(zone.icon),
                    color: textColor.withOpacity(0.8),
                    size: 24,
                  ),
                ],
              ),
              const Spacer(),
              // Display count based on category type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Label if available
                  if (labelText.isNotEmpty)
                    Text(
                      labelText,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  // Value always shown
                  Text(
                    '$valueToShow personas',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
