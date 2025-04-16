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
      final data = await _controller.getCategories();
      final List<Map<String, dynamic>> categoryData = data.map((category) {
        return {
          'name': category,
          'isActive': true,
          'photo': null,
        };
      }).toList();

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
          .where((category) =>
              category['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _editCategory(Map<String, dynamic> category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editar categoría: ${category['name']}')),
    );
  }

  void _deleteCategory(Map<String, dynamic> category) {
    setState(() {
      categories.remove(category);
      filteredCategories.remove(category);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoría eliminada: ${category['name']}')),
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
                        constraints: const BoxConstraints(
                            maxWidth: 1000), // Reducir el ancho máximo
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal:
                                  8.0), // Márgenes laterales más pequeños
                          child: DataTable(
                            dividerThickness:
                                1, // Grosor de las líneas horizontales
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                return theme.colorScheme.surfaceVariant
                                    .withOpacity(0.1); // Color gris suave
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
                            columnSpacing: MediaQuery.of(context).size.width *
                                0.04, // Espaciado dinámico entre columnas
                            columns: const [
                              DataColumn(label: Text('Foto')),
                              DataColumn(label: Text('Nombre')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: filteredCategories.map((category) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: category['photo'] != null
                                          ? NetworkImage(category['photo'])
                                          : null,
                                      child: category['photo'] == null
                                          ? Icon(Icons.category,
                                              size: 20,
                                              color: theme.colorScheme.primary)
                                          : null,
                                      backgroundColor:
                                          theme.colorScheme.surfaceVariant,
                                    ),
                                  ),
                                  DataCell(Text(category['name'])),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        category['isActive']
                                            ? 'Activo'
                                            : 'Inactivo',
                                        style: TextStyle(
                                          color: category['isActive']
                                              ? Colors.green.shade900
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      backgroundColor: category['isActive']
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
                                              _editCategory(category),
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
