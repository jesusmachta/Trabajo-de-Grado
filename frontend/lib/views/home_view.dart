import 'package:flutter/material.dart';
import 'dashboard_view.dart';
import 'statistics_view.dart';
import 'users_view.dart';
import '../controllers/statistics_controller.dart';

class HomeView extends StatefulWidget {
  final Function toggleTheme;

  const HomeView({super.key, required this.toggleTheme});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  bool _showStatisticsSubmenu = false;
  final StatisticsController _statisticsController = StatisticsController();

  // Add a global key for the statistics view using the public state class
  final GlobalKey<StatisticsViewState> _statisticsViewKey =
      GlobalKey<StatisticsViewState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardView(toggleTheme: widget.toggleTheme),
      StatisticsView(key: _statisticsViewKey, toggleTheme: widget.toggleTheme),
      UsersView(toggleTheme: widget.toggleTheme),
    ];
  }

  final List<String> _titles = [
    'Dashboard',
    'Estadísticas',
    'Gestión de Usuarios',
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: false,
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Futuro: mostrar ayuda
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard, size: 28),
              title: const Text('Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              selected: _currentIndex == 0,
              onTap: () {
                setState(() {
                  _currentIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            // Statistics ExpansionTile for vertical expansion
            ExpansionTile(
              leading: const Icon(Icons.bar_chart, size: 28),
              title: const Text('Estadísticas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              initiallyExpanded: _showStatisticsSubmenu,
              onExpansionChanged: (expanded) {
                setState(() {
                  _showStatisticsSubmenu = expanded;
                });
              },
              children:
                  _statisticsController.getStatisticsOptions().map((option) {
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 70),
                  dense: true,
                  leading: Text(
                    option['emoji'] ?? '📊',
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(option['label']!,
                      style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                    // Update statistics view with selected stat type
                    _statisticsViewKey.currentState
                        ?.updateSelectedStat(option['value']!);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, size: 28),
              title: const Text('Roles y Privilegios',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              selected: _currentIndex == 2,
              onTap: () {
                setState(() {
                  _currentIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                  isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  size: 28),
              title: Text(isDarkMode ? 'Modo claro' : 'Modo oscuro',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                widget.toggleTheme();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, size: 28),
              title: const Text('Ayuda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, size: 28),
              title: const Text('Acerca de',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, size: 28),
              title: const Text('Log out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                // Implementación pendiente
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
    );
  }
}
