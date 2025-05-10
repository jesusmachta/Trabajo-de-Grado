import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
  final String? initialView;

  const HomeView({
    super.key,
    required this.toggleTheme,
    this.initialView,
  });

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

      // Set the initial view if specified via the URL route
      if (widget.initialView != null) {
        // Set initial view based on route parameter
        switch (widget.initialView) {
          case 'statistics':
            setState(() {
              _currentIndex = 1;
              _showStatisticsSubmenu = true; // Show the statistics submenu
            });
            break;
          case 'users':
            setState(() {
              _currentIndex = 2;
              _showStatisticsSubmenu = false; // Hide statistics submenu
            });
            break;
          case 'categories':
            setState(() {
              _currentIndex = 3;
              _showStatisticsSubmenu = false; // Hide statistics submenu
            });
            break;
          case 'cameras':
            setState(() {
              _currentIndex = 4;
              _showStatisticsSubmenu = false; // Hide statistics submenu
            });
            break;
          default:
            setState(() {
              _currentIndex = 0;
              _showStatisticsSubmenu = false; // Hide statistics submenu
            });
        }
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

  // Navigate to a specific view and update URL
  void _navigateToView(int index) {
    setState(() {
      _currentIndex = index;

      // Hide statistics submenu if we're navigating to anything other than statistics
      if (index != 1) {
        _showStatisticsSubmenu = false;
      }
    });

    // Update the URL based on the selected view
    String path = '/';
    switch (index) {
      case 0:
        path = '/dashboard';
        break;
      case 1:
        path = '/statistics';
        break;
      case 2:
        path = '/users';
        break;
      case 3:
        path = '/categories';
        break;
      case 4:
        path = '/cameras';
        break;
    }

    // Update URL without triggering a full page reload
    GoRouter.of(context).go(path);
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
        title: Row(
          children: [
            Image.asset(
              'assets/images/storesense_logo.png',
              height: 40,
              width: 40,
            ),
            const SizedBox(width: 8),
            Text(
              'StoreSense',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF223A5E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.backgroundColor
            : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF223A5E),
        elevation: 0,
        centerTitle: false,
        actions: [
          Row(
            children: [
              Text(
                '¡Hola, $userName!',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF223A5E),
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
            // Custom header for the drawer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/storesense_logo.png',
                    height: 40,
                    width: 40,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'StoreSense',
                    style: TextStyle(
                      color: Color(0xFF223A5E),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Dashboard menu item with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () {
                  _navigateToView(0);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _currentIndex == 0
                        ? const Color(
                            0xFFE1F5FF) // Light blue background for selected item
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard,
                        size: 28,
                        color: _currentIndex == 0
                            ? const Color(0xFF223A5E)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _currentIndex == 0
                              ? const Color(0xFF223A5E)
                              : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Statistics ExpansionTile with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: _currentIndex == 1
                      ? const Color(
                          0xFFE1F5FF) // Light blue background for selected item
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(
                      Icons.bar_chart,
                      size: 28,
                      color: _currentIndex == 1
                          ? const Color(0xFF223A5E)
                          : Colors.grey[600],
                    ),
                    title: Text(
                      'Estadísticas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _currentIndex == 1
                            ? const Color(0xFF223A5E)
                            : Colors.grey[800],
                      ),
                    ),
                    initiallyExpanded: _showStatisticsSubmenu,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _showStatisticsSubmenu = expanded;
                        // Remove the automatic navigation when expanding
                        // Just toggle the visibility of the submenu
                      });
                    },
                    children: _statisticsController
                        .getStatisticsOptions()
                        .map((option) {
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

                      return Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 40),
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

                            // Update URL to statistics
                            GoRouter.of(context).go('/statistics');
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Admin menu items with custom styling
            if (Provider.of<AuthController>(context).currentUser?.role ==
                'admin') ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () {
                    _navigateToView(2);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentIndex == 2
                          ? const Color(
                              0xFFE1F5FF) // Light blue background for selected item
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 28,
                          color: _currentIndex == 2
                              ? const Color(0xFF223A5E)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Roles y Privilegios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _currentIndex == 2
                                ? const Color(0xFF223A5E)
                                : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () {
                    _navigateToView(3);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentIndex == 3
                          ? const Color(
                              0xFFE1F5FF) // Light blue background for selected item
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 28,
                          color: _currentIndex == 3
                              ? const Color(0xFF223A5E)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Categorías',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _currentIndex == 3
                                ? const Color(0xFF223A5E)
                                : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () {
                    _navigateToView(4);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentIndex == 4
                          ? const Color(
                              0xFFE1F5FF) // Light blue background for selected item
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 28,
                          color: _currentIndex == 4
                              ? const Color(0xFF223A5E)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Cámaras',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _currentIndex == 4
                                ? const Color(0xFF223A5E)
                                : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const Divider(height: 32),

            // Theme switch with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () {
                  // Cerrar el drawer inmediatamente
                  Navigator.pop(context);

                  // Comunicar directamente con el controlador de tema global
                  // para cambiar el tema inmediatamente
                  final newMode =
                      Theme.of(context).brightness == Brightness.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                  themeController.add(newMode);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDarkMode
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_round,
                        size: 28,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        isDarkMode ? 'Modo claro' : 'Modo oscuro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Help button with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context); // Cerrar el drawer
                  // Navegar a la vista de Ayuda
                  GoRouter.of(context).push('/help');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 28,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Ayuda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // About button with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context); // Cerrar el drawer
                  // Navegar a la vista de Acerca de
                  GoRouter.of(context).push('/about');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 28,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Acerca de',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 32),

            // Logout button with custom styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () async {
                  // Cerrar el drawer primero
                  Navigator.pop(context);

                  // Ejecutar logout
                  await Provider.of<AuthController>(context, listen: false)
                      .logout();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        size: 28,
                        color: Colors.red[400],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Log out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
