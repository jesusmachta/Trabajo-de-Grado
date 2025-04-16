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
  List<String> categories = [];
  bool isLoading = true;

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
      setState(() {
        categories = data;
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(
        title: const Text('Categories',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        toolbarHeight: 90,
        actions: [
          IconButton(
            icon: Icon(
                isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
            tooltip:
                isDarkMode ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
            onPressed: () {
              widget.toggleTheme();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.4,
                      children: categories.map((cat) {
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Expanded(
                                  child: Text(
                                    '',
                                    style: TextStyle(
                                        fontSize: 15, color: Colors.black87),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    child: const Text('See details'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add),
      ),
    );
  }
}
