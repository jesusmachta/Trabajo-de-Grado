import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/toast_notification.dart';
import '../controllers/sensors_controller.dart';
import 'categories_view.dart'; // Import the categories view directly

// Define the base URL for the API
const String _apiBaseUrl = 'http://127.0.0.1:8000/api';

// Add enum for sensor status filter
enum SensorStatusFilter { todos, activo, inactivo }

class SensorsView extends StatefulWidget {
  final Function toggleTheme;

  const SensorsView({super.key, required this.toggleTheme});

  @override
  State<SensorsView> createState() => _SensorsViewState();
}

class _SensorsViewState extends State<SensorsView> {
  final SensorsController _controller = SensorsController();
  List<Map<String, dynamic>> _sensors = [];
  List<Map<String, dynamic>> _filteredSensors = [];
  List<Map<String, dynamic>> _availableCategories = [];
  bool _isLoadingSensors = true;
  bool _isLoadingCategories = true;
  String? _sensorsError;
  String? _categoriesError;
  SensorStatusFilter _selectedStatus = SensorStatusFilter.todos;
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchSensors();
    _fetchAvailableCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSensors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSensors = true;
      _sensorsError = null;
    });

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to get sensors
      final sensors = await _controller.getSensors(token);

      if (!mounted) return;

      setState(() {
        _sensors = sensors
          ..sort((a, b) =>
              (a['id_sensor'] as int).compareTo(b['id_sensor'] as int));
        _isLoadingSensors = false;
        _filterSensors(); // Apply filters after loading data
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sensorsError = 'Error al cargar sensores: $e';
        _isLoadingSensors = false;
      });
    }
  }

  // Function to load available categories
  Future<void> _fetchAvailableCategories({String? sensorId}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to get available categories
      final availableCategories =
          await _controller.getAvailableCategories(token, sensorId);

      if (!mounted) return;

      setState(() {
        _availableCategories = availableCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = 'Error: $e';
        _isLoadingCategories = false;
      });
    }
  }

  // Filter sensors based on search and status filter
  void _filterSensors() {
    setState(() {
      // First filter by status
      List<Map<String, dynamic>> statusFiltered;
      if (_selectedStatus == SensorStatusFilter.todos) {
        statusFiltered = List.from(_sensors);
      } else {
        bool isActiveFilter = _selectedStatus == SensorStatusFilter.activo;
        statusFiltered = _sensors.where((sensor) {
          final isActive = sensor['isActive'] as bool? ?? false;
          return isActive == isActiveFilter;
        }).toList();
      }

      // Then apply search filter if search term is not empty
      if (_searchTerm.trim().isEmpty) {
        _filteredSensors = statusFiltered;
      } else {
        final searchLower = _searchTerm.toLowerCase().trim();
        _filteredSensors = statusFiltered.where((sensor) {
          // Check if sensor ID contains search term
          final idContains = sensor['id_sensor']
              .toString()
              .toLowerCase()
              .contains(searchLower);

          // Check categories
          final principalCategoryContains =
              sensor['principal_category_name'] != null &&
                  sensor['principal_category_name']
                      .toString()
                      .toLowerCase()
                      .contains(searchLower);

          final mediumCategoryContains =
              sensor['medium_category_name'] != null &&
                  sensor['medium_category_name']
                      .toString()
                      .toLowerCase()
                      .contains(searchLower);

          final farCategoryContains = sensor['far_category_name'] != null &&
              sensor['far_category_name']
                  .toString()
                  .toLowerCase()
                  .contains(searchLower);

          return idContains ||
              principalCategoryContains ||
              mediumCategoryContains ||
              farCategoryContains;
        }).toList();
      }
      _currentPage = 0; // Reset page when filtering
    });
  }

  // --- CRUD Operations ---

  Future<void> _addSensor(
      int idSensor, int tipoPrincipal, int? tipoMedium, int? tipoFar) async {
    if (!mounted) return;
    final currentContext = context;

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to add the sensor
      await _controller.addSensor(
          idSensor, tipoPrincipal, tipoMedium, tipoFar, token);

      await _fetchSensors(); // Reload the list of sensors
      Navigator.of(currentContext).pop();
      ToastService.showSuccess(currentContext, 'Sensor añadido con éxito.');
    } catch (e) {
      if (mounted) {
        if (Navigator.of(currentContext).canPop()) {
          Navigator.of(currentContext).pop();
        }
        ToastService.showError(currentContext, 'Error al añadir sensor: $e');
      }
    }
  }

  Future<void> _toggleSensorStatus(String mongoId, bool newStatus) async {
    if (!mounted) return;
    final currentContext = context;

    // Find the sensor in the list and update its status optimistically
    final index = _sensors.indexWhere((sensor) => sensor['_id'] == mongoId);
    if (index != -1) {
      setState(() {
        _sensors[index]['isActive'] = newStatus;
        _filterSensors(); // Apply filters after updating the status
      });
    }

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to update the status
      await _controller.toggleSensorStatus(mongoId, newStatus, token);

      if (!mounted) return;

      // Success - already optimistically updated
      ToastService.showSuccess(currentContext,
          'Estado del sensor actualizado a ${newStatus ? 'activo' : 'inactivo'}');
    } catch (e) {
      // Revert the optimistic change if the request fails
      if (index != -1 && mounted) {
        setState(() {
          _sensors[index]['isActive'] = !newStatus;
          _filterSensors(); // Apply filters after reverting the status
        });
      }
      if (mounted) {
        ToastService.showError(
            currentContext, 'Error al actualizar estado: $e');
      }
    }
  }

  Future<void> _deleteSensor(String mongoId) async {
    if (!mounted) return;
    final currentContext = context;

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to delete the sensor
      await _controller.deleteSensor(mongoId, token);

      if (!mounted) return;

      await _fetchSensors(); // Reload the list of sensors
      ToastService.showSuccess(currentContext, 'Sensor eliminado con éxito.');
    } catch (e) {
      if (mounted) {
        ToastService.showError(currentContext, 'Error al eliminar sensor: $e');
      }
    }
  }

  Future<void> _updateSensor(String mongoId, int idSensor, int tipoPrincipal,
      int? tipoMedium, int? tipoFar) async {
    if (!mounted) return;
    final currentContext = context;

    try {
      // Get the JWT token from the AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Use the controller to edit the sensor
      await _controller.editSensor(
          mongoId, idSensor, tipoPrincipal, tipoMedium, tipoFar, token);

      if (!mounted) return;

      await _fetchSensors(); // Reload the list of sensors
      Navigator.of(currentContext).pop();
      ToastService.showSuccess(currentContext, 'Sensor actualizado con éxito.');
    } catch (e) {
      if (mounted) {
        if (Navigator.of(currentContext).canPop()) {
          Navigator.of(currentContext).pop();
        }
        ToastService.showError(
            currentContext, 'Error al actualizar sensor: $e');
      }
    }
  }

  // --- Dialogs ---

  void _showAddSensorDialog() {
    if (_isLoadingCategories) {
      // Wait for categories to load before showing the dialog
      ToastService.showInfo(
          context, 'Cargando categorías, por favor espere...');
      _fetchAvailableCategories().then((_) {
        if (mounted) {
          // Show the dialog only when loading is complete
          _showAddSensorDialogContent();
        }
      });
    } else {
      // Categories already loaded, show the dialog
      _showAddSensorDialogContent();
    }
  }

  void _showAddSensorDialogContent() {
    final formKey = GlobalKey<FormState>();
    final idSensorController = TextEditingController();
    int? selectedPrincipalType;
    int? selectedMediumType;
    int? selectedFarType;

    final List<int> existingSensorIds =
        _sensors.map((sensor) => sensor['id_sensor'] as int).toList();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing when clicking outside
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Build the dropdown items for principal category
            List<DropdownMenuItem<int>> buildPrincipalItems() {
              final items = <DropdownMenuItem<int>>[];

              // Only show active categories
              final activeCategories = _availableCategories
                  .where((category) => category['isActive'] == true)
                  .toList();

              for (var category in activeCategories) {
                final id = category['Tipo_Producto'] as int? ??
                    int.tryParse(category['Tipo_Producto'].toString()) ??
                    0;
                final name = category['Categoria_Producto'] as String? ??
                    category['Nombre'] as String? ??
                    'Sin nombre';

                items.add(DropdownMenuItem<int>(
                  value: id,
                  child: Text(name),
                ));
              }

              return items;
            }

            // Build the dropdown items for medium category
            List<DropdownMenuItem<int>> buildMediumItems() {
              final items = <DropdownMenuItem<int>>[];

              // Add a null item for optional selection
              items.add(const DropdownMenuItem<int>(
                value: null,
                child: Text('No seleccionar'),
              ));

              // Only show other categories if principal is selected
              if (selectedPrincipalType != null) {
                // Only show active categories
                final activeCategories = _availableCategories
                    .where((category) => category['isActive'] == true)
                    .toList();

                // Add categories that are not the principal
                for (var category in activeCategories) {
                  final id = category['Tipo_Producto'] as int? ??
                      int.tryParse(category['Tipo_Producto'].toString()) ??
                      0;

                  // Skip if this is the principal category
                  if (id == selectedPrincipalType) continue;

                  final name = category['Categoria_Producto'] as String? ??
                      category['Nombre'] as String? ??
                      'Sin nombre';

                  items.add(DropdownMenuItem<int>(
                    value: id,
                    child: Text(name),
                  ));
                }
              }

              return items;
            }

            // Build the dropdown items for far category
            List<DropdownMenuItem<int>> buildFarItems() {
              final items = <DropdownMenuItem<int>>[];

              // Add a null item for optional selection
              items.add(const DropdownMenuItem<int>(
                value: null,
                child: Text('No seleccionar'),
              ));

              // Only show other categories if principal is selected
              if (selectedPrincipalType != null) {
                // Only show active categories
                final activeCategories = _availableCategories
                    .where((category) => category['isActive'] == true)
                    .toList();

                // Add categories that are not selected for principal or medium
                for (var category in activeCategories) {
                  final id = category['Tipo_Producto'] as int? ??
                      int.tryParse(category['Tipo_Producto'].toString()) ??
                      0;

                  // Skip if this is the principal or medium category
                  if (id == selectedPrincipalType || id == selectedMediumType)
                    continue;

                  final name = category['Categoria_Producto'] as String? ??
                      category['Nombre'] as String? ??
                      'Sin nombre';

                  items.add(DropdownMenuItem<int>(
                    value: id,
                    child: Text(name),
                  ));
                }
              }

              return items;
            }

            return AlertDialog(
              title: const Text('Añadir Nuevo Sensor'),
              content: Container(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ID Field
                        TextFormField(
                          controller: idSensorController,
                          decoration: const InputDecoration(
                            labelText: 'ID Sensor',
                            hintText: 'Ingrese un número único',
                            errorMaxLines: 3,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el ID del sensor';
                            }

                            final id = int.tryParse(value);
                            if (id == null) {
                              return 'Por favor ingrese un número válido';
                            }

                            if (existingSensorIds.contains(id)) {
                              return 'Este ID de sensor ya existe. Por favor ingrese un ID diferente.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Categories
                        if (_isLoadingCategories)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else if (_availableCategories.isEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Warning message when no categories are available
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            color: Colors.amber.shade800),
                                        const SizedBox(width: 8),
                                        Text(
                                          'No existen categorías disponibles',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Necesitas crear al menos una categoría para poder asociarla al sensor.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    // Button to go to the categories view
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.category),
                                      label: const Text('Ir a Categorías'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        // Close current dialog
                                        Navigator.of(context).pop();

                                        // Navigate to the categories view
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CategoriesView(
                                                    toggleTheme:
                                                        widget.toggleTheme),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Categoría Principal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: selectedPrincipalType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Seleccionar Categoría Principal',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                items: buildPrincipalItems(),
                                onChanged: (int? newValue) {
                                  setDialogState(() {
                                    selectedPrincipalType = newValue;
                                    // Reset medium and far if they match the new principal
                                    if (selectedMediumType == newValue) {
                                      selectedMediumType = null;
                                    }
                                    if (selectedFarType == newValue) {
                                      selectedFarType = null;
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Por favor seleccione una categoría principal';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Categoría Media (Opcional)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: selectedMediumType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Seleccionar Categoría Media',
                                  hintText: 'Opcional',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                items: buildMediumItems(),
                                onChanged: (int? newValue) {
                                  setDialogState(() {
                                    selectedMediumType = newValue;
                                    // Reset far if it matches the new medium
                                    if (selectedFarType == newValue) {
                                      selectedFarType = null;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Categoría Lejana (Opcional)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: selectedFarType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Seleccionar Categoría Lejana',
                                  hintText: 'Opcional',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                items: buildFarItems(),
                                onChanged: (int? newValue) {
                                  setDialogState(() {
                                    selectedFarType = newValue;
                                  });
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Añadir'),
                  onPressed: _isLoadingCategories ||
                          _availableCategories.isEmpty ||
                          selectedPrincipalType == null
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            final idSensor = int.parse(idSensorController.text);
                            _addSensor(idSensor, selectedPrincipalType!,
                                selectedMediumType, selectedFarType);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSensorDialog(Map<String, dynamic> sensor) {
    final formKey = GlobalKey<FormState>();
    final idSensorController =
        TextEditingController(text: sensor['id_sensor'].toString());
    int? selectedPrincipalType = sensor['tipo_producto_principal'];
    int? selectedMediumType = sensor['tipo_producto_medium'];
    int? selectedFarType = sensor['tipo_producto_far'];
    final String mongoId = sensor['_id'] as String;

    // List of existing sensor IDs for validation (excluding the current one)
    final List<int> existingSensorIds = _sensors
        .where((s) => s['_id'] != mongoId)
        .map((s) => s['id_sensor'] as int)
        .toList();

    // First load available categories for this sensor
    setState(() => _isLoadingCategories = true);
    _fetchAvailableCategories(sensorId: mongoId).then((_) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);

        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing when clicking outside
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Build the dropdown items for principal category
                List<DropdownMenuItem<int>> buildPrincipalItems() {
                  final items = <DropdownMenuItem<int>>[];

                  // Always include current principal type if it exists
                  if (selectedPrincipalType != null) {
                    String currentName = sensor['principal_category_name'] ??
                        'Categoría Principal Actual';
                    items.add(DropdownMenuItem<int>(
                      value: selectedPrincipalType,
                      child: Text(currentName),
                    ));
                  }

                  // Only show active categories
                  final activeCategories = _availableCategories
                      .where((category) => category['isActive'] == true)
                      .toList();

                  // Add all other available categories
                  for (var category in activeCategories) {
                    final id = category['Tipo_Producto'] as int? ??
                        int.tryParse(category['Tipo_Producto'].toString()) ??
                        0;

                    // Skip if this is already the selected principal
                    if (id == selectedPrincipalType) continue;

                    final name = category['Categoria_Producto'] as String? ??
                        category['Nombre'] as String? ??
                        'Sin nombre';

                    items.add(DropdownMenuItem<int>(
                      value: id,
                      child: Text(name),
                    ));
                  }

                  return items;
                }

                // Build the dropdown items for medium category
                List<DropdownMenuItem<int>> buildMediumItems() {
                  final items = <DropdownMenuItem<int>>[];

                  // Add a null item for optional selection
                  items.add(const DropdownMenuItem<int>(
                    value: null,
                    child: Text('No seleccionar'),
                  ));

                  // Include current medium category if it exists and is different from principal
                  if (selectedMediumType != null &&
                      selectedMediumType != selectedPrincipalType) {
                    String currentName = sensor['medium_category_name'] ??
                        'Categoría Media Actual';
                    items.add(DropdownMenuItem<int>(
                      value: selectedMediumType,
                      child: Text(currentName),
                    ));
                  }

                  // Only show active categories
                  final activeCategories = _availableCategories
                      .where((category) => category['isActive'] == true)
                      .toList();

                  // Add available categories that are not principal or already medium
                  if (selectedPrincipalType != null) {
                    for (var category in activeCategories) {
                      final id = category['Tipo_Producto'] as int? ??
                          int.tryParse(category['Tipo_Producto'].toString()) ??
                          0;

                      // Skip if this is already a selected category
                      if (id == selectedPrincipalType ||
                          id == selectedMediumType) continue;

                      final name = category['Categoria_Producto'] as String? ??
                          category['Nombre'] as String? ??
                          'Sin nombre';

                      items.add(DropdownMenuItem<int>(
                        value: id,
                        child: Text(name),
                      ));
                    }
                  }

                  return items;
                }

                // Build the dropdown items for far category
                List<DropdownMenuItem<int>> buildFarItems() {
                  final items = <DropdownMenuItem<int>>[];

                  // Add a null item for optional selection
                  items.add(const DropdownMenuItem<int>(
                    value: null,
                    child: Text('No seleccionar'),
                  ));

                  // Include current far category if it exists and is different from principal and medium
                  if (selectedFarType != null &&
                      selectedFarType != selectedPrincipalType &&
                      selectedFarType != selectedMediumType) {
                    String currentName = sensor['far_category_name'] ??
                        'Categoría Lejana Actual';
                    items.add(DropdownMenuItem<int>(
                      value: selectedFarType,
                      child: Text(currentName),
                    ));
                  }

                  // Only show active categories
                  final activeCategories = _availableCategories
                      .where((category) => category['isActive'] == true)
                      .toList();

                  // Add available categories that are not selected for principal or medium
                  if (selectedPrincipalType != null) {
                    for (var category in activeCategories) {
                      final id = category['Tipo_Producto'] as int? ??
                          int.tryParse(category['Tipo_Producto'].toString()) ??
                          0;

                      // Skip if already selected for another category
                      if (id == selectedPrincipalType ||
                          id == selectedMediumType ||
                          id == selectedFarType) continue;

                      final name = category['Categoria_Producto'] as String? ??
                          category['Nombre'] as String? ??
                          'Sin nombre';

                      items.add(DropdownMenuItem<int>(
                        value: id,
                        child: Text(name),
                      ));
                    }
                  }

                  return items;
                }

                return AlertDialog(
                  title: Text('Editar Sensor ${sensor['id_sensor']}'),
                  content: Container(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // ID Field
                            TextFormField(
                              controller: idSensorController,
                              decoration: const InputDecoration(
                                labelText: 'ID Sensor',
                                hintText: 'Ingrese un número único',
                                errorMaxLines: 3,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingrese el ID del sensor';
                                }

                                final id = int.tryParse(value);
                                if (id == null) {
                                  return 'Por favor ingrese un número válido';
                                }

                                if (existingSensorIds.contains(id)) {
                                  return 'Este ID de sensor ya existe. Por favor ingrese un ID diferente.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // Categories
                            if (_isLoadingCategories)
                              const Center(
                                child: CircularProgressIndicator(),
                              )
                            else if (_availableCategories.isEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Warning message when no categories are available
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.amber.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded,
                                                color: Colors.amber.shade800),
                                            const SizedBox(width: 8),
                                            Text(
                                              'No existen categorías disponibles',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Necesitas crear al menos una categoría para poder asociarla al sensor.',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 16),
                                        // Button to go to the categories view
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.category),
                                          label: const Text('Ir a Categorías'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.amber.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            // Close current dialog
                                            Navigator.of(context).pop();

                                            // Navigate to the categories view
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    CategoriesView(
                                                        toggleTheme:
                                                            widget.toggleTheme),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Categoría Principal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: selectedPrincipalType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Seleccionar Categoría Principal',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    items: buildPrincipalItems(),
                                    onChanged: (int? newValue) {
                                      setDialogState(() {
                                        selectedPrincipalType = newValue;
                                        // Reset medium and far if they match the new principal
                                        if (selectedMediumType == newValue) {
                                          selectedMediumType = null;
                                        }
                                        if (selectedFarType == newValue) {
                                          selectedFarType = null;
                                        }
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Por favor seleccione una categoría principal';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Categoría Media (Opcional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: selectedMediumType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Seleccionar Categoría Media',
                                      hintText: 'Opcional',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    items: buildMediumItems(),
                                    onChanged: (int? newValue) {
                                      setDialogState(() {
                                        selectedMediumType = newValue;
                                        // Reset far if it matches the new medium
                                        if (selectedFarType == newValue) {
                                          selectedFarType = null;
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Categoría Lejana (Opcional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: selectedFarType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Seleccionar Categoría Lejana',
                                      hintText: 'Opcional',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    items: buildFarItems(),
                                    onChanged: (int? newValue) {
                                      setDialogState(() {
                                        selectedFarType = newValue;
                                      });
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    ElevatedButton(
                      child: const Text('Guardar'),
                      onPressed: _isLoadingCategories ||
                              _availableCategories.isEmpty ||
                              selectedPrincipalType == null
                          ? null
                          : () {
                              if (formKey.currentState!.validate()) {
                                final idSensor =
                                    int.parse(idSensorController.text);
                                _updateSensor(
                                    mongoId,
                                    idSensor,
                                    selectedPrincipalType!,
                                    selectedMediumType,
                                    selectedFarType);
                              }
                            },
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }).catchError((error) {
      // Handle error if fetchAvailableCategories fails entirely
      setState(() {
        _isLoadingCategories = false;
        _categoriesError = error.toString();
      });

      // Show error toast
      ToastService.showError(
        context,
        'Error al cargar categorías: $error',
      );
    });
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> sensor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Está seguro que desea eliminar el sensor ${sensor['id_sensor']}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSensor(sensor['_id']);
              },
            ),
          ],
        );
      },
    );
  }

  // Helper widget to build the main content (DataTable)
  Widget _buildSensorsTable() {
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (_currentPage + 1) * _rowsPerPage;
    final List<Map<String, dynamic>> pageSensors =
        _filteredSensors.skip(startIndex).take(_rowsPerPage).toList();
    final int totalPages = (_filteredSensors.length / _rowsPerPage).ceil();
    final Color azulOscuro = const Color(0xFF223A5E);
    final Color grisClaro = const Color(0xFFE0E0E0);
    final theme = Theme.of(context);

    return Column(
      children: [
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                    (states) => Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.1),
                  ),
                  columns: const [
                    DataColumn(
                        label: Text('ID Sensor',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Categoría Principal',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Categoría Media',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Categoría Lejana',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Estado',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Acciones',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: pageSensors.map((sensor) {
                    final mongoId = sensor['_id'] as String;
                    final idSensor = sensor['id_sensor'] ?? 'N/A';
                    final isActive = sensor['isActive'] as bool? ?? false;

                    return DataRow(
                      cells: [
                        DataCell(Text(idSensor.toString())),
                        DataCell(Text(sensor['principal_category_name'] ??
                            'No asignada')),
                        DataCell(Text(
                            sensor['medium_category_name'] ?? 'No asignada')),
                        DataCell(
                            Text(sensor['far_category_name'] ?? 'No asignada')),
                        DataCell(Row(
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (newValue) {
                                _toggleSensorStatus(mongoId, newValue);
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(
                                      0xFF64B5F6) // Light blue for dark mode
                                  : azulOscuro,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Theme.of(context)
                                          .brightness ==
                                      Brightness.dark
                                  ? Color(0xFF424242) // Dark grey for dark mode
                                  : grisClaro,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              splashRadius: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(isActive ? 'Activo' : 'Inactivo',
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? isActive
                                            ? Color(
                                                0xFF81D4FA) // Lighter blue for "Activo" in dark mode
                                            : Color(
                                                0xFFEF9A9A) // Light red for "Inactivo" in dark mode
                                        : isActive
                                            ? azulOscuro
                                            : Colors.red.shade700,
                                    fontWeight: FontWeight.w500)),
                          ],
                        )),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Editar Sensor',
                                child: IconButton(
                                  icon: Icon(Icons.edit,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(
                                              0xFF81D4FA) // Light blue for dark mode
                                          : const Color(0xFF223A5E)),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showEditSensorDialog(sensor),
                                ),
                              ),
                              Tooltip(
                                message: 'Eliminar Sensor',
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(
                                              0xFFEF9A9A) // Light red for dark mode
                                          : Colors.red.shade600),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Eliminar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showDeleteConfirmationDialog(sensor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ),
        // Pagination controls
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Column(
            children: [
              // Record count text
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Mostrando ${_filteredSensors.isEmpty ? 0 : startIndex + 1}-${endIndex > _filteredSensors.length ? _filteredSensors.length : endIndex} de ${_filteredSensors.length} registros',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              // Page navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_left),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage = 0;
                            });
                          }
                        : null,
                    tooltip: 'Primera página',
                    color: _currentPage > 0
                        ? const Color(0xFF0277BD)
                        : Colors.grey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_left),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                    tooltip: 'Página anterior',
                    color: _currentPage > 0
                        ? const Color(0xFF0277BD)
                        : Colors.grey,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Página ${_currentPage + 1} de ${totalPages == 0 ? 1 : totalPages}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_right),
                    onPressed: endIndex < _filteredSensors.length
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    tooltip: 'Página siguiente',
                    color: endIndex < _filteredSensors.length
                        ? const Color(0xFF0277BD)
                        : Colors.grey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_right),
                    onPressed: _currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              _currentPage = totalPages - 1;
                            });
                          }
                        : null,
                    tooltip: 'Última página',
                    color: _currentPage < totalPages - 1
                        ? const Color(0xFF0277BD)
                        : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final isAdmin = authController.currentUser?.role == 'admin';
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('StoreSense')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('No tienes permisos para acceder a esta sección.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.dashboard),
                label: const Text('Volver al Dashboard'),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    Widget bodyContent;

    if (_isLoadingSensors) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_sensorsError != null) {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      'Error al cargar sensores: $_sensorsError\n\nPor favor, revise la conexión con el servidor e inténtelo de nuevo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    onPressed: () {
                      setState(() {
                        _isLoadingSensors = true;
                        _sensorsError = null;
                        _isLoadingCategories = true;
                        _categoriesError = null;
                      });
                      _fetchSensors();
                      _fetchAvailableCategories();
                    },
                  )
                ],
              )));
    } else {
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header and Filters Card
          Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de Sensores',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF223A5E),
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Search field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Búsqueda',
                            hintText: 'Ingrese ID o Categoría para buscar',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            suffixIcon: _searchTerm.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchTerm = '';
                                        _filterSensors();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchTerm = value;
                              _filterSensors();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SensorStatusFilter>(
                            focusColor: Colors.transparent,
                            value: _selectedStatus,
                            icon: const Icon(Icons.filter_list),
                            items: const [
                              DropdownMenuItem(
                                value: SensorStatusFilter.todos,
                                child: Text('Estado: Todos'),
                              ),
                              DropdownMenuItem(
                                value: SensorStatusFilter.activo,
                                child: Text('Estado: Activo'),
                              ),
                              DropdownMenuItem(
                                value: SensorStatusFilter.inactivo,
                                child: Text('Estado: Inactivo'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                  _filterSensors();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Table Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _fetchSensors(),
                  _fetchAvailableCategories(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [_buildSensorsTable()],
              ),
            ),
          ),

          // Optional footer text
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Center(
                child: Text('Lista de sensores y sus estados',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary))),
          ),
        ],
      );
    }

    return Scaffold(
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSensorDialog,
        tooltip: 'Añadir Sensor',
        child: const Icon(Icons.add),
      ),
    );
  }
}
