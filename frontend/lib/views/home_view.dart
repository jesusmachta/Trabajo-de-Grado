import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_view.dart';
import 'statistics_view.dart';
import 'users_view.dart';
import 'categories_view.dart';
import '../controllers/statistics_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/route_guard.dart';
import '../main.dart'; // Importar para acceder al themeController
import 'cameras_view.dart';
import 'profile_view.dart';
import '../controllers/chat_controller.dart'; // Import ChatController

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

  late List<Widget> _pages;
  late List<String> _titles;

  @override
  void initState() {
    super.initState();

    // Verificar autenticación al inicializar
    Future.microtask(() {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      if (!authController.isAuthenticated) {
        authController.checkAuthAndRedirect(context);
      }
    });
    // Inicializar _pages y _titles en didChangeDependencies para tener acceso al usuario
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = Provider.of<AuthController>(context, listen: false);
    final isAdmin = authController.currentUser?.role == 'admin';
    _pages = [
      DashboardView(toggleTheme: widget.toggleTheme),
      StatisticsView(key: _statisticsViewKey, toggleTheme: widget.toggleTheme),
      if (isAdmin) UsersView(toggleTheme: widget.toggleTheme),
      if (isAdmin) CategoriesView(toggleTheme: widget.toggleTheme),
      if (isAdmin) CamerasView(toggleTheme: widget.toggleTheme),
    ];
    _titles = [
      'Dashboard',
      'Estadísticas',
      if (isAdmin) 'Gestión de Usuarios',
      if (isAdmin) 'Categorías',
      if (isAdmin) 'Gestión de Cámaras',
    ];
    // Si el usuario no es admin y el índice actual es > 1, volver al dashboard
    if (!isAdmin && _currentIndex > 1) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  // Helper to properly encode profile picture URLs
  String _encodeProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    print('HomeView - Original profile URL: $url');

    try {
      // Handle specific case for tesislospomelos bucket
      if (url.contains('tesislospomelos.s3.amazonaws.com')) {
        print('HomeView - Detected tesislospomelos S3 URL');

        // Direct access format for S3 - no transformation needed for this bucket
        // Just ensure proper encoding
        final encodedUrl = url.replaceAll(' ', '%20');
        print('HomeView - Encoded tesislospomelos URL: $encodedUrl');
        return encodedUrl;
      }
      // Check if it's an S3 URL
      else if (url.contains('s3.amazonaws.com')) {
        // Convert https://bucketname.s3.amazonaws.com/key to https://s3.amazonaws.com/bucketname/key format
        // This alternate format often works better with public access settings
        final uri = Uri.parse(url);
        final host = uri.host;

        if (host.endsWith('s3.amazonaws.com')) {
          // Extract bucket name from the hostname (e.g., "bucketname.s3.amazonaws.com")
          final bucketName = host.split('.').first;

          // Get the path without leading slash
          final objectKey =
              uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

          // Build URL in the alternative format
          return 'https://s3.amazonaws.com/$bucketName/$objectKey';
        }
      }

      // If not an S3 URL or already in the right format, just encode it properly
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments.map(Uri.encodeComponent).join('/');
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/$pathSegments';
    } catch (e) {
      // If URL parsing fails, fall back to basic space encoding
      print('Error encoding URL in HomeView: $e');
      return url.replaceAll(' ', '%20');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final String userName = currentUser?.fullName.split(' ')[0] ?? 'Usuario';

    // Encode profile picture URL if exists
    final String? encodedProfilePictureUrl = currentUser?.profilePicture != null
        ? _encodeProfilePictureUrl(currentUser!.profilePicture)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StoreSense',
          style: const TextStyle(
            color: Color(0xFF223A5E),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF223A5E),
        elevation: 0,
        centerTitle: false,
        actions: [
          Row(
            children: [
              Text(
                '¡Hola, $userName!',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Color(0xFF223A5E),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 42, // Increased icon size
                icon: CircleAvatar(
                  radius: 21,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  backgroundImage: encodedProfilePictureUrl != null &&
                          encodedProfilePictureUrl.isNotEmpty
                      ? NetworkImage(encodedProfilePictureUrl,
                          headers: {'Accept': '*/*'})
                      : null,
                  child: encodedProfilePictureUrl == null ||
                          encodedProfilePictureUrl.isEmpty
                      ? Icon(Icons.person,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onBackgroundImageError: encodedProfilePictureUrl != null
                      ? (exception, stackTrace) {
                          print(
                              'Error loading profile image in header: $exception');
                          // Force a rebuild with the fallback icon on error
                          if (mounted) {
                            setState(() {
                              // Try to refresh user data from server to get updated profile URL
                              final authController =
                                  Provider.of<AuthController>(context,
                                      listen: false);
                              authController.refreshUserData();
                            });
                          }
                        }
                      : null,
                ),
                tooltip: 'Perfil',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileView()),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Chatbot Toggle Button
              IconButton(
                icon: Icon(
                  Icons.auto_awesome, // Sparkle icon for AI
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Abrir Chat AI',
                onPressed: () {
                  // Access ChatController and toggle the overlay
                  Provider.of<ChatController>(context, listen: false)
                      .toggleChatOverlay(context);
                },
              ),
              const SizedBox(width: 16), // Add some spacing before drawer icon
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard, size: 32),
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
              leading: const Icon(Icons.bar_chart, size: 32),
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
                // Map de valores de estadísticas a iconos apropiados
                IconData getStatIcon(String value) {
                  switch (value) {
                    case 'peak-hours':
                      return Icons.access_time;
                    case 'least-hours':
                      return Icons.hourglass_empty;
                    case 'busy-days-combined':
                      return Icons.calendar_today;
                    case 'visited-categories-combined':
                      return Icons.category;
                    case 'most-frequent-emotions':
                      return Icons.emoji_emotions;
                    case 'emotion-percentage':
                      return Icons.pie_chart;
                    case 'gender-age-combined':
                      return Icons.people;
                    case 'emotion-comparison': // Kept for compatibility
                      return Icons.compare_arrows;
                    case 'visited-categories-historical':
                      return Icons.history;
                    case 'preferred-category-by-gender':
                      return Icons.wc;
                    case 'top-successful-categories':
                      return Icons.trending_up;
                    case 'emotional-differences-by-category':
                      return Icons.mood;
                    case 'age-gender-distribution-by-category':
                      return Icons.group;
                    default:
                      return Icons.analytics;
                  }
                }

                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 70),
                  dense: true,
                  leading: Icon(
                    getStatIcon(option['value']!),
                    color: Colors.grey,
                    size: 20,
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
            // Solo mostrar estos botones si es admin
            if (Provider.of<AuthController>(context).currentUser?.role ==
                'admin') ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, size: 32),
                title: const Text('Roles y Privilegios',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                selected: _currentIndex == 2,
                onTap: () {
                  setState(() {
                    _currentIndex = 2;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.category, size: 32),
                title: const Text('Categorías',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                selected: _currentIndex == 3,
                onTap: () {
                  setState(() {
                    _currentIndex = 3;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 32),
                title: const Text('Cámaras',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                selected: _currentIndex == 4,
                onTap: () {
                  setState(() {
                    _currentIndex = 4;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(
                  isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  size: 32),
              title: Text(isDarkMode ? 'Modo claro' : 'Modo oscuro',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                // Cerrar el drawer inmediatamente
                Navigator.pop(context);

                // Comunicar directamente con el controlador de tema global
                // para cambiar el tema inmediatamente
                final newMode = Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                themeController.add(newMode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, size: 32),
              title: const Text('Ayuda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, size: 32),
              title: const Text('Acerca de',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, size: 32),
              title: const Text('Log out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () async {
                // Cerrar el drawer primero
                Navigator.pop(context);

                // Ejecutar logout
                await Provider.of<AuthController>(context, listen: false)
                    .logout();

                // No necesitamos hacer navegación manual aquí.
                // El AuthWrapper detectará el cambio en isAuthenticated y mostrará LoginView automáticamente
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
