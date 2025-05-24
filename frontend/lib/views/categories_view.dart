import 'package:flutter/material.dart';
import '../controllers/categories_controller.dart';
import '../widgets/toast_notification.dart'; // Import the new ToastService
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';

// Helper class to convert icon names to IconData
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
    };

    return iconMap[name] ?? Icons.category;
  }
}

// Add enum for category status filter similar to user filter
enum CategoryStatusFilter { todos, activo, inactivo }

// Widget for icon selection
class IconSelector extends StatefulWidget {
  final String initialIcon;
  final Function(String) onIconSelected;

  const IconSelector({
    Key? key,
    required this.initialIcon,
    required this.onIconSelected,
  }) : super(key: key);

  @override
  State<IconSelector> createState() => _IconSelectorState();
}

class _IconSelectorState extends State<IconSelector> {
  late String selectedIcon;
  bool _showGrid = false;

  // List of common Material icons to choose from
  final List<Map<String, dynamic>> availableIcons = [
    {'name': 'category', 'icon': Icons.category},
    {'name': 'shopping_basket', 'icon': Icons.shopping_basket},
    {'name': 'fastfood', 'icon': Icons.fastfood},
    {'name': 'local_drink', 'icon': Icons.local_drink},
    {'name': 'bakery_dining', 'icon': Icons.bakery_dining},
    {'name': 'restaurant', 'icon': Icons.restaurant},
    {'name': 'liquor', 'icon': Icons.liquor},
    {'name': 'local_mall', 'icon': Icons.local_mall},
    {'name': 'checkroom', 'icon': Icons.checkroom},
    {'name': 'diamond', 'icon': Icons.diamond},
    {'name': 'watch', 'icon': Icons.watch},
    {'name': 'devices', 'icon': Icons.devices},
    {'name': 'phone_android', 'icon': Icons.phone_android},
    {'name': 'tv', 'icon': Icons.tv},
    {'name': 'laptop', 'icon': Icons.laptop},
    {'name': 'headphones', 'icon': Icons.headphones},
    {'name': 'camera_alt', 'icon': Icons.camera_alt},
    {'name': 'sports_basketball', 'icon': Icons.sports_basketball},
    {'name': 'sports_soccer', 'icon': Icons.sports_soccer},
    {'name': 'sports_tennis', 'icon': Icons.sports_tennis},
    {'name': 'fitness_center', 'icon': Icons.fitness_center},
    {'name': 'home', 'icon': Icons.home},
    {'name': 'bed', 'icon': Icons.bed},
    {'name': 'chair', 'icon': Icons.chair},
    {'name': 'kitchen', 'icon': Icons.kitchen},
    {'name': 'format_paint', 'icon': Icons.format_paint},
    {'name': 'toys', 'icon': Icons.toys},
    {'name': 'pets', 'icon': Icons.pets},
    {'name': 'child_friendly', 'icon': Icons.child_friendly},
    {'name': 'book', 'icon': Icons.book},
    {'name': 'auto_stories', 'icon': Icons.auto_stories},
    {'name': 'medical_services', 'icon': Icons.medical_services},
    {'name': 'spa', 'icon': Icons.spa},
  ];

  @override
  void initState() {
    super.initState();
    selectedIcon = widget.initialIcon;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Icono',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // Current selected icon preview
        InkWell(
          onTap: () {
            setState(() {
              _showGrid = !_showGrid;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(IconDataHelper.getIconByName(selectedIcon), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Icono seleccionado',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),

        // Grid of icons to choose from
        if (_showGrid) ...[
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: availableIcons.length,
              itemBuilder: (context, index) {
                final iconData = availableIcons[index];
                final bool isSelected = selectedIcon == iconData['name'];

                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedIcon = iconData['name'];
                      widget.onIconSelected(selectedIcon);
                      _showGrid = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected
                          ? Border.all(color: Theme.of(context).primaryColor)
                          : null,
                    ),
                    child: Icon(
                      iconData['icon'],
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade800,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class CategoriesView extends StatefulWidget {
  final Function toggleTheme;

  const CategoriesView({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final CategoriesController _controller = CategoriesController();
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> filteredCategories = [];
  bool isLoading = true;
  String searchQuery = '';
  CategoryStatusFilter _selectedStatus =
      CategoryStatusFilter.todos; // Default filter status
  int _currentPage = 0;
  final int _rowsPerPage = 10; // Fixed at 10 rows per page

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Llama a getCategories con el token
      final List<Map<String, dynamic>> categoryData =
          await _controller.getCategories(token);

      setState(() {
        categories = categoryData;
        _applyFilters(); // Aplica los filtros después de cargar las categorías
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ToastService.showError(context, 'Error al cargar categorías: $e');
    }
  }

  // Updated method to handle both search query and status filter
  void _applyFilters() {
    setState(() {
      List<Map<String, dynamic>> result = categories;

      // Apply status filter first
      if (_selectedStatus != CategoryStatusFilter.todos) {
        bool isActiveFilter = _selectedStatus == CategoryStatusFilter.activo;
        result = result.where((category) {
          final isActive = category["isActive"] as bool? ?? false;
          return isActive == isActiveFilter;
        }).toList();
      }

      // Then apply search filter if needed
      if (searchQuery.isNotEmpty) {
        result = result
            .where((category) => category["Categoria_Producto"]
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList();
      }

      filteredCategories = result;
      _currentPage = 0; // Resetear página al filtrar
    });
  }

  // Update the existing filter method to call the new combined method
  void _filterCategories(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _deleteCategory(Map<String, dynamic> category) async {
    final String categoriaId = category["_id"];
    final String categoriaNombre =
        category["Categoria_Producto"] ?? "Categoría";

    // Confirmar eliminación
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Categoría'),
          content: Text(
            '¿Estás seguro de que deseas eliminar la categoría "$categoriaNombre"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Obtén el token JWT desde el AuthController
        final authController =
            Provider.of<AuthController>(context, listen: false);
        final String? token = authController.token;

        if (token == null) {
          throw Exception('No se encontró el token de autenticación.');
        }

        // Optimistic update - remove from UI first
        if (mounted) {
          setState(() {
            categories.removeWhere((cat) => cat["_id"] == categoriaId);
            _applyFilters(); // Update filtered list
            isLoading = true; // Show loading state
          });
        }

        // Llamar al controlador para eliminar la categoría
        await _controller.deleteCategory(categoriaId, token);

        // Recargar la lista de categorías para asegurar consistencia
        if (mounted) {
          await _loadCategories();
          ToastService.showSuccess(
              context, 'Categoría eliminada: $categoriaNombre');
        }
      } catch (e) {
        // On error, refresh the list to get the correct state
        if (mounted) {
          await _loadCategories();
          ToastService.showError(context, 'Error al eliminar categoría: $e');
        }
      }
    }
  }

  // Función auxiliar para eliminar cámara por id (llama al endpoint de cámaras)
  Future<void> _deleteCameraById(String cameraMongoId) async {
    final url = Uri.parse('http://127.0.0.1:8000/api/cameras/$cameraMongoId');
    final response = await http.delete(url);
    if (response.statusCode != 204) {
      throw Exception('Error al eliminar cámara: ${response.body}');
    }
  }

  // Función auxiliar para actualizar el Tipo_Producto de una cámara (reasignar)
  Future<void> _updateCameraTipoProducto(
      String cameraMongoId, int idCamara, int newTipoProducto) async {
    final url = Uri.parse('http://127.0.0.1:8000/api/cameras/$cameraMongoId');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'Id_Camara': idCamara,
        'Tipo_Producto': newTipoProducto,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al reasignar cámara: ${response.body}');
    }
  }

  void _showEditCategoryModal(Map<String, dynamic> category) {
    final TextEditingController nameController =
        TextEditingController(text: category["Categoria_Producto"]);
    bool isActive = category["isActive"];
    String selectedIcon =
        category["icon"] ?? "category"; // Get existing icon or use default
    String? errorText; // Variable para mostrar el mensaje de error

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('Editar Categoría'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo para editar el nombre
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la categoría',
                        border: const OutlineInputBorder(),
                        errorText:
                            errorText, // Mostrar mensaje de error si es necesario
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          errorText =
                              null; // Limpiar el mensaje de error al escribir
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Icon selector widget
                    IconSelector(
                      initialIcon: selectedIcon,
                      onIconSelected: (icon) {
                        setModalState(() {
                          selectedIcon = icon;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Switch para activar/desactivar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activo',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : null,
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            setModalState(() {
                              isActive =
                                  value; // Actualiza el estado local del modal
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      // Validar que el campo no esté vacío
                      setModalState(() {
                        errorText = 'El nombre no puede estar vacío';
                      });
                      return;
                    }

                    try {
                      // Obtén el token JWT desde el AuthController
                      final authController =
                          Provider.of<AuthController>(context, listen: false);
                      final String? token = authController.token;

                      if (token == null) {
                        throw Exception(
                            'No se encontró el token de autenticación.');
                      }

                      // Optimistic update - update UI before API call
                      final String categoryId = category["_id"];
                      final String newName = nameController.text.trim();

                      // Update the local list
                      if (mounted) {
                        setState(() {
                          final index = categories
                              .indexWhere((c) => c["_id"] == categoryId);
                          if (index != -1) {
                            categories[index]["Categoria_Producto"] = newName;
                            categories[index]["isActive"] = isActive;
                            categories[index]["icon"] = selectedIcon;
                          }
                          // Update filtered list
                          _applyFilters();
                        });
                      }

                      // Cerrar el modal
                      Navigator.of(context).pop();

                      // Llamar al controlador para actualizar la categoría
                      await _controller.updateCategory(
                        categoryId,
                        newName,
                        isActive,
                        token, // Pasar el token aquí
                        icon: selectedIcon, // Pass the selected icon
                      );

                      // Recargar la lista de categorías
                      if (mounted) {
                        await _loadCategories();
                      }

                      if (mounted) {
                        ToastService.showSuccess(
                            context, 'Categoría actualizada exitosamente');
                      }
                    } catch (e) {
                      // If error occurs, reload to get the correct state
                      if (mounted) {
                        await _loadCategories();
                        ToastService.showError(
                            context, 'Error al actualizar categoría: $e');
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateCategoryModal() {
    final TextEditingController tipoProductoController =
        TextEditingController();
    final TextEditingController categoriaProductoController =
        TextEditingController();
    bool isActive = true;
    String selectedIcon = 'category'; // Default icon
    String? errorTextTipoProducto;
    String? errorTextCategoriaProducto;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('Crear Nueva Categoría'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo para Tipo_Producto
                    TextField(
                      controller: tipoProductoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Producto (ID)',
                        border: const OutlineInputBorder(),
                        errorText: errorTextTipoProducto,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          errorTextTipoProducto =
                              null; // Limpiar error al escribir

                          // Validación para asegurar que sea un número entero
                          if (value.isNotEmpty) {
                            try {
                              int.parse(value);
                            } catch (e) {
                              errorTextTipoProducto =
                                  'Debe ser un número entero';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Campo para Categoria_Producto
                    TextField(
                      controller: categoriaProductoController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Categoría',
                        border: const OutlineInputBorder(),
                        errorText: errorTextCategoriaProducto,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          errorTextCategoriaProducto = null; // Limpiar error
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Icon selector
                    IconSelector(
                      initialIcon: selectedIcon,
                      onIconSelected: (icon) {
                        setModalState(() {
                          selectedIcon = icon;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Switch para activar/desactivar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activo',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : null,
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            setModalState(() {
                              isActive = value; // Actualizar estado local
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validar campos
                    if (tipoProductoController.text.trim().isEmpty) {
                      setModalState(() {
                        errorTextTipoProducto = 'El campo no puede estar vacío';
                      });
                      return;
                    }

                    // Validar que Tipo_Producto sea un número entero
                    try {
                      int.parse(tipoProductoController.text.trim());
                    } catch (e) {
                      setModalState(() {
                        errorTextTipoProducto = 'Debe ser un número entero';
                      });
                      return;
                    }

                    if (categoriaProductoController.text.trim().isEmpty) {
                      setModalState(() {
                        errorTextCategoriaProducto =
                            'El campo no puede estar vacío';
                      });
                      return;
                    }

                    try {
                      // Obtén el token JWT desde el AuthController
                      final authController =
                          Provider.of<AuthController>(context, listen: false);
                      final String? token = authController.token;

                      if (token == null) {
                        throw Exception(
                            'No se encontró el token de autenticación.');
                      }

                      // Cerrar el modal antes de la operación API
                      Navigator.of(context).pop();

                      // Show loading indicator
                      if (mounted) {
                        setState(() {
                          isLoading = true;
                        });
                      }

                      // Llamar al controlador para crear la categoría
                      await _controller.createCategory(
                        int.parse(tipoProductoController.text.trim()),
                        categoriaProductoController.text.trim(),
                        isActive,
                        token, // Pasar el token aquí
                        icon: selectedIcon, // Pass the selected icon
                      );

                      // Recargar la lista de categorías
                      if (mounted) {
                        await _loadCategories();
                        ToastService.showSuccess(
                            context, 'Categoría creada exitosamente');
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                        ToastService.showError(
                            context, 'Error al crear categoría: $e');
                      }
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleCategoryStatus(Map<String, dynamic> category) async {
    final bool currentStatus = category["isActive"] as bool? ?? false;
    final String categoryId = category["_id"] as String;
    final String categoryName = category["Categoria_Producto"] ?? "Categoría";
    final bool newStatus = !currentStatus;

    try {
      // Obtén el token JWT desde el AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      // Optimistically update UI first
      setState(() {
        // Find the category in our list and update its status
        final index = categories.indexWhere((c) => c["_id"] == categoryId);
        if (index != -1) {
          categories[index]["isActive"] = newStatus;
        }

        // Update the filtered list through our filter method
        _applyFilters();
      });

      // Call API to update status
      await _controller.updateCategory(
        categoryId,
        category["Categoria_Producto"],
        newStatus,
        token,
      );

      // Don't reload the full list after toggle - just keep our optimistic update
      // This avoids the flicker effect where the switch appears to revert

      // Show success message
      if (mounted) {
        ToastService.showSuccess(context,
            'Estado de "$categoryName" actualizado a ${newStatus ? 'activo' : 'inactivo'}');
      }
    } catch (e) {
      // If there was an error, revert the optimistic update
      setState(() {
        final index = categories.indexWhere((c) => c["_id"] == categoryId);
        if (index != -1) {
          categories[index]["isActive"] = currentStatus;
        }

        // Update filtered list after reverting
        _applyFilters();
      });

      if (mounted) {
        ToastService.showError(context, 'Error al actualizar estado: $e');
      }
    }
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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCategoryModal,
        child: const Icon(Icons.add),
        tooltip: 'Crear nueva categoría',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and filter card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorías',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF223A5E),
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explora las categorías en el sistema asociadas a una cámara.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),

                    // Search and filter row
                    Row(
                      children: [
                        // Search field
                        Expanded(
                          child: TextField(
                            onChanged: _filterCategories,
                            decoration: InputDecoration(
                              labelText: 'Búsqueda de Categorías',
                              hintText: 'Ingrese nombre para buscar',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Status filter dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CategoryStatusFilter>(
                              focusColor: Colors.transparent,
                              value: _selectedStatus,
                              icon: const Icon(Icons.filter_list),
                              items: const [
                                DropdownMenuItem(
                                  value: CategoryStatusFilter.todos,
                                  child: Text('Estado: Todos'),
                                ),
                                DropdownMenuItem(
                                  value: CategoryStatusFilter.activo,
                                  child: Text('Estado: Activo'),
                                ),
                                DropdownMenuItem(
                                  value: CategoryStatusFilter.inactivo,
                                  child: Text('Estado: Inactivo'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedStatus = value;
                                    _applyFilters();
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

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: filteredCategories.isEmpty
                          ? Center(
                              child: Text(
                                searchQuery.isEmpty &&
                                        _selectedStatus ==
                                            CategoryStatusFilter.todos
                                    ? 'No hay categorías disponibles.'
                                    : 'No se encontraron categorías que coincidan con los filtros.',
                                style: theme.textTheme.titleMedium,
                              ),
                            )
                          : _buildCategoriesTable(),
                    ),
            ),

            // Optional footer text
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Center(
                  child: Text('Lista de categorías y sus estados',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.secondary))),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the main content (DataTable)
  Widget _buildCategoriesTable() {
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (_currentPage + 1) * _rowsPerPage;
    final List<Map<String, dynamic>> pageCategories =
        filteredCategories.skip(startIndex).take(_rowsPerPage).toList();
    final int totalPages = (filteredCategories.length / _rowsPerPage).ceil();
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
                        label: Text('Icono',
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
                  rows: pageCategories.map((category) {
                    final mongoId = category['_id'] as String;
                    final nombre =
                        category["Categoria_Producto"] ?? 'Desconocida';
                    final isActive = category["isActive"] as bool? ?? false;
                    final iconName = category["icon"] ?? "category";

                    return DataRow(
                      cells: [
                        DataCell(
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              IconDataHelper.getIconByName(iconName),
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        DataCell(Text(nombre)),
                        DataCell(Row(
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (newValue) {
                                _toggleCategoryStatus(category);
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
                                message: 'Editar Categoría',
                                child: IconButton(
                                  icon: Icon(Icons.edit,
                                      color: const Color(0xFF223A5E)),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showEditCategoryModal(category),
                                ),
                              ),
                              Tooltip(
                                message: 'Eliminar Categoría',
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.red.shade600),
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  tooltip: 'Eliminar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deleteCategory(category),
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
        // --- CONTROLES DE PAGINACIÓN ESTILO MATERIAL ---
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
                  'Mostrando ${filteredCategories.isEmpty ? 0 : startIndex + 1}-${endIndex > filteredCategories.length ? filteredCategories.length : endIndex} de ${filteredCategories.length} registros',
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
                      'Página ${filteredCategories.isEmpty ? 0 : _currentPage + 1} de $totalPages',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_right),
                    onPressed: endIndex < filteredCategories.length
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    tooltip: 'Página siguiente',
                    color: endIndex < filteredCategories.length
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
}
