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

  // Distance category settings
  String? _mainCategoryId;
  String? _mediumCategoryId;
  String? _farCategoryId;

  @override
  void initState() {
    super.initState();
    // The controller will be initialized in didChangeDependencies
    _loadThresholds();
    _loadCategorySettings();
  }

  Future<void> _loadThresholds() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowThreshold = prefs.getInt('heatmap_low_threshold') ?? 5;
      _mediumThreshold = prefs.getInt('heatmap_medium_threshold') ?? 10;
      _highThreshold = prefs.getInt('heatmap_high_threshold') ?? 15;
    });
  }

  Future<void> _loadCategorySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainCategoryId = prefs.getString('heatmap_main_category');
      _mediumCategoryId = prefs.getString('heatmap_medium_category');
      _farCategoryId = prefs.getString('heatmap_far_category');
    });
  }

  Future<void> _saveThresholds() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('heatmap_low_threshold', _lowThreshold);
    await prefs.setInt('heatmap_medium_threshold', _mediumThreshold);
    await prefs.setInt('heatmap_high_threshold', _highThreshold);
  }

  Future<void> _saveCategorySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Limpiar configuraciones anteriores
    await prefs.remove('heatmap_main_category');
    await prefs.remove('heatmap_medium_category');
    await prefs.remove('heatmap_far_category');

    // Guardar nuevas configuraciones
    if (_mainCategoryId != null) {
      await prefs.setString('heatmap_main_category', _mainCategoryId!);
      print('Guardado categoría principal: $_mainCategoryId');
    }
    if (_mediumCategoryId != null) {
      await prefs.setString('heatmap_medium_category', _mediumCategoryId!);
      print('Guardado categoría media: $_mediumCategoryId');
    }
    if (_farCategoryId != null) {
      await prefs.setString('heatmap_far_category', _farCategoryId!);
      print('Guardado categoría lejana: $_farCategoryId');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the controller once the context is available
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

      // Debug log para encontrar el problema con medium y far
      if (_mainCategoryId != null) {
        for (var data in _heatmapData) {
          if (data.locationId == _mainCategoryId) {
            print('MAIN CATEGORY DATA:');
            print('Location ID: ${data.locationId}');
            print('Count: ${data.avgCount}');
            print('Medium: ${data.avgMedium}');
            print('Far: ${data.avgFar}');
            break;
          }
        }
      }
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
    String? tempMainCategory = _mainCategoryId;
    String? tempMediumCategory = _mediumCategoryId;
    String? tempFarCategory = _farCategoryId;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          // Función local para manejar cambios en las categorías
          void handleCategoryChange(String type, String? value) {
            setState(() {
              // Actualizar el valor seleccionado
              if (type == 'Principal') {
                // Si cambia la categoría principal
                tempMainCategory = value;

                // Si la nueva categoría principal era antes media o lejana, resetearlas
                if (tempMediumCategory == value) {
                  tempMediumCategory = null;
                }
                if (tempFarCategory == value) {
                  tempFarCategory = null;
                }
              } else if (type == 'Distancia Media') {
                // Si cambia la categoría media
                tempMediumCategory = value;

                // Si la nueva categoría media era antes lejana, resetearla
                if (tempFarCategory == value) {
                  tempFarCategory = null;
                }
              } else if (type == 'Distancia Lejana') {
                // Si cambia la categoría lejana
                tempFarCategory = value;
              }
            });
          }

          return DefaultTabController(
            length: 2,
            child: AlertDialog(
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
                    TabBar(
                      indicatorColor: Theme.of(context)
                          .colorScheme
                          .primary, // Blue indicator
                      labelColor: Theme.of(context)
                          .colorScheme
                          .primary, // Blue label for selected tab
                      unselectedLabelColor: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color, // Default text color for unselected
                      tabs: const [
                        Tab(text: 'Umbrales'),
                        Tab(text: 'Categorías por Distancia'),
                      ],
                    ),
                    SizedBox(
                      height: 300, // Set a fixed height for content
                      child: TabBarView(
                        children: [
                          // Tab 1: Threshold settings
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Umbral Bajo',
                                      hintText: 'Ingrese cantidad de personas',
                                      isDense: false,
                                      border: OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    controller: TextEditingController(
                                        text: tempLow.toString()),
                                    onChanged: (value) {
                                      tempLow = int.tryParse(value) ?? tempLow;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Medio Threshold
                                  const Text('Medio:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Umbral Medio',
                                      hintText: 'Ingrese cantidad de personas',
                                      isDense: false,
                                      border: OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    controller: TextEditingController(
                                        text: tempMedium.toString()),
                                    onChanged: (value) {
                                      tempMedium =
                                          int.tryParse(value) ?? tempMedium;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Alto Threshold
                                  const Text('Alto:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Umbral Alto',
                                      hintText: 'Ingrese cantidad de personas',
                                      isDense: false,
                                      border: OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    controller: TextEditingController(
                                        text: tempHigh.toString()),
                                    onChanged: (value) {
                                      tempHigh =
                                          int.tryParse(value) ?? tempHigh;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Tab 2: Category distance settings
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Configure las categorías para cada distancia:',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),

                                  // Main category dropdown
                                  const Text(
                                    'Categoría Principal:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: tempMainCategory,
                                        isExpanded: true,
                                        isDense: true,
                                        hint: const Text(
                                            'Seleccionar Categoría Principal'),
                                        items: _categories.map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category.id,
                                            child: Text(category.name),
                                          );
                                        }).toList(),
                                        onChanged: (value) =>
                                            handleCategoryChange(
                                                'Principal', value),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Medium distance category dropdown
                                  const Text(
                                    'Categoría a Distancia Media:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: tempMediumCategory,
                                        isExpanded: true,
                                        isDense: true,
                                        hint: const Text(
                                            'Seleccionar Categoría Media'),
                                        items: _categories
                                            .where((category) =>
                                                category.id != tempMainCategory)
                                            .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category.id,
                                            child: Text(category.name),
                                          );
                                        }).toList(),
                                        onChanged: (value) =>
                                            handleCategoryChange(
                                                'Distancia Media', value),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Far distance category dropdown
                                  const Text(
                                    'Categoría a Distancia Lejana:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: tempFarCategory,
                                        isExpanded: true,
                                        isDense: true,
                                        hint: const Text(
                                            'Seleccionar Categoría Lejana'),
                                        items: _categories
                                            .where((category) =>
                                                category.id !=
                                                    tempMainCategory &&
                                                category.id !=
                                                    tempMediumCategory)
                                            .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category.id,
                                            child: Text(category.name),
                                          );
                                        }).toList(),
                                        onChanged: (value) =>
                                            handleCategoryChange(
                                                'Distancia Lejana', value),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                    if (!(tempLow < tempMedium && tempMedium < tempHigh)) {
                      isValid = false;
                      errorMessage =
                          'Los valores deben ser ascendentes: Bajo < Medio < Alto';
                    }

                    if (isValid) {
                      // Update thresholds
                      this.setState(() {
                        _lowThreshold = tempLow;
                        _mediumThreshold = tempMedium;
                        _highThreshold = tempHigh;
                        _mainCategoryId = tempMainCategory;
                        _mediumCategoryId = tempMediumCategory;
                        _farCategoryId = tempFarCategory;
                      });

                      // Save all settings
                      _saveThresholds();
                      _saveCategorySettings();

                      // Cerrar el diálogo
                      Navigator.of(context).pop();

                      // Recargar datos para aplicar los cambios inmediatamente
                      _loadData();
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
            ),
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

    // Find main category data
    HeatmapLocation? mainCategoryData;
    StoreCategory? mainCategoryDetails;
    StoreCategory? mediumCategoryDetails;
    StoreCategory? farCategoryDetails;

    if (_mainCategoryId != null) {
      try {
        mainCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _mainCategoryId);
        mainCategoryData = _heatmapData.firstWhere(
          (data) =>
              data.locationId == mainCategoryDetails!.tipoProducto.toString(),
        );
        print('Datos de categoría principal encontrados: $mainCategoryData');
        print(
            'Medium value: ${mainCategoryData.avgMedium}, Far value: ${mainCategoryData.avgFar}');
      } catch (e) {
        print(
            'No se encontraron datos para la categoría principal o la categoría en sí: $e');
      }
    }
    if (_mediumCategoryId != null) {
      try {
        mediumCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _mediumCategoryId);
      } catch (e) {
        print('No se encontró la categoría media seleccionada: $e');
      }
    }
    if (_farCategoryId != null) {
      try {
        farCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _farCategoryId);
      } catch (e) {
        print('No se encontró la categoría lejana seleccionada: $e');
      }
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
        if (mainCategoryDetails != null &&
            zone.id == mainCategoryDetails.tipoProducto.toString()) {
          HeatmapLocation zoneData = _heatmapData.firstWhere(
            (data) => data.locationId == zone.id,
          );
          valueToUse = zoneData.avgCount.round();
          print(
              'Categoría Principal (${zone.name}) - Count Value: $valueToUse');
        }
        // Check if this zone is the medium distance category AND mainCategoryData is available
        else if (mediumCategoryDetails != null &&
            zone.id == mediumCategoryDetails.tipoProducto.toString() &&
            mainCategoryData != null) {
          valueToUse = mainCategoryData.avgMedium.round();
          print(
              'Categoría Media (${zone.name}) - Medium Value (from ${mainCategoryDetails?.name}): $valueToUse');
        }
        // Check if this zone is the far distance category AND mainCategoryData is available
        else if (farCategoryDetails != null &&
            zone.id == farCategoryDetails.tipoProducto.toString() &&
            mainCategoryData != null) {
          valueToUse = mainCategoryData.avgFar.round();
          print(
              'Categoría Lejana (${zone.name}) - Far Value (from ${mainCategoryDetails?.name}): $valueToUse');
        } else {
          // Para otras categorías, usar su count normal si existe
          HeatmapLocation? zoneData = _heatmapData.firstWhere(
            (data) => data.locationId == zone.id,
            orElse: () => HeatmapLocation(
              locationId: zone.id,
              avgCount: 0,
              avgMedium: 0,
              avgFar: 0,
              maxCount: 0,
              totalReadings: 0,
              lastUpdate: DateTime.now(),
            ),
          );
          valueToUse = zoneData.avgCount.round();
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
    print(
        'ID Categoría Principal: $_mainCategoryId, Media: $_mediumCategoryId, Lejana: $_farCategoryId');

    // Find main category data and details first
    HeatmapLocation? mainHeatmapDataForDistances;
    StoreCategory? mainCategoryDetails;
    StoreCategory? mediumCategoryDetails;
    StoreCategory? farCategoryDetails;

    if (_mainCategoryId != null) {
      try {
        mainCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _mainCategoryId);
        mainHeatmapDataForDistances = _heatmapData.firstWhere(
            (data) =>
                data.locationId == mainCategoryDetails!.tipoProducto.toString(),
            orElse: () => HeatmapLocation(
                locationId: mainCategoryDetails!.tipoProducto.toString(),
                avgCount: 0,
                avgMedium: 0,
                avgFar: 0,
                maxCount: 0,
                totalReadings: 0,
                lastUpdate: DateTime.now()));
        print(
            'Datos de heatmap de categoría principal para distancias: count=${mainHeatmapDataForDistances.avgCount}, medium=${mainHeatmapDataForDistances.avgMedium}, far=${mainHeatmapDataForDistances.avgFar}');
      } catch (e) {
        print('Error buscando categoría principal o sus datos de heatmap: $e');
      }
    }
    if (_mediumCategoryId != null) {
      try {
        mediumCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _mediumCategoryId);
      } catch (e) {
        print('Error buscando detalles de categoría media: $e');
      }
    }
    if (_farCategoryId != null) {
      try {
        farCategoryDetails =
            _categories.firstWhere((cat) => cat.id == _farCategoryId);
      } catch (e) {
        print('Error buscando detalles de categoría lejana: $e');
      }
    }

    // Comparamos usando zona.id que es el tipoProducto como string
    // Check if current zone is the main category
    if (mainCategoryDetails != null &&
        zone.id == mainCategoryDetails.tipoProducto.toString()) {
      final zoneData = _heatmapData.firstWhere(
        (element) => element.locationId == zone.id,
        orElse: () => HeatmapLocation(
            locationId: zone.id,
            avgCount: 0,
            avgMedium: 0,
            avgFar: 0,
            maxCount: 0,
            totalReadings: 0,
            lastUpdate: DateTime.now()),
      );
      valueToShow = zoneData.avgCount.round();
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
        (element) => element.locationId == zone.id,
        orElse: () => HeatmapLocation(
          locationId: zone.id,
          avgCount: 0,
          avgMedium: 0,
          avgFar: 0,
          maxCount: 0,
          totalReadings: 0,
          lastUpdate: DateTime.now(),
        ),
      );
      valueToShow = zoneData.avgCount.round();
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
