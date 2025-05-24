import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/toast_notification.dart';
import '../controllers/cameras_controller.dart'; // Importar el nuevo controller
import 'categories_view.dart'; // Importar directamente la vista de categorías
import 'package:go_router/go_router.dart';

// Define the base URL for the API
const String _apiBaseUrl =
    'http://127.0.0.1:8000/api'; // Using default FastAPI port

// Add enum for camera status filter similar to user filter
enum CameraStatusFilter { todos, activo, inactivo }

class CamerasView extends StatefulWidget {
  final Function toggleTheme;

  const CamerasView({super.key, required this.toggleTheme});

  @override
  State<CamerasView> createState() => _CamerasViewState();
}

class _CamerasViewState extends State<CamerasView> {
  final CamerasController _controller =
      CamerasController(); // Instanciar el controller
  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _filteredCameras = []; // New filtered list
  List<Map<String, dynamic>> _activeCategories = [];
  bool _isLoadingCameras = true;
  bool _isLoadingCategories = true;
  String? _camerasError;
  String? _categoriesError;
  CameraStatusFilter _selectedStatus =
      CameraStatusFilter.todos; // Default filter status
  String _searchTerm = ''; // For search functionality
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  final int _rowsPerPage = 10; // Fixed at 10 rows per page

  @override
  void initState() {
    super.initState();
    // Fetch both data concurrently
    _fetchCameras();
    _fetchActiveCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCameras() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCameras = true;
      _camerasError = null;
    });

    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para obtener las cámaras
      final cameras = await _controller.getCameras(token);

      if (!mounted) return;

      setState(() {
        _cameras = cameras
          ..sort((a, b) =>
              (a['Id_Camara'] as int).compareTo(b['Id_Camara'] as int));
        _isLoadingCameras = false;
        _filterCameras(); // Aplicar filtros después de cargar los datos
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _camerasError = 'Error al cargar cámaras: $e';
        _isLoadingCameras = false;
      });
    }
  }

  // Función para cargar categorías activas
  Future<void> _fetchActiveCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para obtener las categorías activas
      final activeCategories = await _controller.getActiveCategories(token);

      if (!mounted) return;

      setState(() {
        _activeCategories = activeCategories;
        _isLoadingCategories = false;
        print(
            'Successfully loaded ${_activeCategories.length} active categories');
      });
    } catch (e) {
      print('Error during category loading: $e');
      if (!mounted) return;

      setState(() {
        _categoriesError = 'Error: $e';
        _isLoadingCategories = false;
      });
    }
  }

  // Helper to find type/product ID given various possible field names
  int? _extractProductTypeId(Map<String, dynamic> camera) {
    final possibleFields = [
      'Tipo_Producto',
      'tipo_producto',
      'product_type',
      'type_id',
      'category_id',
      'Id_Tipo'
    ];

    for (var field in possibleFields) {
      if (camera.containsKey(field)) {
        var value = camera[field];
        if (value is int) return value;
        if (value is String) {
          int? parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }

    print('Could not find product type ID in camera: ${camera['Id_Camara']}');
    return null;
  }

  String _extractCategoryName(Map<String, dynamic> camera) {
    final possibleFields = [
      'Categoria_Producto',
      'categoria_producto',
      'category_name',
      'type_name',
      'Nombre_Categoria',
      'nombre_categoria'
    ];

    for (var field in possibleFields) {
      if (camera.containsKey(field) && camera[field] != null) {
        return camera[field].toString();
      }
    }

    return 'Categoría Desconocida';
  }

  // --- CRUD Operations ---

  Future<void> _addCamera(int idCamara, int categoryId) async {
    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para añadir la cámara
      await _controller.addCamera(idCamara, categoryId, token);

      // Recargar la lista de cámaras
      await _fetchCameras();

      // Cerrar el diálogo
      Navigator.of(context).pop();

      // Mostrar notificación de éxito
      ToastService.showSuccess(context, 'Cámara añadida con éxito.');
    } catch (e) {
      // Si hay un diálogo abierto, cerrarlo
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ToastService.showError(context, 'Error al añadir cámara: $e');
    }
  }

  Future<void> _toggleCameraStatus(String mongoId, bool currentStatus) async {
    if (!mounted) return;
    final currentContext = context;
    final bool newStatus = !currentStatus;

    // Encuentra la cámara en la lista y actualiza su estado de manera optimista
    final index = _cameras.indexWhere((cam) => cam['_id'] == mongoId);
    if (index != -1) {
      setState(() {
        _cameras[index]['isActive'] = newStatus;
        _filterCameras(); // Aplicar filtros después de actualizar el estado
      });
    }

    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para actualizar el estado
      await _controller.toggleCameraStatus(mongoId, newStatus, token);

      if (!mounted) return;

      // No reload full camera list to avoid switch flickering
      // The optimistic update already took care of the UI

      // Éxito, el estado ya se actualizó de manera optimista
      ToastService.showSuccess(currentContext,
          'Estado de cámara actualizado a ${newStatus ? 'activa' : 'inactiva'}');
    } catch (e) {
      // Revertir el cambio optimista si falla la solicitud
      if (index != -1 && mounted) {
        setState(() {
          _cameras[index]['isActive'] = currentStatus;
          _filterCameras(); // Aplicar filtros después de revertir el estado
        });
      }
      if (mounted) {
        ToastService.showError(
            currentContext, 'Error al actualizar estado: $e');
      }
    }
  }

  Future<void> _deleteCamera(String mongoId) async {
    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para eliminar la cámara
      await _controller.deleteCamera(mongoId, token);

      // Recargar la lista de cámaras
      await _fetchCameras();

      // Mostrar notificación de éxito
      ToastService.showSuccess(context, 'Cámara eliminada con éxito.');
    } catch (e) {
      ToastService.showError(context, 'Error al eliminar cámara: $e');
    }
  }

  // Método para editar una cámara existente
  Future<void> _editCamera(String mongoId, int idCamara, int categoryId) async {
    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Usar el controller para editar la cámara
      await _controller.editCamera(mongoId, idCamara, categoryId, token);

      // Recargar la lista de cámaras
      await _fetchCameras();

      // Cerrar el diálogo
      Navigator.of(context).pop();

      // Mostrar notificación de éxito
      ToastService.showSuccess(context, 'Cámara actualizada con éxito.');
    } catch (e) {
      // Si hay un diálogo abierto, cerrarlo
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ToastService.showError(context, 'Error al actualizar cámara: $e');
    }
  }

  // --- Dialogs ---

  void _showAddCameraDialog() {
    if (_isLoadingCategories) {
      // Esperar a que las categorías se carguen antes de mostrar el diálogo
      ToastService.showInfo(
          context, 'Cargando categorías, por favor espere...');
      _fetchActiveCategories().then((_) {
        if (mounted) {
          // Mostrar el diálogo solo cuando termina de cargar
          _showAddCameraDialogContent();
        }
      });
    } else {
      // Ya cargaron categorías, mostrar el diálogo
      _showAddCameraDialogContent();
    }
  }

  void _showAddCameraDialogContent() {
    final formKey = GlobalKey<FormState>();
    final idCamaraController = TextEditingController();
    int? selectedCategoryId;

    final List<int> existingCameraIds =
        _cameras.map((camera) => camera['Id_Camara'] as int).toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Crear un mapa de ID a nombre para las categorías
            final Map<int, String> categoryMap = {};
            for (var category in _activeCategories) {
              // Extraer ID de categoría de forma segura
              final id = category['Tipo_Producto'] as int? ??
                  (category['Id_Tipo_Producto'] is int
                      ? category['Id_Tipo_Producto'] as int
                      : int.tryParse(category['Id_Tipo_Producto'].toString()) ??
                          0);

              // Extraer nombre de categoría
              final name = category['Categoria_Producto'] as String? ??
                  category['Nombre'] as String? ??
                  'Sin nombre';

              categoryMap[id] = name;
            }

            return AlertDialog(
              title: const Text('Añadir Nueva Cámara'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Campo ID
                      TextFormField(
                        controller: idCamaraController,
                        decoration: const InputDecoration(
                          labelText: 'ID Cámara (Número)',
                          hintText: 'Ingrese un número único',
                          errorMaxLines: 3,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el ID de la cámara';
                          }

                          final id = int.tryParse(value);
                          if (id == null) {
                            return 'Por favor ingrese un número válido';
                          }

                          if (existingCameraIds.contains(id)) {
                            return 'Este ID de cámara ya existe. Por favor ingrese un ID diferente.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Si hay categorías activas, mostrar el dropdown
                      if (_isLoadingCategories)
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      else if (_activeCategories.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mensaje de aviso cuando no hay categorías
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
                                        'No existen categorías activas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Necesitas crear al menos una categoría activa para poder asociarla a la cámara.',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  // Botón para ir a la vista de categorías
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.category),
                                    label: const Text('Ir a Categorías'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      // Cerrar diálogo actual
                                      Navigator.of(context).pop();

                                      // Navegar a la vista principal de categorías
                                      context.go('/categories');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Categoría',
                          ),
                          items: categoryMap.entries.map((entry) {
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setDialogState(() {
                              selectedCategoryId = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor seleccione una categoría';
                            }
                            return null;
                          },
                        ),
                    ],
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
                          _activeCategories.isEmpty ||
                          selectedCategoryId == null
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            final idCamara = int.parse(idCamaraController.text);
                            _addCamera(idCamara, selectedCategoryId!);
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

  void _showDeleteConfirmationDialog(String mongoId, int idCamara) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Está seguro que desea eliminar la cámara con ID $idCamara?'),
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
                _deleteCamera(mongoId);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditCameraDialog(Map<String, dynamic> camera) {
    print('Opening Edit Camera Dialog');

    final formKey = GlobalKey<FormState>();
    final idCamaraController =
        TextEditingController(text: camera['Id_Camara'].toString());
    int? selectedCategoryId = camera['Tipo_Producto'];
    final String mongoId = camera['_id'] as String;

    // Lista de IDs de cámaras existentes para validación excluyendo el actual
    final List<int> existingCameraIds = _cameras
        .where((cam) => cam['_id'] != mongoId)
        .map((cam) => cam['Id_Camara'] as int)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Crear un mapa simple de ID a nombre para las categorías
            final Map<int, String> categoryMap = {};
            for (var category in _activeCategories) {
              final id = category['Tipo_Producto'] as int? ??
                  (category['Id_Tipo_Producto'] is int
                      ? category['Id_Tipo_Producto'] as int
                      : int.tryParse(category['Id_Tipo_Producto'].toString()) ??
                          0);

              final name = category['Categoria_Producto'] as String? ??
                  category['Nombre'] as String? ??
                  'Sin nombre';

              categoryMap[id] = name;
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Text('Editar Cámara'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar categorías',
                    onPressed: () async {
                      setDialogState(() {
                        _isLoadingCategories = true;
                      });

                      try {
                        await _fetchActiveCategories();
                      } catch (e) {
                        print('Error refreshing categories: $e');
                      }

                      setDialogState(() {});

                      ToastService.showInfo(
                        context,
                        'Categorías cargadas: ${_activeCategories.length}',
                      );
                    },
                  ),
                ],
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Campo ID
                      TextFormField(
                        controller: idCamaraController,
                        decoration: const InputDecoration(
                          labelText: 'ID Cámara (Número)',
                          hintText: 'Ingrese un número único',
                          errorMaxLines: 3,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el ID de la cámara';
                          }

                          final id = int.tryParse(value);
                          if (id == null) {
                            return 'Por favor ingrese un número válido';
                          }

                          if (existingCameraIds.contains(id)) {
                            return 'Este ID de cámara ya existe. Por favor ingrese un ID diferente.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Verificar si hay categorías disponibles
                      if (_isLoadingCategories)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_activeCategories.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mensaje de aviso cuando no hay categorías
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
                                        'No existen categorías activas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Necesitas crear al menos una categoría activa para poder asociarla a la cámara.',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  // Botón para ir a la vista de categorías
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.category),
                                    label: const Text('Ir a Categorías'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      // Cerrar diálogo actual
                                      Navigator.of(context).pop();

                                      // Navegar a la vista principal de categorías
                                      context.go('/categories');
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
                            const Text('Seleccionar Categoría:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            // Simple dropdown button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButton<int>(
                                value: selectedCategoryId,
                                isExpanded: true,
                                hint: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Seleccione una categoría'),
                                ),
                                underline:
                                    Container(), // Eliminar línea inferior
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                items: categoryMap.entries.map((entry) {
                                  return DropdownMenuItem<int>(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  print(
                                      'Selected category: $newValue - ${categoryMap[newValue]}');
                                  setDialogState(() {
                                    selectedCategoryId = newValue;
                                  });
                                },
                              ),
                            ),
                            if (selectedCategoryId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Categoría seleccionada: ${categoryMap[selectedCategoryId]}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
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
                          _activeCategories.isEmpty ||
                          selectedCategoryId == null
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            final idCamara = int.parse(idCamaraController.text);
                            _editCamera(mongoId, idCamara, selectedCategoryId!);
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

  // Method to filter cameras by status and search term
  void _filterCameras() {
    setState(() {
      // First filter by status
      List<Map<String, dynamic>> statusFiltered;
      if (_selectedStatus == CameraStatusFilter.todos) {
        statusFiltered = List.from(_cameras);
      } else {
        bool isActiveFilter = _selectedStatus == CameraStatusFilter.activo;
        statusFiltered = _cameras.where((camera) {
          final isActive = camera['isActive'] as bool? ?? false;
          return isActive == isActiveFilter;
        }).toList();
      }

      // Then apply search filter if search term is not empty
      if (_searchTerm.trim().isEmpty) {
        _filteredCameras = statusFiltered;
      } else {
        final searchLower = _searchTerm.toLowerCase().trim();
        _filteredCameras = statusFiltered.where((camera) {
          // Check if camera ID contains search term
          final idContains = camera['Id_Camara']
              .toString()
              .toLowerCase()
              .contains(searchLower);

          // Get category name - improved method
          String categoryName = '';

          // First try to get the category directly from the camera data
          if (camera.containsKey('Categoria_Producto') &&
              camera['Categoria_Producto'] != null) {
            categoryName =
                camera['Categoria_Producto'].toString().toLowerCase();
          } else {
            // Then try to match with category list
            final typeId = camera['Tipo_Producto'];
            if (typeId != null) {
              for (var category in _activeCategories) {
                final catId =
                    category['Tipo_Producto'] ?? category['Id_Tipo_Producto'];
                if (catId == typeId) {
                  categoryName = (category['Categoria_Producto'] ??
                          category['Nombre'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  break;
                }
              }
            }
          }

          // Add debug prints to help identify issues
          print(
              'Camera ID: ${camera['Id_Camara']}, Category: $categoryName, Search: $searchLower');
          print(
              'ID Match: $idContains, Category Match: ${categoryName.contains(searchLower)}');

          // Return true if either ID or category name contains search term
          return idContains || categoryName.contains(searchLower);
        }).toList();
      }
      _currentPage = 0; // Resetear página al filtrar
    });
  }

  // Helper widget to build the main content (DataTable)
  Widget _buildCamerasTable() {
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (_currentPage + 1) * _rowsPerPage;
    final List<Map<String, dynamic>> pageCameras =
        _filteredCameras.skip(startIndex).take(_rowsPerPage).toList();
    final int totalPages = (_filteredCameras.length / _rowsPerPage).ceil();
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
                        label: Text('ID Cámara',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Categoría',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Estado',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Acciones',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: pageCameras.map((camera) {
                    final mongoId = camera['_id'] as String;
                    final idCamara = camera['Id_Camara'] ?? 'N/A';
                    final categoriaProducto =
                        camera['Categoria_Producto'] ?? 'Desconocida';
                    final isActive = camera['isActive'] as bool? ?? false;

                    return DataRow(
                      cells: [
                        DataCell(Text(idCamara.toString())),
                        DataCell(Text(categoriaProducto.toString())),
                        DataCell(Row(
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (newValue) {
                                _toggleCameraStatus(mongoId, isActive);
                              },
                              activeColor: Colors.white,
                              activeTrackColor: azulOscuro,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: grisClaro,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              splashRadius: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(isActive ? 'Activo' : 'Inactivo',
                                style: TextStyle(
                                    color: isActive
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
                                message: 'Editar Cámara',
                                child: IconButton(
                                  icon: Icon(Icons.edit,
                                      color: const Color(0xFF223A5E)),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showEditCameraDialog(camera),
                                ),
                              ),
                              Tooltip(
                                message: 'Eliminar Cámara',
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.red.shade600),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Eliminar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showDeleteConfirmationDialog(
                                          mongoId, idCamara as int? ?? 0),
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
                  'Mostrando ${_filteredCameras.isEmpty ? 0 : startIndex + 1}-${endIndex > _filteredCameras.length ? _filteredCameras.length : endIndex} de ${_filteredCameras.length} registros',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
              // Pagination buttons
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Página ${_filteredCameras.isEmpty ? 0 : _currentPage + 1} de $totalPages',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_right),
                    onPressed: endIndex < _filteredCameras.length
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    tooltip: 'Página siguiente',
                    color: endIndex < _filteredCameras.length
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

    if (_isLoadingCameras) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_camerasError != null) {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      'Error al cargar cámaras: $_camerasError\n\nPor favor, revise la conexión con el servidor e inténtelo de nuevo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    onPressed: () {
                      setState(() {
                        _isLoadingCameras = true;
                        _camerasError = null;
                        _isLoadingCategories = true;
                        _categoriesError = null;
                      });
                      _fetchCameras();
                      _fetchActiveCategories();
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
                    'Gestión de Cámaras',
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
                                        _filterCameras();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchTerm = value;
                              _filterCameras();
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
                          child: DropdownButton<CameraStatusFilter>(
                            focusColor: Colors.transparent,
                            value: _selectedStatus,
                            icon: const Icon(Icons.filter_list),
                            items: const [
                              DropdownMenuItem(
                                value: CameraStatusFilter.todos,
                                child: Text('Estado: Todos'),
                              ),
                              DropdownMenuItem(
                                value: CameraStatusFilter.activo,
                                child: Text('Estado: Activo'),
                              ),
                              DropdownMenuItem(
                                value: CameraStatusFilter.inactivo,
                                child: Text('Estado: Inactivo'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                  _filterCameras();
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
                  _fetchCameras(),
                  _fetchActiveCategories(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [_buildCamerasTable()],
              ),
            ),
          ),

          // Optional footer text
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Center(
                child: Text('Lista de cámaras y sus estados',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary))),
          ),
        ],
      );
    }

    return Scaffold(
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCameraDialog,
        tooltip: 'Añadir Cámara',
        child: const Icon(Icons.add),
      ),
    );
  }
}
