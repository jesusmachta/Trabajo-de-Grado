import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/route_guard.dart';
import 'widgets/statistic_card.dart';
import 'statistics_view.dart';
import 'home_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../controllers/categories_controller.dart';

// Clase para datos de porcentaje de emociones (igual que en statistics_view)
class EmotionPercentageData {
  final String emotion;
  final double percentage;

  EmotionPercentageData({
    required this.emotion,
    required this.percentage,
  });
}

// Clase para datos de gráfico de horas
class HourData {
  final String hour;
  final double count;
  final String fullLabel;

  HourData({required this.hour, required this.count, this.fullLabel = ''});
}

class DashboardView extends StatefulWidget {
  final Function toggleTheme;

  const DashboardView({super.key, required this.toggleTheme});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardController _controller = DashboardController();
  final CategoriesController _categoriesController = CategoriesController();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  Map<String, String> _categoryIconMap = {};

  // Función auxiliar para convertir nombres de iconos en objetos IconData
  IconData _getIconDataFromName(String name) {
    // Mapa de iconos - mismos que en IconDataHelper
    Map<String, IconData> iconMap = {
      'category': Icons.category,
      'shopping_basket': Icons.shopping_basket,
      'fastfood': Icons.fastfood,
      'local_drink': Icons.local_drink,
      'bakery_dining': Icons.bakery_dining,
      'restaurant': Icons.restaurant,
      'liquor': Icons.liquor,
      'local_mall': Icons.local_mall,
      'checkroom': Icons.checkroom,
      'diamond': Icons.diamond,
      'watch': Icons.watch,
      'devices': Icons.devices,
      'phone_android': Icons.phone_android,
      'tv': Icons.tv,
      'laptop': Icons.laptop,
      'headphones': Icons.headphones,
      'camera_alt': Icons.camera_alt,
      'sports_basketball': Icons.sports_basketball,
      'sports_soccer': Icons.sports_soccer,
      'sports_tennis': Icons.sports_tennis,
      'fitness_center': Icons.fitness_center,
      'home': Icons.home,
      'bed': Icons.bed,
      'chair': Icons.chair,
      'kitchen': Icons.kitchen,
      'format_paint': Icons.format_paint,
      'toys': Icons.toys,
      'pets': Icons.pets,
      'child_friendly': Icons.child_friendly,
      'book': Icons.book,
      'auto_stories': Icons.auto_stories,
      'medical_services': Icons.medical_services,
      'spa': Icons.spa,
      'shopping_bag': Icons.shopping_bag,
      'cookie': Icons.cookie,
      'wine_bar': Icons.wine_bar,
      'egg': Icons.egg,
      'cleaning_services': Icons.cleaning_services,
      'breakfast_dining': Icons.breakfast_dining,
      'ac_unit': Icons.ac_unit,
      'star': Icons.star,
    };

    return iconMap[name] ?? Icons.category;
  }

  // Helper function to get category icon
  IconData getCategoryIcon(String category) {
    // Primero buscar en nuestro mapa de iconos personalizados
    final String iconName =
        _categoryIconMap[category.toLowerCase()] ?? 'category';

    // Usar el auxiliar para obtener el IconData
    return _getIconDataFromName(iconName);
  }

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
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      // Cargar categorías primero
      final categories = await _categoriesController.getCategories(token);

      // Crear mapa de categoría a icono
      final Map<String, String> iconMap = {};
      for (var category in categories) {
        final String name = category['Categoria_Producto'] ?? '';
        final String icon = category['icon'] ?? 'category';
        if (name.isNotEmpty) {
          iconMap[name.toLowerCase()] = icon;
        }
      }

      // Cargar datos del dashboard
      final data = await _controller.getAllDashboardStatistics(token);

      setState(() {
        _categories = categories;
        _categoryIconMap = iconMap;
        _dashboardData = data;
        _isLoading = false;
      });

      print('Dashboard data loaded successfully');
    } catch (e) {
      print('Error loading dashboard data: $e');
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadDashboardData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
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
          // Dashboard title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Panel de Estadísticas Históricas',
                  style: const TextStyle(
                    color: Color(0xFF223A5E),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                  onPressed: _loadDashboardData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Main content grid - First row with traffic charts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Peak hours chart
              Expanded(
                child: _buildPeakHoursChart(),
              ),
              const SizedBox(width: 16),
              // Least hours chart
              Expanded(
                child: _buildLeastHoursChart(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Second row with days and weekly calendar
          _buildBusyDaysAndCalendar(),

          const SizedBox(height: 16),

          // Third row with categories and emotions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories visited
              Expanded(
                child: _buildVisitedCategories(),
              ),
              const SizedBox(width: 16),
              // Emotions detected
              Expanded(
                child: _buildEmotionsDetected(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Fourth row with preferred categories by gender and top categories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preferred categories by gender
              Expanded(
                child: _buildPreferredCategoriesByGender(),
              ),
              const SizedBox(width: 16),
              // Top categories
              Expanded(
                child: _buildTopCategories(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    if (_dashboardData == null || !_dashboardData!.containsKey('peakHours')) {
      return _buildEmptyStateCard(
        title: 'Horas con mayor afluencia de clientes',
        icon: Icons.insights_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }

    final data = _dashboardData!['peakHours'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is Map && (data['data'] as Map).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Horas con mayor afluencia de clientes',
        icon: Icons.insights_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }

    final hourData = data['data'] as Map<String, dynamic>;

    // Convert data for the chart
    final List<HourData> chartData = [];

    // Traducir días de inglés a español
    final Map<String, String> dayTranslations = {
      'Monday': 'Lunes',
      'Tuesday': 'Martes',
      'Wednesday': 'Miércoles',
      'Thursday': 'Jueves',
      'Friday': 'Viernes',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo'
    };

    // Ordenar las horas para mostrarlas cronológicamente
    final sortedEntries = hourData.entries.toList();
    sortedEntries.sort((a, b) {
      final String dayA = a.key.toString();
      final String dayB = b.key.toString();

      // Orden de los días de la semana
      final dayOrder = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7
      };

      return dayOrder[dayA]!.compareTo(dayOrder[dayB]!);
    });

    for (var entry in sortedEntries) {
      final String dayEn = entry.key.toString();
      final String dayEs = dayTranslations[dayEn] ?? dayEn;
      final int hourValue = (entry.value is int)
          ? entry.value
          : int.tryParse(entry.value.toString()) ?? 0;

      chartData.add(HourData(
          hour: dayEs, // Solo el día para el eje X
          count:
              hourValue.toDouble(), // La hora como valor numérico para el eje Y
          fullLabel:
              "$dayEs a las ${hourValue.toString().padLeft(2, '0')}:00" // Etiqueta completa para las tarjetas
          ));
    }

    // Obtener colores para el gráfico
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = primaryColor.withOpacity(0.7);
    final Color surfaceColor = Theme.of(context).colorScheme.surface;

    return StatisticCard(
      title: 'Horas con mayor afluencia de clientes',
      icon: Icons.trending_up,
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(builder: (context, constraints) {
          // Adjust chart based on available width
          double chartHeight = constraints.maxWidth > 600 ? 300 : 250;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Horas con mayor afluencia de clientes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                width: constraints.maxWidth,
                child: SfCartesianChart(
                  margin: const EdgeInsets.all(8),
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    title: AxisTitle(
                      text: 'Día de la semana',
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: AxisLine(
                      width: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                    labelIntersectAction: AxisLabelIntersectAction.rotate45,
                    labelRotation: constraints.maxWidth < 400 ? 45 : 0,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(
                      text: 'Hora del día',
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    labelFormat: '{value}:00',
                    minimum: 0,
                    maximum: 24,
                    interval: 4,
                    majorGridLines: MajorGridLines(
                      width: 0.5,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                      dashArray: const <double>[5, 5],
                    ),
                    axisLine: AxisLine(
                      width: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  legend: Legend(isVisible: false),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'Día: {point.x}\nHora: {point.y}:00',
                    color: Theme.of(context).colorScheme.primaryContainer,
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    duration: 2500,
                    animationDuration: 500,
                  ),
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    tooltipSettings: InteractiveTooltip(
                      enable: true,
                      color: surfaceColor,
                      borderColor: primaryColor,
                      borderWidth: 1.5,
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    lineType: TrackballLineType.vertical,
                    lineColor: primaryColor.withOpacity(0.5),
                    lineWidth: 1,
                    markerSettings: const TrackballMarkerSettings(
                      markerVisibility: TrackballVisibilityMode.visible,
                      height: 10,
                      width: 10,
                      borderWidth: 1,
                    ),
                  ),
                  series: <CartesianSeries>[
                    // Línea brillante en primer plano
                    SplineSeries<HourData, String>(
                      dataSource: chartData,
                      xValueMapper: (HourData data, _) => data.hour,
                      yValueMapper: (HourData data, _) => data.count,
                      name: 'Horas',
                      color: primaryColor,
                      width: 3,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        height: 8,
                        width: 8,
                        shape: DataMarkerType.circle,
                        borderWidth: 2,
                        borderColor: primaryColor,
                        color: surfaceColor,
                      ),
                      animationDuration: 1500,
                      enableTooltip: true,
                    ),
                    // Área con gradiente para efecto de profundidad
                    SplineAreaSeries<HourData, String>(
                      dataSource: chartData,
                      xValueMapper: (HourData data, _) => data.hour,
                      yValueMapper: (HourData data, _) => data.count,
                      name: 'Área',
                      borderWidth: 0,
                      animationDuration: 1800,
                      borderDrawMode: BorderDrawMode.top,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.7),
                          primaryColor.withOpacity(0.5),
                          primaryColor.withOpacity(0.2),
                          primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      enableTooltip: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Leyenda para los puntos de datos
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: chartData.map((data) {
                  return Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      data.fullLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }),
      ),
      expanded: false,
      height: 400,
    );
  }

  Widget _buildLeastHoursChart() {
    if (_dashboardData == null || !_dashboardData!.containsKey('leastHours')) {
      return _buildEmptyStateCard(
        title: 'Horas con menor afluencia de clientes',
        icon: Icons.trending_down,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }

    final data = _dashboardData!['leastHours'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is Map && (data['data'] as Map).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Horas con menor afluencia de clientes',
        icon: Icons.trending_down,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }

    final hourData = data['data'] as Map<String, dynamic>;

    // Convert data for the chart
    final List<HourData> chartData = [];

    // Traducir días de inglés a español
    final Map<String, String> dayTranslations = {
      'Monday': 'Lunes',
      'Tuesday': 'Martes',
      'Wednesday': 'Miércoles',
      'Thursday': 'Jueves',
      'Friday': 'Viernes',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo'
    };

    // Ordenar las horas para mostrarlas cronológicamente
    final sortedEntries = hourData.entries.toList();
    sortedEntries.sort((a, b) {
      final String dayA = a.key.toString();
      final String dayB = b.key.toString();

      // Orden de los días de la semana
      final dayOrder = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7
      };

      return dayOrder[dayA]!.compareTo(dayOrder[dayB]!);
    });

    for (var entry in sortedEntries) {
      final String dayEn = entry.key.toString();
      final String dayEs = dayTranslations[dayEn] ?? dayEn;
      final int hourValue = (entry.value is int)
          ? entry.value
          : int.tryParse(entry.value.toString()) ?? 0;

      chartData.add(HourData(
          hour: dayEs, // Solo el día para el eje X
          count:
              hourValue.toDouble(), // La hora como valor numérico para el eje Y
          fullLabel:
              "$dayEs a las ${hourValue.toString().padLeft(2, '0')}:00" // Etiqueta completa para las tarjetas
          ));
    }

    // Color para menor afluencia
    final Color tealColor = Colors.teal;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;

    return StatisticCard(
      title: 'Horas con menor afluencia de clientes',
      icon: Icons.trending_down,
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(builder: (context, constraints) {
          // Adjust chart based on available width
          double chartHeight = constraints.maxWidth > 600 ? 300 : 250;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Horas con menor afluencia de clientes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tealColor,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                width: constraints.maxWidth,
                child: SfCartesianChart(
                  margin: const EdgeInsets.all(8),
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    title: AxisTitle(
                      text: 'Día de la semana',
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: AxisLine(
                      width: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                    labelIntersectAction: AxisLabelIntersectAction.rotate45,
                    labelRotation: constraints.maxWidth < 400 ? 45 : 0,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(
                      text: 'Hora del día',
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    labelFormat: '{value}:00',
                    minimum: 0,
                    maximum: 24,
                    interval: 4,
                    majorGridLines: MajorGridLines(
                      width: 0.5,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                      dashArray: const <double>[5, 5],
                    ),
                    axisLine: AxisLine(
                      width: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  legend: Legend(isVisible: false),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'Día: {point.x}\nHora: {point.y}:00',
                    color: Colors.teal.shade100,
                    textStyle: TextStyle(
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                    duration: 2500,
                    animationDuration: 500,
                  ),
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    tooltipSettings: InteractiveTooltip(
                      enable: true,
                      color: surfaceColor,
                      borderColor: tealColor,
                      borderWidth: 1.5,
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    lineType: TrackballLineType.vertical,
                    lineColor: tealColor.withOpacity(0.5),
                    lineWidth: 1,
                    markerSettings: const TrackballMarkerSettings(
                      markerVisibility: TrackballVisibilityMode.visible,
                      height: 10,
                      width: 10,
                      borderWidth: 1,
                    ),
                  ),
                  series: <CartesianSeries>[
                    // Línea brillante en primer plano
                    SplineSeries<HourData, String>(
                      dataSource: chartData,
                      xValueMapper: (HourData data, _) => data.hour,
                      yValueMapper: (HourData data, _) => data.count,
                      name: 'Horas',
                      color: tealColor,
                      width: 3,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        height: 8,
                        width: 8,
                        shape: DataMarkerType.circle,
                        borderWidth: 2,
                        borderColor: tealColor,
                        color: surfaceColor,
                      ),
                      animationDuration: 1500,
                      enableTooltip: true,
                    ),
                    // Área con gradiente para efecto de profundidad
                    SplineAreaSeries<HourData, String>(
                      dataSource: chartData,
                      xValueMapper: (HourData data, _) => data.hour,
                      yValueMapper: (HourData data, _) => data.count,
                      name: 'Área',
                      borderWidth: 0,
                      animationDuration: 1800,
                      borderDrawMode: BorderDrawMode.top,
                      gradient: LinearGradient(
                        colors: [
                          tealColor.withOpacity(0.7),
                          tealColor.withOpacity(0.5),
                          tealColor.withOpacity(0.2),
                          tealColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      enableTooltip: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Leyenda para los puntos de datos
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: chartData.map((data) {
                  return Container(
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tealColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      data.fullLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }),
      ),
      expanded: false,
      height: 400,
    );
  }

  Widget _buildEmotionsDetected() {
    if (_dashboardData == null ||
        !_dashboardData!.containsKey('emotionPercentageByCategory')) {
      return _buildEmptyStateCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 340,
      );
    }

    final data = _dashboardData!['emotionPercentageByCategory'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is Map && (data['data'] as Map).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 340,
      );
    }

    final Map<String, dynamic> categoryData =
        data['data'] as Map<String, dynamic>;
    if (categoryData.isEmpty) {
      return const StatisticCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions,
        content: Center(child: Text('No se encontraron datos de emociones')),
        expanded: false,
        height: 300,
      );
    }

    // Construir los datos para el gráfico: porcentaje de HAPPY por categoría
    final List<EmotionPercentageData> chartData = [];
    categoryData.forEach((category, emotions) {
      double happy = 0;
      if (emotions is Map<String, dynamic> && emotions.containsKey('HAPPY')) {
        final value = emotions['HAPPY'];
        if (value is num) happy = value.toDouble();
      }
      chartData
          .add(EmotionPercentageData(emotion: category, percentage: happy));
    });
    if (chartData.isEmpty) {
      return const StatisticCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions,
        content: Center(child: Text('No se encontraron datos de emociones')),
        expanded: false,
        height: 300,
      );
    }

    // Colores bonitos de Material para las categorías
    final List<Color> materialColors = [
      Colors.blue,
      Colors.amber,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
      Colors.deepPurple,
      Colors.lightBlue,
      Colors.brown,
    ];

    Color getCategoryColor(int index) =>
        materialColors[index % materialColors.length];

    return StatisticCard(
      title: 'Porcentaje de clientes felices por categoría',
      icon: Icons.emoji_emotions,
      content: Column(
        children: [
          SizedBox(
            height: 220,
            child: SfCircularChart(
              margin: EdgeInsets.zero,
              legend: Legend(isVisible: false),
              series: <CircularSeries<EmotionPercentageData, String>>[
                DoughnutSeries<EmotionPercentageData, String>(
                  dataSource: chartData,
                  xValueMapper: (EmotionPercentageData data, _) => data.emotion,
                  yValueMapper: (EmotionPercentageData data, _) =>
                      data.percentage,
                  pointColorMapper: (EmotionPercentageData data, idx) =>
                      getCategoryColor(idx!),
                  dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside),
                  dataLabelMapper: (EmotionPercentageData data, _) =>
                      '${data.emotion}: ${data.percentage.toStringAsFixed(1)}%',
                  enableTooltip: true,
                  innerRadius: '60%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: List.generate(chartData.length, (i) {
              final entry = chartData[i];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: getCategoryColor(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.emotion}: ${entry.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
      expanded: false,
      height: 340,
    );
  }

  Widget _buildBusyDaysAndCalendar() {
    if (_dashboardData == null || !_dashboardData!.containsKey('busyDays')) {
      return _buildEmptyStateCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }
    final busyDaysData = _dashboardData!['busyDays'] as Map<String, dynamic>?;
    if (busyDaysData == null ||
        busyDaysData['most_busy_day'] == null ||
        busyDaysData['least_busy_day'] == null ||
        busyDaysData['most_busy_day'] == 'No disponible' ||
        busyDaysData['least_busy_day'] == 'No disponible') {
      return _buildEmptyStateCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 400,
      );
    }

    // Traducción de días
    final Map<String, String> dayTranslations = {
      'Monday': 'Lunes',
      'Tuesday': 'Martes',
      'Wednesday': 'Miércoles',
      'Thursday': 'Jueves',
      'Friday': 'Viernes',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo',
    };
    final String mostBusyDayName =
        dayTranslations[busyDaysData['most_busy_day']] ??
            busyDaysData['most_busy_day'] ??
            'No disponible';
    final String leastBusyDayName =
        dayTranslations[busyDaysData['least_busy_day']] ??
            busyDaysData['least_busy_day'] ??
            'No disponible';
    // Semana actual (7 días hasta hoy)
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    final List<Map<String, dynamic>> pastWeekDaysInfo = [];
    for (int i = 0; i < 7; i++) {
      final date = weekAgo.add(Duration(days: i));
      String weekdayName;
      switch (date.weekday) {
        case 1:
          weekdayName = 'Lunes';
          break;
        case 2:
          weekdayName = 'Martes';
          break;
        case 3:
          weekdayName = 'Miércoles';
          break;
        case 4:
          weekdayName = 'Jueves';
          break;
        case 5:
          weekdayName = 'Viernes';
          break;
        case 6:
          weekdayName = 'Sábado';
          break;
        case 7:
          weekdayName = 'Domingo';
          break;
        default:
          weekdayName = '';
      }
      String initialLetter;
      switch (date.weekday) {
        case 1:
          initialLetter = 'L';
          break;
        case 2:
          initialLetter = 'M';
          break;
        case 3:
          initialLetter = 'M';
          break;
        case 4:
          initialLetter = 'J';
          break;
        case 5:
          initialLetter = 'V';
          break;
        case 6:
          initialLetter = 'S';
          break;
        case 7:
          initialLetter = 'D';
          break;
        default:
          initialLetter = '';
      }
      pastWeekDaysInfo.add({
        'letter': initialLetter,
        'full': weekdayName,
        'date': date.day,
        'isMostBusy': weekdayName == mostBusyDayName,
        'isLeastBusy': weekdayName == leastBusyDayName,
      });
    }
    return StatisticCard(
      title: 'Días de la semana con más y menos afluencia',
      icon: Icons.calendar_month,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Días de la Semana con Más y Menos Afluencia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Calendario Semanal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: pastWeekDaysInfo.map((dayInfo) {
                      final bool isMostBusy = dayInfo['isMostBusy'];
                      final bool isLeastBusy = dayInfo['isLeastBusy'];
                      Color? bgColor;
                      if (isMostBusy) {
                        bgColor = const Color(0xFFE8F5E9);
                      } else if (isLeastBusy) {
                        bgColor = const Color(0xFFFFF3E0);
                      }
                      return Column(
                        children: [
                          Text(
                            dayInfo['letter'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isMostBusy
                                  ? Colors.green[700]
                                  : isLeastBusy
                                      ? Colors.orange[700]
                                      : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dayInfo['full'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: isMostBusy || isLeastBusy
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              dayInfo['date'].toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isMostBusy || isLeastBusy
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Día Más Concurrido',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          mostBusyDayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Día Menos Concurrido',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          leastBusyDayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      expanded: false,
      height: 400,
    );
  }

  Widget _buildVisitedCategories() {
    if (_dashboardData == null ||
        !_dashboardData!.containsKey('visitedCategories')) {
      return _buildEmptyStateCard(
        title: 'Categorías visitadas',
        icon: Icons.category_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }

    final data = _dashboardData!['visitedCategories'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is Map && (data['data'] as Map).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Categorías visitadas',
        icon: Icons.category_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }

    final categoriesData = data['data'] as Map<String, dynamic>;

    // Extract category data
    final String mostVisitedCategory =
        categoriesData['most_visited_category'] ?? 'No disponible';
    final int mostVisitedCount = categoriesData['most_visited_count'] ?? 0;
    final String leastVisitedCategory =
        categoriesData['least_visited_category'] ?? 'No disponible';
    final int leastVisitedCount = categoriesData['least_visited_count'] ?? 0;

    return StatisticCard(
      title: 'Categorías visitadas',
      icon: Icons.category,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Most visited category
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Más Visitada',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getCategoryIcon(mostVisitedCategory),
                      color: Theme.of(context).colorScheme.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mostVisitedCategory,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$mostVisitedCount visitas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Least visited category
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Menos Visitada',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getCategoryIcon(leastVisitedCategory),
                      color: Colors.amber.shade800,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    leastVisitedCategory,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$leastVisitedCount visitas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      expanded: false,
      height: 300,
    );
  }

  Widget _buildPreferredCategoriesByGender() {
    if (_dashboardData == null ||
        !_dashboardData!.containsKey('preferredCategoriesByGender')) {
      return _buildEmptyStateCard(
        title: 'Categorías preferidas por sexo',
        icon: Icons.category_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }
    final data = _dashboardData!['preferredCategoriesByGender'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is Map && (data['data'] as Map).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Categorías preferidas por sexo',
        icon: Icons.category_outlined,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }
    final genderPreferencesData = data['data'] as Map<String, dynamic>;
    // Extraer correctamente los datos de 'Male' y 'Female'
    final malePreference = genderPreferencesData['Male'] ?? {};
    final femalePreference = genderPreferencesData['Female'] ?? {};

    Widget buildGenderCard(
        String gender, Map data, Color color, IconData icon) {
      final String category = data['category'] ?? 'No disponible';
      final int count = data['count'] ?? 0;
      return Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(gender,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 16),
            Icon(getCategoryIcon(category), color: color, size: 48),
            const SizedBox(height: 8),
            Text(category,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count visitas',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return StatisticCard(
      title: 'Categorías preferidas por sexo',
      icon: Icons.category_outlined,
      content: Row(
        children: [
          Expanded(
              child: buildGenderCard(
                  'Masculino', malePreference, Colors.blue, Icons.man)),
          const SizedBox(width: 16),
          Expanded(
              child: buildGenderCard(
                  'Femenino', femalePreference, Colors.pink, Icons.woman)),
        ],
      ),
      expanded: false,
      height: 300,
    );
  }

  Widget _buildTopCategories() {
    if (_dashboardData == null ||
        !_dashboardData!.containsKey('topCategories')) {
      return _buildEmptyStateCard(
        title: 'Top Categorías Mejor Evaluadas',
        icon: Icons.star_outline,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }

    final data = _dashboardData!['topCategories'];
    if (data is Map &&
        (data['empty'] == true ||
            data['data'] == null ||
            (data['data'] is List && (data['data'] as List).isEmpty))) {
      return _buildEmptyStateCard(
        title: 'Top Categorías Mejor Evaluadas',
        icon: Icons.star_outline,
        message:
            'Aún no hay datos para mostrar.\nSube tu primera imagen para comenzar.',
        height: 300,
      );
    }

    // Extract the data list
    final List<dynamic> topCategories = data['data'] as List<dynamic>;

    // Ensure we have at least 3 categories
    if (topCategories.length < 3) {
      return const StatisticCard(
        title: 'Top Categorías Mejor Evaluadas',
        icon: Icons.star,
        content:
            Center(child: Text('No hay suficientes categorías para mostrar')),
        expanded: false,
        height: 300,
      );
    }

    return StatisticCard(
      title: 'Top Categorías Mejor Evaluadas',
      icon: Icons.star,
      content: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Second place
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getCategoryIcon(topCategories[1]['category'] ?? 'N/A'),
                        color: Colors.grey.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '#${topCategories[1]['rank'] ?? '2'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[1]['category'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // First place (taller)
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getCategoryIcon(topCategories[0]['category'] ?? 'N/A'),
                        color: Colors.amber.shade700,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '#${topCategories[0]['rank'] ?? '1'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[0]['category'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Third place (shortest)
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.brown.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getCategoryIcon(topCategories[2]['category'] ?? 'N/A'),
                        color: Colors.brown.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '#${topCategories[2]['rank'] ?? '3'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[2]['category'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Counts
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (topCategories.length > 1 &&
                    topCategories[1]['happy_count'] != null)
                  Text(
                    topCategories[1]['happy_count'] == 1
                        ? '1 cliente feliz'
                        : '${topCategories[1]['happy_count']} clientes felices',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (topCategories.isNotEmpty &&
                    topCategories[0]['happy_count'] != null)
                  Text(
                    topCategories[0]['happy_count'] == 1
                        ? '1 cliente feliz'
                        : '${topCategories[0]['happy_count']} clientes felices',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (topCategories.length > 2 &&
                    topCategories[2]['happy_count'] != null)
                  Text(
                    topCategories[2]['happy_count'] == 1
                        ? '1 cliente feliz'
                        : '${topCategories[2]['happy_count']} clientes felices',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ],
      ),
      expanded: false,
      height: 300,
    );
  }

  Widget _buildEmptyStateCard({
    required String title,
    required IconData icon,
    required String message,
    double height = 300,
  }) {
    return StatisticCard(
      title: title,
      icon: icon,
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      expanded: false,
      height: height,
    );
  }
}
