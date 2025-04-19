import 'package:flutter/material.dart';
import '../controllers/categories_controller.dart';

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
        filteredCategories = categoryData;
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

  void _filterCategories(String query) {
    setState(() {
      searchQuery = query;
      filteredCategories = categories
          .where((category) => category["Categoria_Producto"]
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
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
        await _loadCategories();

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
                      await _loadCategories();

                      // Aplicamos el filtro otra vez
                      _filterCategories(searchQuery);

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
                      await _loadCategories();

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
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 300,
                child: TextField(
                  onChanged: _filterCategories,
                  decoration: InputDecoration(
                    hintText: 'Buscar categorías...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor:
                        theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: _buildCategoriesTable(),
                    ),
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
                        // Status Cell with Chip
                        DataCell(
                          Chip(
                            label: Text(
                              isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.green.shade900
                                    : Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            backgroundColor: isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        // Actions Cell
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button
                              Tooltip(
                                message: 'Editar Categoría',
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.white),
                                    iconSize: 22,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    tooltip: 'Editar',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _showEditCategoryModal(category),
                                  ),
                                ),
                              ),
                              // Delete Button
                              Tooltip(
                                message: 'Eliminar Categoría',
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.white),
                                    iconSize: 22,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    tooltip: 'Eliminar',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _deleteCategory(category),
                                  ),
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
