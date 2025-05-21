import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'views/home_view.dart';
import 'views/login_view.dart';
import 'views/dashboard_view.dart';
import 'controllers/auth_controller.dart';
import 'controllers/user_controller.dart';
import 'controllers/chat_controller.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'views/help_view.dart';
import 'views/about_view.dart';
import 'views/company_view.dart';

// Create a global theme controller
final themeController = StreamController<ThemeMode>.broadcast();

// Global GoRouter instance for routing
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => AuthWrapper(toggleTheme: () {
        // Toggle theme globally through the stream controller
        final currentMode = Theme.of(context).brightness == Brightness.light
            ? ThemeMode.dark
            : ThemeMode.light;
        themeController.add(currentMode);
      }),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => AuthWrapper(toggleTheme: () {
        final currentMode = Theme.of(context).brightness == Brightness.light
            ? ThemeMode.dark
            : ThemeMode.light;
        themeController.add(currentMode);
      }),
    ),
    GoRoute(
      path: '/statistics',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'statistics',
        initialStat: state.uri.queryParameters['stat'],
      ),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'categories',
      ),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'users',
      ),
    ),
    GoRoute(
      path: '/cameras',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'cameras',
      ),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'chat',
      ),
    ),
    GoRoute(
      path: '/heatmap',
      builder: (context, state) => AuthWrapper(
        toggleTheme: () {
          final currentMode = Theme.of(context).brightness == Brightness.light
              ? ThemeMode.dark
              : ThemeMode.light;
          themeController.add(currentMode);
        },
        initialView: 'heatmap',
      ),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpView(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutView(),
    ),
    GoRoute(
      path: '/company',
      builder: (context, state) => const CompanyView(),
    ),
  ],
);

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize date formatting
  initializeDateFormatting('es_ES').then((_) {
    Intl.defaultLocale = 'es_ES';
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AuthController()),
          ChangeNotifierProvider(create: (context) => UserController()),
          ChangeNotifierProxyProvider<AuthController, ChatController>(
            create: (context) => ChatController(
                Provider.of<AuthController>(context, listen: false)),
            update: (context, auth, previousChatController) {
              if (previousChatController == null) {
                return ChatController(auth);
              }
              return previousChatController;
            },
          ),
        ],
        child: const MyApp(),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late StreamSubscription _themeSub;

  // Color azul claro para el tema claro
  static const Color lightBlue = Color(0xFFE1F5FF);
  // Color azul oscuro/océano para el tema oscuro
  static const Color darkBlue = Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();

    // Listen for theme changes
    _themeSub = themeController.stream.listen((newThemeMode) {
      setState(() {
        _themeMode = newThemeMode;
      });
    });
  }

  @override
  void dispose() {
    _themeSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'StoreSense',
      debugShowCheckedModeBanner: false,
      // Add a builder to allow overlays for toast notifications
      builder: (context, child) {
        // Ensure we have an overlay for toast notifications
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) {
                // Apply app icon to top level
                if (child != null) {
                  final mediaQueryData = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQueryData,
                    child: child,
                  );
                }
                return Container();
              },
            ),
          ],
        );
      },
      // Tema claro con azul E1F5FF
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightBlue,
          brightness: Brightness.light,
          primary: Color(0xFF0277BD),
          primaryContainer: lightBlue,
          surface: Colors.white,
          background: Colors.white,
          surfaceVariant: lightBlue.withOpacity(0.7),
        ),
        scaffoldBackgroundColor: Colors.white,
        // Personalización de texto para Material 3
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        // Configuración para los componentes
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: lightBlue,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // Configuración para los botones
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0277BD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF0277BD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF0277BD),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Configuración para los inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightBlue.withOpacity(0.3),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF0277BD), width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightBlue.withOpacity(0.5),
          indicatorColor: Color(0xFF0277BD).withOpacity(0.2),
        ),
      ),
      // Tema oscuro con azul océano
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkBlue,
          brightness: Brightness.dark,
          primary: Color(0xFF64B5F6),
          primaryContainer: darkBlue,
          surface: Color(0xFF121212),
          background: Color(0xFF121212),
          surfaceVariant: darkBlue.withOpacity(0.3),
          onSurface: Colors.white,
          onBackground: Colors.white,
          secondary: Color(0xFF81D4FA),
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: Color(0xFF121212),
        // Personalización de texto para Material 3
        textTheme: const TextTheme(
          displayLarge:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          displaySmall:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          headlineLarge:
              TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          headlineMedium:
              TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          titleLarge:
              TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white),
          labelSmall: TextStyle(color: Colors.white),
        ),
        // Configuración para los componentes
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFF0D2B4E),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          color: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // Configuración para los botones
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF64B5F6),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF42A5F5),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF64B5F6),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Configuración para los inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2C3A47),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF64B5F6), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white54),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Color(0xFF0D2B4E),
          indicatorColor: Color(0xFF64B5F6).withOpacity(0.3),
          labelTextStyle: MaterialStateProperty.all(
            TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          iconTheme: MaterialStateProperty.all(
            IconThemeData(color: Colors.white),
          ),
        ),
        listTileTheme: ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Color(0xFF2C3A47),
          textStyle: TextStyle(color: Colors.white),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: Colors.white),
          menuStyle: MenuStyle(
            backgroundColor: MaterialStateProperty.all(Color(0xFF2C3A47)),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white24,
        ),
      ),
      themeMode: _themeMode,
    );
  }
}

// New Widget: AuthWrapper
// This widget checks the authentication state and displays the appropriate view.
class AuthWrapper extends StatelessWidget {
  final Function toggleTheme;
  final String? initialView;
  final String? initialStat;

  const AuthWrapper({
    super.key,
    required this.toggleTheme,
    this.initialView,
    this.initialStat,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to AuthController changes
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // Show loading indicator while initializing
        if (authController.isInitializing) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Validar token al iniciar, pero solo una vez al cargar la aplicación
        if (authController.isAuthenticated) {
          // Usamos microtask para que la validación ocurra después del render
          // pero evitamos que se repita en cada reconstrucción
          Future.microtask(() async {
            // Primero validar el token
            await authController.validateToken();

            // Si seguimos autenticados después de validar, refrescar datos de usuario
            if (authController.isAuthenticated) {
              print('Refreshing user data on app start');
              await authController.refreshUserData();
            }
          });
        }

        // After initialization, decide which view to show
        if (authController.isAuthenticated) {
          // User is authenticated -> Show HomeView with initialView parameter
          return HomeView(
            toggleTheme: toggleTheme,
            initialView: initialView,
            initialStat: initialStat,
          );
        } else {
          // User is not authenticated -> Show LoginView
          return LoginView(toggleTheme: toggleTheme);
        }
      },
    );
  }
}
