import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/route_guard.dart';
import 'widgets/statistic_card.dart';
import 'statistics_view.dart';
import 'home_view.dart';

class DashboardView extends StatefulWidget {
  final Function toggleTheme;

  const DashboardView({super.key, required this.toggleTheme});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardController _controller = DashboardController();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    // Verificar autenticación al inicializar
    Future.microtask(() {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      if (!authController.isAuthenticated) {
        authController.checkAuthAndRedirect(context);
      }
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _controller.getDashboardSummary();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _testApiConnection() async {
    try {
      final message = await _controller.testApiConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;

    // Usar RouteGuard para proteger esta vista
    return RouteGuard.protect(
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar datos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _buildDashboardContent(),
      toggleTheme: widget.toggleTheme,
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del dashboard
          StatisticCard(
            title: 'Bienvenido a StoreSense',
            icon: Icons.storefront,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema inteligente de análisis de comportamiento de clientes',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _testApiConnection,
                  child: const Text('Probar Conexión con API'),
                ),
              ],
            ),
          ),

          // Tarjetas de acceso rápido
          Row(
            children: [
              Expanded(
                child: StatisticCard(
                  title: 'Estadísticas',
                  icon: Icons.bar_chart,
                  iconColor: Theme.of(context).colorScheme.primary,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accede a todas las estadísticas del sistema',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          // Ir a Estadísticas desde el botón de navegación
                          if (context
                                  .findAncestorWidgetOfExactType<Scaffold>() !=
                              null) {
                            Scaffold.of(context).openDrawer();
                          }
                        },
                        child: const Text('Ver Estadísticas'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatisticCard(
                  title: 'Documentación',
                  icon: Icons.description,
                  iconColor: Theme.of(context).colorScheme.primary,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consulta la documentación del sistema',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          // Futuro: Abrir documentación
                        },
                        child: const Text('Ver Documentación'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Sección adicional
          StatisticCard(
            title: 'Análisis en Tiempo Real',
            icon: Icons.analytics,
            iconColor: Theme.of(context).colorScheme.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información sobre el comportamiento de los clientes en la tienda con análisis avanzado de datos',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                                Theme.of(context).colorScheme.primary,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
