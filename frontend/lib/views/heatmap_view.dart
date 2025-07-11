import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/heatmap_controller.dart';
import '../models/heatmap_data.dart';
import '../widgets/heatmap_legend.dart';
import '../controllers/categories_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/widgets/toast_notification.dart';

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

  // Current sensor configuration
  Map<String, List<int>> _sensorConfig = {
    'medium': [],
    'far': [],
  };

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

      // 2. Get sensor configuration
      final sensorConfig = await _controller.getSensorsConfiguration();

      // 3. Then load heatmap data
      final heatmapData = await _controller.getAggregatedHeatmapData();

      // Find max activity for scaling
      double maxVal = 0;
      for (var location in heatmapData) {
        if (location.avgPrincipal > maxVal) {
          maxVal = location.avgPrincipal;
        }
      }

      // 4. Generate store layout from categories
      final storeLayout = StoreLayout.fromCategories(categories);

      setState(() {
        _categories = categories;
        _heatmapData = heatmapData;
        _storeLayout = storeLayout;
        _maxActivity = maxVal > 0 ? maxVal : 1; // Avoid division by zero
        _isLoading = false;
        _sensorConfig = sensorConfig;
      });

      // Debug logs
      print('Loaded ${_categories.length} categories');
      print('Loaded ${_heatmapData.length} heatmap data points');
      print('Max activity value: $_maxActivity');
      print('Medium categories: ${_sensorConfig["medium"]}');
      print('Far categories: ${_sensorConfig["far"]}');
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
                const Text('Configuración del Monitor de Afluencia'),
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(0xFF0D2B4E).withOpacity(
                                      0.3) // Dark blue background for dark mode
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(
                                          0xFF64B5F6) // Light blue for dark mode
                                      : Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color(
                                                0xFF81D4FA) // Light blue for dark mode
                                            : Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reglas de configuración',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color(
                                                0xFF81D4FA) // Light blue for dark mode
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Los umbrales deben seguir la regla: Bajo ≤ Medio ≤ Alto',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors
                                              .white // White text for dark mode
                                          : Colors.black87),
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
                      ToastService.showSuccess(
                        context,
                        'Configuración actualizada con éxito',
                      );

                      // Reload data to apply changes
                      _loadData();
                    }).catchError((error) {
                      // Show error on failure but keep dialog open
                      ToastService.showError(
                        context,
                        'Error al actualizar: $error',
                      );
                    });
                  } else {
                    // Show error message
                    ToastService.showError(
                      context,
                      errorMessage,
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
                                  'Monitor de Afluencia',
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

    // Check if we have any active sensors first
    bool hasSensors = _sensorConfig['principal']!.isNotEmpty ||
        _sensorConfig['medium']!.isNotEmpty ||
        _sensorConfig['far']!.isNotEmpty;

    if (!hasSensors) {
      return Center(
        child: Text(
          'No hay sensores configurados',
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

    // Debug: Log all available heatmap data to check sensor IDs and categories
    print('Available heatmap data:');
    for (var data in _heatmapData) {
      print(
          'SensorID: ${data.sensorId}, Principal: ${data.avgPrincipal}, Medium: ${data.avgMedium}, Far: ${data.avgFar}');
    }

    // Debug: Log all categories in the storeLayout
    print('Available zones in store layout:');
    for (var zone in filteredZones) {
      print(
          'Zone ID: ${zone.id}, Name: ${zone.name}, tipoProducto: ${zone.tipoProducto}');
    }

    // Categorize zones into tiers based on count
    for (var zone in filteredZones) {
      // Find corresponding heatmap data and value to use for tierization
      int valueToUse = 0;

      // Debug para cada zona
      print(
          'Evaluando zona: ID=${zone.id}, nombre=${zone.name}, tipoProducto=${zone.tipoProducto}');

      try {
        // Check if this zone should be displayed
        bool isPrincipalCategory =
            _sensorConfig['principal']!.contains(zone.tipoProducto);
        bool isMediumCategory =
            _sensorConfig['medium']!.contains(zone.tipoProducto);
        bool isFarCategory = _sensorConfig['far']!.contains(zone.tipoProducto);
        bool shouldDisplayZone =
            isPrincipalCategory || isMediumCategory || isFarCategory;

        print(
            'Zone ${zone.name} is principal: $isPrincipalCategory, medium: $isMediumCategory, far: $isFarCategory, should display: $shouldDisplayZone');

        // Skip categories not associated with any sensor
        if (!shouldDisplayZone) {
          print('Skipping zone ${zone.name} - not associated with any sensor');
          continue;
        }

        // Find sensor data for this zone's category
        final sensorDataList = _heatmapData
            .where((data) =>
                data.sensorId == zone.tipoProducto.toString() ||
                // If the category is not found directly as a sensor ID, it might be a principal, medium, or far category
                (isPrincipalCategory || isMediumCategory || isFarCategory))
            .toList();

        if (sensorDataList.isNotEmpty) {
          // This zone has direct sensor data or is configured in a sensor
          HeatmapLocation? zoneData;

          // Try to find direct data by tipoProducto
          zoneData = sensorDataList.firstWhere(
            (data) => data.sensorId == zone.tipoProducto.toString(),
            orElse: () => HeatmapLocation(
              sensorId: zone.tipoProducto.toString(),
              avgPrincipal: 0,
              avgMedium: 0,
              avgFar: 0,
              maxPrincipal: 0,
              totalReadings: 0,
              lastUpdate: DateTime.now(),
            ),
          );

          // If no direct data but it's a category in use, use the first available data
          if (zoneData.totalReadings == 0 && sensorDataList.isNotEmpty) {
            zoneData = sensorDataList.first;
          }

          if (isMediumCategory) {
            // This zone is configured as a medium-distance category in some sensor
            valueToUse = zoneData.avgMedium.round();
            print('Tier Categoría Media (${zone.name}) - Valor: $valueToUse');
          } else if (isFarCategory) {
            // This zone is configured as a far-distance category in some sensor
            valueToUse = zoneData.avgFar.round();
            print('Tier Categoría Lejana (${zone.name}) - Valor: $valueToUse');
          } else if (isPrincipalCategory) {
            // This zone is a principal category
            valueToUse = zoneData.avgPrincipal.round();
            print(
                'Tier Categoría Principal (${zone.name}) - Valor: $valueToUse');
          } else {
            // Fallback for any other case
            valueToUse = zoneData.avgPrincipal.round();
            print(
                'Tier Categoría Fallback (${zone.name}) - Valor: $valueToUse');
          }
        } else {
          print('No sensor data found for zone ${zone.name}');
          // We'll still include the zone as it's associated with a sensor
          // but we'll give it a value of 0
          valueToUse = 0;
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

    try {
      // Check if this zone should be displayed
      bool isPrincipalCategory =
          _sensorConfig['principal']!.contains(zone.tipoProducto);
      bool isMediumCategory =
          _sensorConfig['medium']!.contains(zone.tipoProducto);
      bool isFarCategory = _sensorConfig['far']!.contains(zone.tipoProducto);
      bool shouldDisplayZone =
          isPrincipalCategory || isMediumCategory || isFarCategory;

      print(
          'Zone ${zone.name} is principal: $isPrincipalCategory, medium: $isMediumCategory, far: $isFarCategory, should display: $shouldDisplayZone');

      // If category is not associated with any sensor, we shouldn't be here
      // But as an extra validation, check again
      if (!shouldDisplayZone) {
        print(
            'Warning: Zone ${zone.name} should not be displayed but was passed to _buildZoneCard');
        valueToShow = 0;
        labelText = 'No asociada';
      } else {
        // Find sensor data for this zone's category
        final sensorDataList = _heatmapData
            .where((data) =>
                data.sensorId == zone.tipoProducto.toString() ||
                // If the category is not found directly as a sensor ID, it might be a principal, medium, or far category
                (isPrincipalCategory || isMediumCategory || isFarCategory))
            .toList();

        if (sensorDataList.isNotEmpty) {
          // This zone has direct sensor data or is configured in a sensor
          HeatmapLocation? zoneData;

          // Try to find direct data by tipoProducto
          zoneData = sensorDataList.firstWhere(
            (data) => data.sensorId == zone.tipoProducto.toString(),
            orElse: () => HeatmapLocation(
              sensorId: zone.tipoProducto.toString(),
              avgPrincipal: 0,
              avgMedium: 0,
              avgFar: 0,
              maxPrincipal: 0,
              totalReadings: 0,
              lastUpdate: DateTime.now(),
            ),
          );

          // If no direct data but it's a category in use, use the first available data
          if (zoneData.totalReadings == 0 && sensorDataList.isNotEmpty) {
            zoneData = sensorDataList.first;
          }

          if (isMediumCategory) {
            // This zone is configured as a medium-distance category in some sensor
            valueToShow = zoneData.avgMedium.round();
            labelText = 'Distancia Media';
            print(
                'Categoría configurada como Media (${zone.name}) - Valor: $valueToShow');
          } else if (isFarCategory) {
            // This zone is configured as a far-distance category in some sensor
            valueToShow = zoneData.avgFar.round();
            labelText = 'Distancia Lejana';
            print(
                'Categoría configurada como Lejana (${zone.name}) - Valor: $valueToShow');
          } else if (isPrincipalCategory) {
            // This zone is a principal category
            valueToShow = zoneData.avgPrincipal.round();
            labelText = 'Principal';
            print(
                'Categoría Principal (${zone.name}) - Valor Principal: $valueToShow');
          } else {
            // Fallback for other cases
            valueToShow = zoneData.avgPrincipal.round();
            print('Categoría (${zone.name}) - Fallback valor: $valueToShow');
          }
        } else {
          print('No sensor data found for zone ${zone.name}');
          labelText = 'Sin datos';
        }
      }
    } catch (e) {
      print('Error procesando zona ${zone.name}: $e');
      valueToShow = 0;
      labelText = 'Error';
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
