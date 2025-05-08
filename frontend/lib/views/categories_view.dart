import 'package:flutter/material.dart';
import '../controllers/categories_controller.dart';
import '../widgets/toast_notification.dart'; // Import the new ToastService
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';

// Add enum for category status filter similar to user filter
enum CategoryStatusFilter { todos, activo, inactivo }

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
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50];

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
    String? errorText; // Variable para mostrar el mensaje de error

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('Editar Categoría'),
              content: Column(
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
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        errorText =
                            null; // Limpiar el mensaje de error al escribir
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Switch para activar/desactivar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activo'),
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
                      // If error occurs, reload to get correct state
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
    String? errorTextTipoProducto;
    String? errorTextCategoriaProducto;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('Crear Nueva Categoría'),
              content: Column(
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
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        errorTextTipoProducto =
                            null; // Limpiar error al escribir
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Campo para Categoria_Producto
                  TextField(
                    controller: categoriaProductoController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la Categoría',
                      border: const OutlineInputBorder(),
                      errorText: errorTextCategoriaProducto,
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        errorTextCategoriaProducto = null; // Limpiar error
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Switch para activar/desactivar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activo'),
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
        appBar: AppBar(title: const Text('Acceso denegado')),
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
                              hintText: 'Buscar categorías...',
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
                        label: Text('Foto',
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
                    return DataRow(
                      cells: [
                        DataCell(
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.category,
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
                                      color: Colors.blue.shade600),
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Filas por página:', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _rowsPerPage,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                items: _rowsPerPageOptions.map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _rowsPerPage = value;
                      _currentPage = 0;
                    });
                  }
                },
                underline: Container(),
              ),
              const SizedBox(width: 32),
              Text(
                  'Página ${filteredCategories.isEmpty ? 0 : _currentPage + 1} de $totalPages',
                  style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.black.withOpacity(_currentPage > 0 ? 0.87 : 0.2),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                splashRadius: 18,
                iconSize: 24,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.black.withOpacity(
                    endIndex < filteredCategories.length ? 0.87 : 0.2),
                onPressed: endIndex < filteredCategories.length
                    ? () => setState(() => _currentPage++)
                    : null,
                splashRadius: 18,
                iconSize: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
