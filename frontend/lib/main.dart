import 'package:flutter/material.dart';
import 'views/home_view.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Inicializar los datos de localización para fechas
  initializeDateFormatting('es_ES').then((_) {
    Intl.defaultLocale = 'es_ES';
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  // Color azul claro para el tema claro
  static const Color lightBlue = Color(0xFFE1F5FF);
  // Color azul oscuro/océano para el tema oscuro
  static const Color darkBlue = Color(0xFF0D47A1);

  void toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoreSense',
      debugShowCheckedModeBanner: false,
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
        ),
        // Configuración para los componentes
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: darkBlue,
          foregroundColor: Colors.white,
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
          fillColor: darkBlue.withOpacity(0.2),
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
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkBlue.withOpacity(0.2),
          indicatorColor: Color(0xFF64B5F6).withOpacity(0.3),
        ),
      ),
      themeMode: _themeMode,
      home: HomeView(toggleTheme: toggleThemeMode),
    );
  }
}
