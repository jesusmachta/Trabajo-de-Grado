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

// Clase para datos de porcentaje de emociones (igual que en statistics_view)
class EmotionPercentageData {
  final String emotion;
  final double percentage;

  EmotionPercentageData({
    required this.emotion,
    required this.percentage,
  });
}

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
      // Get all dashboard statistics without period filtering
      final data = await _controller.getAllDashboardStatistics();

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });

      // Print success message
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
      return const StatisticCard(
        title: 'Horas con mayor afluencia de clientes',
        icon: Icons.trending_up,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['peakHours'];

    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Horas con mayor afluencia de clientes',
        icon: Icons.trending_up,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 300,
      );
    }

    final hourData = data['data'] as Map<String, dynamic>;

    // Convert data for the chart
    final List<FlSpot> spots = [];
    final List<String> hourLabels = [];
    int maxCount = 0;

    // Sort hours chronologically
    final sortedHours = hourData.keys.toList()
      ..sort((a, b) {
        final int timeA = int.tryParse(a.toString().split(':')[0]) ?? 0;
        final int timeB = int.tryParse(b.toString().split(':')[0]) ?? 0;
        return timeA.compareTo(timeB);
      });

    // Create spots for each hour
    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      final count = hourData[hour] as int;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
      hourLabels.add(hour.toString());

      if (count > maxCount) {
        maxCount = count;
      }
    }

    // Round up to nearest multiple of 5 for y-axis max
    final yAxisMax = ((maxCount / 5).ceil() * 5).toDouble();

    return StatisticCard(
      title: 'Horas con mayor afluencia de clientes',
      icon: Icons.trending_up,
      content: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 5,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= hourLabels.length) {
                            return const SizedBox();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              hourLabels[index],
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 5 != 0) return const SizedBox();

                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: spots.length - 1.0,
                  minY: 0,
                  maxY: yAxisMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5.0,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 1,
                            strokeColor: Theme.of(context).colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Visitor counts
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                min(7, sortedHours.length),
                (index) {
                  final hour = sortedHours[index];
                  final count = hourData[hour] as int;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count visitantes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      expanded: false,
      height: 400,
    );
  }

  Widget _buildLeastHoursChart() {
    if (_dashboardData == null || !_dashboardData!.containsKey('leastHours')) {
      return const StatisticCard(
        title: 'Horas con menor afluencia de clientes',
        icon: Icons.trending_down,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['leastHours'];

    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Horas con menor afluencia de clientes',
        icon: Icons.trending_down,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 300,
      );
    }

    final hourData = data['data'] as Map<String, dynamic>;

    // Convert data for the chart
    final List<FlSpot> spots = [];
    final List<String> hourLabels = [];
    int maxCount = 0;

    // Sort hours chronologically
    final sortedHours = hourData.keys.toList()
      ..sort((a, b) {
        final int timeA = int.tryParse(a.toString().split(':')[0]) ?? 0;
        final int timeB = int.tryParse(b.toString().split(':')[0]) ?? 0;
        return timeA.compareTo(timeB);
      });

    // Create spots for each hour
    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      final count = hourData[hour] as int;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
      hourLabels.add(hour.toString());

      if (count > maxCount) {
        maxCount = count;
      }
    }

    // Round up to nearest multiple of 5 for y-axis max
    final yAxisMax = max(((maxCount / 5).ceil() * 5).toDouble(), 5.0);

    return StatisticCard(
      title: 'Horas con menor afluencia de clientes',
      icon: Icons.trending_down,
      content: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 2,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= hourLabels.length) {
                            return const SizedBox();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              hourLabels[index],
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Show every 2 values for least hours chart
                          if (value % 2 != 0) return const SizedBox();

                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: spots.length - 1.0,
                  minY: 0,
                  maxY: yAxisMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5.0,
                            color: Colors.teal,
                            strokeWidth: 1,
                            strokeColor: Theme.of(context).colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Visitor counts
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                min(7, sortedHours.length),
                (index) {
                  final hour = sortedHours[index];
                  final count = hourData[hour] as int;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count visitantes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      expanded: false,
      height: 400,
    );
  }

  Widget _buildEmotionsDetected() {
    if (_dashboardData == null ||
        !_dashboardData!.containsKey('emotionPercentageByCategory')) {
      return const StatisticCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['emotionPercentageByCategory'];
    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Emociones detectadas',
        icon: Icons.emoji_emotions,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 300,
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
      title: 'Porcentaje de clientes FELICES por categoría',
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
      return const StatisticCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 400,
      );
    }
    final data = _dashboardData!['busyDays'];
    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 400,
      );
    }
    final busyDaysData = data['data'] as Map<String, dynamic>;
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
      return const StatisticCard(
        title: 'Categorías visitadas',
        icon: Icons.category,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['visitedCategories'];

    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Categorías visitadas',
        icon: Icons.category,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
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

    // Helper function to get category icon
    IconData getCategoryIcon(String category) {
      switch (category.toLowerCase()) {
        case 'snacks':
          return Icons.cookie;
        case 'frutas':
          return Icons.apple;
        case 'alcohol':
          return Icons.wine_bar;
        case 'bebidas':
          return Icons.local_drink;
        case 'carnes':
          return Icons.restaurant;
        case 'lácteos':
        case 'lacteos':
          return Icons.egg;
        case 'panadería':
        case 'panaderia':
          return Icons.bakery_dining;
        case 'limpieza':
          return Icons.cleaning_services;
        case 'cereales':
          return Icons.breakfast_dining;
        case 'congelados':
          return Icons.ac_unit;
        default:
          return Icons.shopping_bag;
      }
    }

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
      return const StatisticCard(
        title: 'Categorías preferidas por género',
        icon: Icons.category_outlined,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }
    final data = _dashboardData!['preferredCategoriesByGender'];
    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Categorías preferidas por género',
        icon: Icons.category_outlined,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 300,
      );
    }
    final genderPreferencesData = data['data'] as Map<String, dynamic>;
    // Extraer correctamente los datos de 'Male' y 'Female'
    final malePreference = genderPreferencesData['Male'] ?? {};
    final femalePreference = genderPreferencesData['Female'] ?? {};
    // Helper function to get category icon
    IconData getCategoryIcon(String category) {
      switch (category.toLowerCase()) {
        case 'snacks':
          return Icons.cookie;
        case 'frutas':
          return Icons.apple;
        case 'alcohol':
          return Icons.wine_bar;
        case 'bebidas':
          return Icons.local_drink;
        case 'carnes':
          return Icons.restaurant;
        case 'lácteos':
        case 'lacteos':
          return Icons.egg;
        case 'panadería':
        case 'panaderia':
          return Icons.bakery_dining;
        case 'limpieza':
          return Icons.cleaning_services;
        case 'cereales':
          return Icons.breakfast_dining;
        case 'congelados':
          return Icons.ac_unit;
        default:
          return Icons.shopping_bag;
      }
    }

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
      title: 'Categorías preferidas por género',
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
      return const StatisticCard(
        title: 'Top Categorías Mejor Evaluadas',
        icon: Icons.star,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['topCategories'];

    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Top Categorías Mejor Evaluadas',
        icon: Icons.star,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
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

    // Helper function to get category icon
    IconData getCategoryIcon(String category) {
      switch (category.toLowerCase()) {
        case 'snacks':
          return Icons.cookie;
        case 'frutas':
          return Icons.apple;
        case 'alcohol':
          return Icons.wine_bar;
        case 'bebidas':
          return Icons.local_drink;
        case 'carnes':
          return Icons.restaurant;
        case 'lácteos':
        case 'lacteos':
          return Icons.egg;
        case 'panadería':
        case 'panaderia':
          return Icons.bakery_dining;
        case 'limpieza':
          return Icons.cleaning_services;
        case 'cereales':
          return Icons.breakfast_dining;
        case 'congelados':
          return Icons.ac_unit;
        default:
          return Icons.shopping_bag;
      }
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
                        getCategoryIcon(topCategories[1]['category']),
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
                            const Text(
                              '#2',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[1]['category'],
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
                        getCategoryIcon(topCategories[0]['category']),
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
                            const Text(
                              '#1',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[0]['category'],
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
                        getCategoryIcon(topCategories[2]['category']),
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
                            const Text(
                              '#3',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCategories[2]['category'],
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
                if (topCategories[1]['total_count'] != null)
                  Text(
                    '${topCategories[1]['total_count']} visitas',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (topCategories[0]['total_count'] != null)
                  Text(
                    '${topCategories[0]['total_count']} visitas',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (topCategories[2]['total_count'] != null)
                  Text(
                    '${topCategories[2]['total_count']} visitas',
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
}
