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

  // Period selection
  String _selectedPeriod = 'week';
  DateTime _selectedDate = DateTime.now();

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
      // Format date for API request
      final String formattedDate =
          DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Output debug info to console
      print(
          'Loading dashboard data with period: $_selectedPeriod, date: $formattedDate');

      // Get all dashboard statistics with selected period and date
      final data = await _controller.getAllDashboardStatistics(
        period: _selectedPeriod,
        date: formattedDate,
      );

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

  void _updatePeriod(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadDashboardData();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDashboardData();
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
          // Period filter section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por período:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Week filter button
                    ElevatedButton(
                      onPressed: () => _updatePeriod('week'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPeriod == 'week'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        foregroundColor: _selectedPeriod == 'week'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Semana'),
                    ),
                    const SizedBox(width: 16),
                    // Month filter button
                    ElevatedButton(
                      onPressed: () => _updatePeriod('month'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPeriod == 'month'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        foregroundColor: _selectedPeriod == 'month'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Mes'),
                    ),
                    const Spacer(),
                    // Selected period display
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedPeriod == 'week'
                                ? 'Semana seleccionada'
                                : 'Mes seleccionado',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                      onPressed: _loadDashboardData,
                    ),
                  ],
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

          // Fourth row with gender distribution and top categories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gender distribution
              Expanded(
                child: _buildGenderDistribution(),
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
          // Day labels below chart
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Monday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Tuesday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Wednesday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Thursday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Friday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Saturday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Sunday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
              ],
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
          // Day labels below chart
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Monday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Tuesday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Wednesday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Thursday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Friday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Saturday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
                Text('Sunday',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
              ],
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

  Widget _buildBusyDaysAndCalendar() {
    if (_dashboardData == null || !_dashboardData!.containsKey('busyDays')) {
      return const StatisticCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month,
        content: Center(child: Text('No hay datos disponibles')),
        expanded: false,
        height: 300,
      );
    }

    final data = _dashboardData!['busyDays'];

    if (data is! Map || !data.containsKey('data') || data['data'] == null) {
      return const StatisticCard(
        title: 'Días de la semana con más y menos afluencia',
        icon: Icons.calendar_month,
        content: Center(child: Text('Formato de datos incorrecto')),
        expanded: false,
        height: 300,
      );
    }

    final busyDaysData = data['data'] as Map<String, dynamic>;

    // Extract most and least busy days
    final String mostBusyDay = busyDaysData['most_busy_day'] ?? 'Friday';
    final int mostBusyCount = busyDaysData['most_busy_count'] ?? 25;
    final String leastBusyDay = busyDaysData['least_busy_day'] ?? 'Thursday';
    final int leastBusyCount = busyDaysData['least_busy_count'] ?? 7;

    // Get current week dates
    final List<DateTime> weekDates = [];
    final DateTime now = DateTime.now();
    final DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      weekDates.add(startOfWeek.add(Duration(days: i)));
    }

    // Map days to their Spanish translations and short forms
    final Map<String, String> dayTranslations = {
      'Monday': 'Lunes',
      'Tuesday': 'Martes',
      'Wednesday': 'Miércoles',
      'Thursday': 'Jueves',
      'Friday': 'Viernes',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo',
    };

    final Map<String, String> dayShort = {
      'Monday': 'L',
      'Tuesday': 'M',
      'Wednesday': 'M',
      'Thursday': 'J',
      'Friday': 'V',
      'Saturday': 'S',
      'Sunday': 'D',
    };

    final String translatedMostBusyDay =
        dayTranslations[mostBusyDay] ?? mostBusyDay;
    final String translatedLeastBusyDay =
        dayTranslations[leastBusyDay] ?? leastBusyDay;

    return StatisticCard(
      title: 'Días de la semana con más y menos afluencia',
      icon: Icons.calendar_month,
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Days with highest/lowest traffic
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Most busy day
                  Column(
                    children: [
                      Text(
                        'Día Más Concurrido',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              translatedMostBusyDay,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Least busy day
                  Column(
                    children: [
                      Text(
                        'Día Menos Concurrido',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_off,
                              color: Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              translatedLeastBusyDay,
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Calendar title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Calendario Semanal',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Calendar grid with days of the week
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final date = weekDates[index];
                  final dayName = DateFormat('EEEE').format(date);
                  final dayLetter = dayShort[dayName] ?? '';
                  final isToday = date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;
                  final isMostBusy = dayName == mostBusyDay;
                  final isLeastBusy = dayName == leastBusyDay;

                  Color dayColor = Theme.of(context).colorScheme.surfaceVariant;

                  if (isToday) {
                    dayColor = Theme.of(context).colorScheme.primary;
                  } else if (isMostBusy) {
                    dayColor =
                        Theme.of(context).colorScheme.primary.withOpacity(0.7);
                  } else if (isLeastBusy) {
                    dayColor = Colors.orange;
                  }

                  return Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: dayColor.withOpacity(isToday ? 1.0 : 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            dayLetter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : dayColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Visitor count info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$mostBusyCount visitantes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$leastBusyCount visitantes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildEmotionsDetected() {
    // If we don't have emotion data, use fallback
    Map<String, dynamic>? emotionData;

    if (_dashboardData != null &&
        _dashboardData!.containsKey('emotionPercentage') &&
        _dashboardData!['emotionPercentage'] is Map &&
        _dashboardData!['emotionPercentage'].containsKey('data')) {
      emotionData =
          _dashboardData!['emotionPercentage']['data'] as Map<String, dynamic>;
    }

    // Fallback data if API didn't return anything
    final Map<String, double> emotions = {
      'Calmado': emotionData?['CALM'] as double? ?? 68.5,
      'Feliz': emotionData?['HAPPY'] as double? ?? 25.3,
      'Triste': emotionData?['SAD'] as double? ?? 6.2,
    };

    // Calculate total for percentages
    final total = emotions.values.fold(0.0, (sum, value) => sum + value);

    // Create a color map for emotions
    final Map<String, Color> emotionColors = {
      'Calmado': Colors.teal,
      'Feliz': Colors.amber,
      'Triste': Colors.blue,
    };

    return StatisticCard(
      title: 'Emociones detectadas',
      icon: Icons.emoji_emotions,
      content: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Pie chart representation
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress indicators stacked for pie chart effect
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: emotions['Calmado']! / total,
                        strokeWidth: 20,
                        backgroundColor: Colors.transparent,
                        color: emotionColors['Calmado'],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: emotions['Feliz']! / total,
                        strokeWidth: 20,
                        backgroundColor: Colors.transparent,
                        color: emotionColors['Feliz'],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: emotions['Triste']! / total,
                        strokeWidth: 20,
                        backgroundColor: Colors.transparent,
                        color: emotionColors['Triste'],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: emotions.entries.map((entry) {
                  final percentage =
                      (entry.value / total * 100).toStringAsFixed(1);

                  return Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: emotionColors[entry.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key}: $percentage%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      expanded: false,
      height: 300,
    );
  }

  Widget _buildGenderDistribution() {
    // If we don't have gender data, use fallback
    Map<String, dynamic>? genderData;

    if (_dashboardData != null &&
        _dashboardData!.containsKey('genderDistribution') &&
        _dashboardData!['genderDistribution'] is Map &&
        _dashboardData!['genderDistribution'].containsKey('data')) {
      genderData =
          _dashboardData!['genderDistribution']['data'] as Map<String, dynamic>;
    }

    // Fallback data if API didn't return anything
    final int maleCount = genderData?['male'] as int? ?? 5;
    final int femaleCount = genderData?['female'] as int? ?? 3;
    final int totalCount = maleCount + femaleCount;

    // Calculate percentages
    final double malePercentage = maleCount / totalCount * 100;
    final double femalePercentage = femaleCount / totalCount * 100;

    return StatisticCard(
      title: 'Distribución por género',
      icon: Icons.people,
      content: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Gender distribution chart
            Expanded(
              child: Row(
                children: [
                  // Male section
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.man,
                              color: Colors.blue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Label
                          const Text(
                            'Masculino',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Value
                          Text(
                            '$maleCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.blue,
                            ),
                          ),
                          // Percentage
                          Text(
                            '${malePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // VS label
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Female section
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.woman,
                              color: Colors.pink,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Label
                          const Text(
                            'Femenino',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Value
                          Text(
                            '$femaleCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.pink,
                            ),
                          ),
                          // Percentage
                          Text(
                            '${femalePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.pink.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Distribution bar
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.withOpacity(0.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width *
                        0.5 *
                        (malePercentage / 100),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      color: Colors.blue,
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width *
                        0.5 *
                        (femalePercentage / 100),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),

            // Age distribution section title
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                'Distribución por edad',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),

            // Age distribution
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '19-30: 8 personas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      expanded: false,
      height: 300,
    );
  }

  Widget _buildTopCategories() {
    List<Map<String, dynamic>> topCategories = [];

    try {
      if (_dashboardData != null &&
          _dashboardData!.containsKey('topCategories') &&
          _dashboardData!['topCategories'] is List) {
        final List<dynamic> data =
            _dashboardData!['topCategories'] as List<dynamic>;

        for (final item in data) {
          if (item is Map<String, dynamic>) {
            topCategories.add(item);
          }
        }
      }
    } catch (e) {
      print('Error parsing top categories: $e');
    }

    // If we don't have enough data, use fallback data
    if (topCategories.length < 3) {
      topCategories = [
        {'rank': 1, 'category': 'Snacks', 'total_count': 210},
        {'rank': 2, 'category': 'Alcohol', 'total_count': 109},
        {'rank': 3, 'category': 'Frutas', 'total_count': 18},
      ];
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
                Text(
                  '${topCategories[1]['total_count']} visitas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${topCategories[0]['total_count']} visitas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
