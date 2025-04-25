import 'package:flutter/material.dart';
import '../controllers/categories_controller.dart';

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
      final List<Map<String, dynamic>> categoryData =
          await _controller.getCategories();

      setState(() {
        categories = categoryData;
        // Apply filters after loading
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
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
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Categoría'),
          content: Text(
            '¿Estás seguro de que deseas eliminar la categoría "${category["Categoria_Producto"]}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            // Botón de cancelar con borde azul
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue), // Borde azul
              ),
              onPressed: () {
                Navigator.of(context).pop(false); // Cancelar
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.blue), // Texto azul
              ),
            ),
            // Botón de eliminar con borde rojo
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red), // Borde rojo
              ),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirmar
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red), // Texto rojo
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Llamar al controlador para eliminar la categoría
        await _controller.deleteCategory(category["_id"]);

        // Recargar la lista de categorías
        await _loadCategories(); // This will also call _applyFilters() now

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Categoría eliminada: ${category["Categoria_Producto"]}',
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar categoría: $e'),
          ),
        );
      }
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
                      // Llamar al controlador para actualizar la categoría
                      await _controller.updateCategory(
                        category["_id"],
                        nameController.text.trim(),
                        isActive,
                      );

                      // Esperamos un poco para asegurarnos que el backend haya guardado
                      await Future.delayed(const Duration(milliseconds: 200));

                      // Recargamos
                      await _loadCategories(); // This will also call _applyFilters() now

                      // Cerramos modal
                      if (mounted) Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Categoría actualizada exitosamente')),
                      );
                    } catch (e) {
                      if (mounted) Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error al actualizar categoría: $e')),
                      );
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
                      // Llamar al controlador para crear la categoría
                      await _controller.createCategory(
                        int.parse(tipoProductoController.text.trim()),
                        categoriaProductoController.text.trim(),
                        isActive,
                      );

                      // Recargar la lista de categorías
                      await _loadCategories(); // This will also call _applyFilters() now

                      // Cerrar el modal
                      if (mounted) Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Categoría creada exitosamente')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al crear categoría: $e')),
                      );
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

    try {
      // Optimistically update UI first
      setState(() {
        // Find the category in our list and update its status
        final index = categories.indexWhere((c) => c["_id"] == categoryId);
        if (index != -1) {
          categories[index]["isActive"] = !currentStatus;
        }

        // Update the filtered list through our filter method
        _applyFilters();
      });

      // Call API to update status
      await _controller.updateCategory(
        categoryId,
        category["Categoria_Producto"],
        !currentStatus,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Estado de "$categoryName" actualizado a ${!currentStatus ? 'activo' : 'inactivo'}'),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
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
                  rows: filteredCategories.map((category) {
                    final mongoId = category['_id'] as String;
                    final nombre =
                        category["Categoria_Producto"] ?? 'Desconocida';
                    final isActive = category["isActive"] as bool? ?? false;

                    return DataRow(
                      cells: [
                        // Foto cell
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
                        // Category name cell
                        DataCell(Text(nombre)),
                        // Status Cell with Switch instead of Chip
                        DataCell(
                          Row(
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (newValue) {
                                  _toggleCategoryStatus(category);
                                },
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.shade300,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 8),
                              Text(isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.red.shade700)),
                            ],
                          ),
                        ),
                        // Actions Cell
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button - Removed border, keep blue icon
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
                              // Delete Button - Removed border, keep red icon
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
      ],
    );
  }
}
