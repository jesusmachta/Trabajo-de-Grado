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
      // Llamar al controlador para obtener las categorías
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

  void _editCategory(Map<String, dynamic> category) {
    _showEditCategoryModal(category);
  }

  void _deleteCategory(Map<String, dynamic> category) {
    setState(() {
      categories.remove(category);
      filteredCategories.remove(category);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Categoría eliminada: ${category["Categoria_Producto"]}')),
    );
  }

  void _showEditCategoryModal(Map<String, dynamic> category) {
    final TextEditingController nameController =
        TextEditingController(text: category["Categoria_Producto"]);
    bool isActive = category["isActive"];

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
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría',
                      border: OutlineInputBorder(),
                    ),
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
                    try {
                      // Llamar al controlador para actualizar la categoría
                      await _controller.updateCategory(
                        category["_id"],
                        nameController.text,
                        isActive,
                      );

                      // Actualizar la lista de categorías
                      await _loadCategories();

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Categoría actualizada exitosamente')),
                      );
                    } catch (e) {
                      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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

          // Buscador con ancho limitado
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 300, // Ancho máximo del buscador
              child: TextField(
                onChanged: _filterCategories,
                decoration: InputDecoration(
                  hintText: 'Buscar categorías...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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

          // Tabla de categorías
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: DataTable(
                            dividerThickness: 1,
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                return theme.colorScheme.surfaceVariant
                                    .withOpacity(0.1);
                              },
                            ),
                            headingRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                return theme.colorScheme.secondaryContainer
                                    .withOpacity(0.3);
                              },
                            ),
                            headingTextStyle:
                                theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            columnSpacing:
                                MediaQuery.of(context).size.width * 0.04,
                            columns: const [
                              DataColumn(label: Text('Foto')),
                              DataColumn(label: Text('Categoría')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: filteredCategories.map((category) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    CircleAvatar(
                                      radius: 20,
                                      child: Icon(
                                        Icons.category,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      backgroundColor:
                                          theme.colorScheme.surfaceVariant,
                                    ),
                                  ),
                                  DataCell(
                                      Text(category["Categoria_Producto"])),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        category["isActive"]
                                            ? 'Activo'
                                            : 'Inactivo',
                                        style: TextStyle(
                                          color: category["isActive"]
                                              ? Colors.green.shade900
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      backgroundColor: category["isActive"]
                                          ? Colors.green.shade100
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined,
                                              color: theme.colorScheme.primary),
                                          tooltip: 'Editar categoría',
                                          onPressed: () =>
                                              _showEditCategoryModal(category),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              color: theme.colorScheme.error),
                                          tooltip: 'Eliminar categoría',
                                          onPressed: () =>
                                              _deleteCategory(category),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
