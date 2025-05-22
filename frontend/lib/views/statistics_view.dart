import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../controllers/statistics_controller.dart';
import '../models/chart_data.dart';
import 'widgets/statistic_card.dart';
import 'widgets/statistics_selector.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart'; // Import month picker
import '../controllers/categories_controller.dart'; // Importar el controlador de categorías
import 'package:go_router/go_router.dart'; // Import GoRouter

// String extension to add capitalize functionality
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

// Clase para datos de porcentaje de emociones
class EmotionPercentageData {
  final String emotion;
  final double percentage;

  EmotionPercentageData({
    required this.emotion,
    required this.percentage,
  });
}

class StatisticsView extends StatefulWidget {
  final Function? toggleTheme;
  final String? initialStat;

  const StatisticsView({super.key, this.toggleTheme, this.initialStat});

  @override
  StatisticsViewState createState() => StatisticsViewState();
}

// Make the state class public by removing the underscore
class StatisticsViewState extends State<StatisticsView> {
  final StatisticsController _controller = StatisticsController();
  final CategoriesController _categoriesController =
      CategoriesController(); // Añadir controlador de categorías
  bool _isLoading = false;
  late String _selectedStat;
  String _selectedPeriod = 'week'; // Default for other stats
  DateTime _selectedDate = DateTime.now(); // Default for other stats
  DateTime? _selectedEndDate; // Default for other stats
  int? _selectedMonth; // Default for other stats
  int? _selectedYear; // Default for other stats

  // Mapa con descripciones para cada tipo de estadística
  final Map<String, String> _statisticsDescriptions = {
    'peak-hours':
        'Muestra las horas del día con mayor afluencia de clientes durante la semana o mes seleccionado. Esta información es útil para optimizar la asignación de personal y recursos.',
    'least-hours':
        'Presenta las horas del día con menor afluencia de clientes. Puede ser útil para programar tareas de mantenimiento o actividades que requieran menos interacción con clientes.',
    'busy-days-combined':
        'Comparativa entre los días de la semana con mayor y menor cantidad de visitantes. Ayuda a identificar patrones semanales de tráfico de clientes.',
    'visited-categories-combined':
        'Muestra las categorías de productos más y menos visitadas por los clientes. Esta información puede guiar decisiones sobre promociones, ubicación de productos y estrategias de marketing.',
    'most-frequent-emotions':
        'Presenta las emociones más comunes detectadas en los clientes. Útil para entender el estado emocional general de los visitantes.',
    'emotion-percentage':
        'Distribución porcentual de las diferentes emociones detectadas en los clientes por categoría. Ayuda a entender la respuesta emocional a distintos productos.',
    'gender-age-combined':
        'Datos demográficos de los clientes según sexo y grupos de edad. Permite conocer mejor el perfil de la clientela para adaptar estrategias de marketing y producto.',
    'preferred-category-by-gender':
        'Muestra las categorías de productos preferidas según el sexo de los clientes. Útil para estrategias de marketing segmentadas.',
    'top-successful-categories':
        'Ranking de las categorías mejor evaluadas o más exitosas entre los clientes. Ayuda a identificar productos estrella y tendencias.',
    'emotional-differences-by-category':
        'Analiza las diferencias en las respuestas emocionales de los clientes según sexo y categoría de producto. Útil para entender preferencias específicas.',
    'age-gender-distribution-by-category':
        'Detalla la distribución demográfica de los clientes por categoría de producto, mostrando patrones de interés según edad y sexo.',
  };

  // State specific for visited-categories-combined
  String _selectedCategoryPeriodType =
      'historic'; // Cambiado a 'historic' para iniciar en histórico
  DateTime? _selectedCategoryWeek; // Start date of the selected week
  DateTime? _selectedCategoryMonth; // First day of the selected month

  // Change to dynamic to accept both Map and List
  dynamic _statisticsData;
  String? _error;

  // Para manejar categorías
  List<Map<String, dynamic>> _categories = []; // Lista de categorías
  Map<String, String> _categoryIconMap = {}; // Mapa de nombre a icono

  // Method to update the selected stat from outside
  void updateSelectedStat(String stat) {
    // Si ya estamos mostrando esta estadística, no hacer nada
    if (_selectedStat == stat) return;

    // Actualizar inmediatamente la UI y mostrar un indicador de carga
    setState(() {
      _selectedStat = stat;
      _isLoading = true;
    });

    // Navegar a la estadística seleccionada sin esperar a que carguen los datos
    GoRouter.of(context).go('/statistics?stat=$stat');
  }

  // Versión asíncrona para no bloquear la UI
  Future<void> _loadStatisticsAsync() async {
    // Establecer loading pero permitir que se muestre la interfaz actualizada
    setState(() {
      _isLoading = true;
    });

    // Cargar los datos en segundo plano
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;

      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      Map<String, String>? params;
      dynamic data;

      // Reiniciar configuraciones específicas si es necesario
      if (_selectedStat == 'gender-age-combined') {
        await _initAvailablePeriods();
      }

      if (_selectedStat == 'visited-categories-combined') {
        data = await _controller.getHistoricalVisitedCategoriesStatistics(
            token: token);
      } else if (_selectedStat == 'busy-days-combined') {
        data = await _controller.getBusyDaysStatistics(token: token);
      } else if (_selectedStat == 'gender-age-combined') {
        // --- ARREGLO PARA EL MENSUAL ---
        if (_selectedCategoryPeriodType == 'month') {
          // Buscar el mes más reciente disponible en _availableMonths
          if (_availableMonths.isNotEmpty) {
            _selectedMonthKey = _availableMonths.first;
          } else {
            _selectedMonthKey = null;
          }
        } else if (_selectedCategoryPeriodType == 'week') {
          if (_availableWeeks.isNotEmpty) {
            _selectedWeekKey = _availableWeeks.first;
          } else {
            _selectedWeekKey = null;
          }
        }
        params = {'period': _selectedCategoryPeriodType};
        if (_selectedCategoryPeriodType == 'week' && _selectedWeekKey != null) {
          params['date'] = _selectedWeekKey!;
        } else if (_selectedCategoryPeriodType == 'month' &&
            _selectedMonthKey != null) {
          final parts = _selectedMonthKey!.split('-');
          params['year'] = parts[0];
          params['month'] = parts[1];
        }
        data = await _controller.getGenderAgeDistributionStatistics(
            params: params, token: token);
      } else if (_selectedStat == 'top-successful-categories') {
        data = await _controller.getTopSuccessfulCategories(token: token);
      } else {
        if (_requiresParams(_selectedStat)) {
          params = {'period': _selectedPeriod};
          if (_selectedPeriod == 'week') {
            params['date'] = DateFormat('yyyy-MM-dd').format(_selectedDate);
            if (_selectedStat == 'emotion-comparison' &&
                _selectedEndDate != null) {
              params['end_date'] =
                  DateFormat('yyyy-MM-dd').format(_selectedEndDate!);
            }
          } else if (_selectedPeriod == 'month') {
            params['month'] = _selectedMonth.toString();
            params['year'] = _selectedYear.toString();
          }
        }
        data = await _controller.getStatistics(_selectedStat,
            params: params, token: token);
      }

      // Actualizar la UI solo si el widget sigue montado
      if (mounted) {
        setState(() {
          _statisticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadStatisticsAsync: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Opciones para el período
  final List<Map<String, String>> _periodOptions = [
    {'value': 'week', 'label': 'Semana'},
    {'value': 'month', 'label': 'Mes'},
  ];

  // Opciones de período para categorías visitadas
  final List<Map<String, String>> _categoryPeriodOptions = [
    {'value': 'week', 'label': 'Semana'},
    {'value': 'month', 'label': 'Mes'},
  ];

  // NUEVO: Listas de semanas y meses disponibles para gender-age-combined
  List<String> _availableWeeks = [];
  List<String> _availableMonths = [];
  String? _selectedWeekKey;
  String? _selectedMonthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedCategoryWeek = now.subtract(Duration(days: now.weekday - 1));
    _selectedCategoryMonth = DateTime(now.year, now.month, 1);
    _selectedPeriod = 'month';
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _selectedCategoryPeriodType = 'historic'; // Inicia en histórico
    _selectedStat = widget.initialStat ?? 'peak-hours';
    _initAvailablePeriods();
    _loadStatisticsAsync();
    _loadCategoryIcons(); // Cargar iconos de categorías
  }

  @override
  void didUpdateWidget(covariant StatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStat != null && widget.initialStat != _selectedStat) {
      updateSelectedStat(widget.initialStat!);
    }
  }

  // NUEVO: Inicializar semanas y meses disponibles
  Future<void> _initAvailablePeriods() async {
    if (_selectedStat == 'gender-age-combined') {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final token = authController.token;
      if (token == null) return;
      final weeks = await _controller.getAvailableWeeks(token: token);
      final months = await _controller.getAvailableMonths(token: token);
      setState(() {
        _availableWeeks = weeks;
        _availableMonths = months;
        _selectedWeekKey = weeks.isNotEmpty ? weeks.first : null;
        _selectedMonthKey = months.isNotEmpty ? months.first : null;
      });
    }
  }

  // NUEVO: Formatear semana para mostrar
  String _formatWeekLabel(String weekKey) {
    try {
      final date = DateTime.parse(weekKey);
      return 'Semana del ${DateFormat('dd/MM/yyyy').format(date)}';
    } catch (_) {
      return weekKey;
    }
  }

  // NUEVO: Formatear mes para mostrar
  String _formatMonthLabel(String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return '${_formatMonthName(month).capitalize()} $year';
    } catch (_) {
      return monthKey;
    }
  }

  // Determinar si se deben mostrar controles de período
  bool _shouldShowPeriodControls() {
    // Mostrar controles para estadísticas que requieren parámetros de período
    // Excluimos visited-categories-combined y gender-age-combined porque tienen controles específicos
    if (_selectedStat == 'visited-categories-combined') return false;
    if (_selectedStat == 'gender-age-combined') return false;
    if (_selectedStat == 'age-gender-distribution-by-category')
      return false; // <-- ADD THIS LINE

    if (_selectedStat.contains('distribution') &&
        _selectedStat != 'gender-age-combined') return true; // Adjust condition
    if (_selectedStat == 'emotion-comparison') return true;

    return _requiresParams(_selectedStat);
  }

  // Verificar si la estadística requiere parámetros
  bool _requiresParams(String stat) {
    return (stat.contains('distribution') &&
            stat != 'gender-age-combined' &&
            stat !=
                'age-gender-distribution-by-category') || // <-- MODIFY THIS LINE
        stat == 'most-visited' ||
        stat == 'least-visited' ||
        stat == 'emotion-comparison' ||
        stat == 'gender-age-combined';
  }

  // Muestra un selector de fecha para el inicio de la semana
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Selecciona una fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;

        // Si estamos en modo semanal, establecer la fecha de fin como 6 días después
        if (_selectedPeriod == 'week') {
          _selectedEndDate = pickedDate.add(const Duration(days: 6));

          // Si la fecha de fin es futura, limitarla a hoy
          final now = DateTime.now();
          if (_selectedEndDate!.isAfter(now)) {
            _selectedEndDate = now;
          }
        }

        // Clear cache for emotion-comparison to ensure fresh data
        if (_selectedStat == 'emotion-comparison') {
          _controller.clearCache(_selectedStat);
          _statisticsData = null;
        }
      });
      _loadStatistics();
    }
  }

  // Muestra un selector de fecha para el fin de la semana
  Future<void> _selectEndDate(BuildContext context) async {
    // Solo permitir seleccionar fecha de fin para el modo semana
    if (_selectedPeriod != 'week') return;

    // La fecha mínima debe ser la fecha de inicio
    final DateTime minDate = _selectedDate;

    // La fecha máxima debe ser exactamente 6 días después de la fecha de inicio
    final DateTime maxDate = _selectedDate.add(const Duration(days: 6));

    // Si maxDate es futuro, limitarlo a hoy
    final DateTime limitedMaxDate =
        maxDate.isAfter(DateTime.now()) ? DateTime.now() : maxDate;

    final DateTime initialDate = _selectedEndDate ?? limitedMaxDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: limitedMaxDate,
      helpText: 'Selecciona una fecha de fin',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (pickedDate != null && (pickedDate != _selectedEndDate)) {
      setState(() {
        _selectedEndDate = pickedDate;

        // Clear cache for emotion-comparison to ensure fresh data
        if (_selectedStat == 'emotion-comparison') {
          _controller.clearCache(_selectedStat);
          _statisticsData = null;
        }
      });
      _loadStatistics();
    }
  }

  // Muestra un selector de mes y año
  Future<void> _selectMonth(BuildContext context) async {
    // Solo permitir seleccionar mes para el modo mes
    if (_selectedPeriod != 'month') return;

    final DateTime now = DateTime.now();
    final int currentYear = _selectedYear ?? now.year;
    final int currentMonth = _selectedMonth ?? now.month;

    // Mostrar un diálogo simple para seleccionar mes y año
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar mes y año'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de año
                Row(
                  children: [
                    const Text('Año: '),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: currentYear,
                      items: List.generate(
                        5,
                        (index) => DropdownMenuItem(
                          value: now.year - index,
                          child: Text('${now.year - index}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Selector de mes
                Row(
                  children: [
                    const Text('Mes: '),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: currentMonth,
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(_formatMonthName(index + 1)),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMonth = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              // Al aceptar, actualizar el estado global y recargar las estadísticas
              this.setState(() {
                _selectedMonth =
                    currentMonth; // Use the ones updated in the dialog state
                _selectedYear =
                    currentYear; // Use the ones updated in the dialog state

                // Limpiar caché para asegurar datos frescos if necessary
                if (_selectedStat == 'emotion-comparison' ||
                    _selectedStat.contains('distribution')) {
                  _controller.clearCache(_selectedStat);
                }
                _statisticsData = null;
              });
              // Cerrar el diálogo
              Navigator.pop(context);

              // Recargar estadísticas con los nuevos parámetros
              _loadStatistics();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ****** NEW: Selector de Semana para Categorías Visitadas ******
  Future<void> _selectCategoryWeek(BuildContext context) async {
    // Evitar múltiples selecciones simultáneas
    if (_isLoading) return;

    // First set a loading state to prevent multiple pickers
    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime now = DateTime.now();
      final DateTime initialDate = _selectedCategoryWeek ?? now;

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('es', 'ES'),
      );

      // Handle case where date picker is dismissed
      if (picked == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Calculate start of week
      final DateTime startOfWeek =
          picked.subtract(Duration(days: picked.weekday - 1));

      // Update state even if week didn't change, to ensure refresh
      setState(() {
        _selectedCategoryWeek = startOfWeek;
        _statisticsData = null;
        _isLoading = false;
      });

      // Load after state update is complete
      await _loadStatistics();
    } catch (e) {
      print('Error in date picker: $e');
      // Ensure loading state is cleared in case of error
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ****** NEW: Selector de Mes para Categorías Visitadas ******
  Future<void> _selectCategoryMonth(BuildContext context) async {
    final DateTime initial = _selectedCategoryMonth ?? DateTime.now();
    // Correctly use the imported showMonthPicker function
    final DateTime? picked = await showMonthPicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020), // Or your earliest data point
      lastDate: DateTime.now(),
      // locale: const Locale('es', 'ES'), // REMOVED: locale is not a direct parameter in v6+
    );

    if (picked != null) {
      // Ensure we store the first day of the month
      final DateTime startOfMonth = DateTime(picked.year, picked.month, 1);
      if (startOfMonth != _selectedCategoryMonth) {
        setState(() {
          _selectedCategoryMonth = startOfMonth;
          // Clear data to force reload
          _statisticsData = null;
        });
        _loadStatistics();
      }
    }
  }

  // Obtener el nombre del mes en español
  String _getMonthName(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return months[month - 1];
  }

  // Método para mostrar el diálogo de ayuda
  void _showHelpDialog() {
    String description = _statisticsDescriptions[_selectedStat] ??
        'Información sobre esta estadística no disponible';

    // Obtener título de la estadística seleccionada
    String title = '';
    for (var option in _controller.getStatisticsOptions()) {
      if (option['value'] == _selectedStat) {
        title = option['label'] ?? '';
        break;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getIconForStatistic(_selectedStat),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acerca de: $title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '* Estas estadísticas se generan a partir del análisis en tiempo real de los clientes en la tienda.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      // Wrap the main Column with SingleChildScrollView
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y descripción
            Text(
              'Estadísticas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona una estadística para visualizar los datos correspondientes.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Selector de estadísticas
            StatisticsSelector(
              value: _selectedStat,
              options: _controller.getStatisticsOptions(),
              onChanged: (value) {
                if (value != null && value != _selectedStat) {
                  setState(() {
                    _selectedStat = value;
                    // Clear data when changing statistics
                    _statisticsData = null;
                  });
                  // Use Future to avoid updating state during build
                  Future.microtask(() => _loadStatistics());
                }
              },
            ),

            // --- CONTROLES DE FILTRO ---
            // Mostrar selectores de período específico para visited-categories-combined
            if (_selectedStat == 'visited-categories-combined') ...[
              // Remove the period selectors - only showing historical data
              const SizedBox(height: 8),
            ],

            // Mostrar selectores de período para gender-age-combined
            if (_selectedStat == 'gender-age-combined') ...[
              const SizedBox(height: 16),
              Text(
                'Filtrar por período:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'week',
                    label: Text('Semana'),
                    icon: Icon(Icons.view_week),
                  ),
                  ButtonSegment<String>(
                    value: 'month',
                    label: Text('Mes'),
                    icon: Icon(Icons.calendar_month),
                  ),
                  ButtonSegment<String>(
                    value: 'historic',
                    label: Text('Histórico'),
                    icon: Icon(Icons.history),
                  ),
                ],
                selected: {_selectedCategoryPeriodType},
                onSelectionChanged: (Set<String> newSelection) async {
                  if (newSelection.isNotEmpty &&
                      newSelection.first != _selectedCategoryPeriodType) {
                    setState(() {
                      _selectedCategoryPeriodType = newSelection.first;
                      _statisticsData = null;
                    });
                    await _initAvailablePeriods();
                    _loadStatistics();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // Mostrar selectores adicionales si es necesario
            if (_shouldShowPeriodControls()) ...[
              const SizedBox(height: 16),
              Text(
                'Esta estadística requiere parámetros adicionales:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),

              // Selector de período
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: const OutlineInputBorder(),
                  labelText: 'Período',
                  hintText: 'Selecciona semana o mes',
                  labelStyle:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                ),
                items: _periodOptions.map((option) {
                  return DropdownMenuItem(
                    value: option['value'],
                    child: Text(option['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _selectedPeriod) {
                    setState(() {
                      _selectedPeriod = value;
                      // Reset date selections when changing period
                      if (value == 'week') {
                        _selectedMonth = null;
                        _selectedYear = null;
                      } else {
                        _selectedEndDate = null;
                      }
                      // Clear data when changing period
                      _statisticsData = null;

                      // Make sure to clear any cached data
                      if (_selectedStat == 'emotion-comparison') {
                        _controller.clearCache(_selectedStat);
                      }
                    });
                    // Use Future to avoid updating state during build
                    Future.microtask(() => _loadStatistics());
                  }
                },
              ),

              const SizedBox(height: 16),

              // Mostrar selectores específicos según el período seleccionado
              if (_selectedPeriod == 'week') ...[
                // Selector de fechas para período semanal (inicio y fin)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de inicio:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(_selectedDate),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de fin:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectEndDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_repeat,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedEndDate != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_selectedEndDate!)
                                          : 'No seleccionada',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                const SizedBox(height: 4),
                Text(
                  'Selecciona el rango de fechas para ver estadísticas de la semana',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else if (_selectedPeriod == 'month') ...[
                // Selector de mes para período mensual
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona un mes:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selectMonth(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedMonth != null && _selectedYear != null
                                    ? '${_getMonthName(_selectedMonth!)} ${_selectedYear!}'
                                    : 'Mes actual',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se mostrarán datos del mes completo seleccionado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Refresh button and Help button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Help button (new)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _showHelpDialog,
                    icon: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.question_mark,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    tooltip: 'Ayuda sobre esta estadística',
                  ),
                ),
                // Existing refresh button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _statisticsData = null;
                    });
                    _controller.clearCache(_selectedStat);
                    _loadStatistics();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Mostrar datos o indicadores de carga/error
            // REMOVED Expanded here
            _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando datos...'),
                      ],
                    ),
                  )
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                _formatErrorMessage(_error!),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _loadStatistics,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _statisticsData == null &&
                            !_isLoading // Handle null data state explicitly
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Selecciona parámetros para cargar los datos',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _buildStatisticsContent(), // Display content directly
          ],
        ),
      ),
    );
  }

  // Formatear mensajes de error para mostrarlos de manera más amigable
  String _formatErrorMessage(String error) {
    if (error.contains('Failed to load statistics')) {
      return 'No se pudieron cargar los datos. Por favor, verifica tu conexión e intenta nuevamente.';
    } else if (error.contains('Error de validación')) {
      return 'Error de validación: asegúrate de seleccionar parámetros válidos.';
    } else if (error.contains('Connection refused')) {
      return 'No se pudo conectar con el servidor. Verifica que el servidor esté en ejecución.';
    } else {
      // Limpiar el mensaje de error original
      String cleanError = error.replaceAll('Exception: Error: Exception: ', '');
      return cleanError;
    }
  }

  Widget _buildStatisticsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Ocurrió un error:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStatistics,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_statisticsData == null && !_isLoading) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Selecciona una estadística o ajusta los filtros.'),
        ],
      ));
    }

    // Special handling for top-successful-categories which is already a List
    if (_selectedStat == 'top-successful-categories') {
      // Obtener el título de la estadística seleccionada
      final selectedStatOption = _controller.getStatisticsOptions().firstWhere(
            (option) => option['value'] == _selectedStat,
            orElse: () => {'value': _selectedStat, 'label': 'Estadística'},
          );

      // Directamente llamar a _buildTopCategoriesView con la lista de datos
      // Asegurarse de que _statisticsData es una lista
      if (_statisticsData is List) {
        return _buildTopCategoriesView(_statisticsData);
      } else {
        print(
            'Error: Expected List for top-successful-categories, but got ${_statisticsData.runtimeType}');
        return StatisticCard(
          title: selectedStatOption['label']!,
          icon: _getIconForStatistic(_selectedStat),
          content:
              const Center(child: Text('Error: formato de datos incorrecto')),
        );
      }
    }

    // For all other statistics that use the Map structure with 'data' field
    final data = _statisticsData!['data'];
    if (data == null) {
      // Added a check specifically for visited-categories-combined before general null check
      if (_selectedStat == 'visited-categories-combined') {
        return const Center(
          child: Text(
              'Datos para categorías combinadas están vacíos o no disponibles'),
        );
      }
      return const Center(
        child: Text('Datos recibidos, pero están vacíos'),
      );
    }

    // Obtener el título de la estadística seleccionada
    final selectedStatOption = _controller.getStatisticsOptions().firstWhere(
          (option) => option['value'] == _selectedStat,
          orElse: () => {'value': _selectedStat, 'label': 'Estadística'},
        );

    // Crear el contenido
    Widget content = _buildStatisticsDataView(data);

    // Si es emotion-comparison, mostrar directamente sin StatisticCard para evitar problemas de layout
    if (_selectedStat == 'emotion-comparison') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                selectedStatOption['label']!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            Expanded(
                child:
                    content), // emotion-comparison content is already Expanded if needed internally
          ],
        ),
      );
    }

    // --- MODIFICATION START ---
    // Handle visited-categories-combined layout specifically
    if (_selectedStat == 'visited-categories-combined') {
      // Directly return the content wrapped in Expanded to manage layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modificar el título para agregar fondo azul como las demás estadísticas
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                  : Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).dividerColor
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getIconForStatistic(_selectedStat),
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedStatOption['label']!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : null,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            // Wrap the content in Expanded
            child: content,
          ),
        ],
      );
    }
    // --- MODIFICATION END ---

    // Para todas las demás estadísticas, usar el formato normal con StatisticCard
    return StatisticCard(
      title: selectedStatOption['label']!,
      icon: _getIconForStatistic(_selectedStat),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mostrar información sobre el período seleccionado si aplica
          if (_shouldShowPeriodControls() &&
              _selectedStat != 'emotion-comparison') ...[
            Text(
              'Período: ${_periodOptions.firstWhere((o) => o['value'] == _selectedPeriod)['label']}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              'Fecha de inicio: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            if (_selectedPeriod == 'week' && _selectedEndDate != null)
              Text(
                'Fecha de fin: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            const SizedBox(height: 8),
          ],

          // Eliminamos el texto "Resultados:"
          const SizedBox(height: 16),

          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsDataView(dynamic data) {
    // Handle null data
    if (data == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Add print statement to debug data
    print(
        'Building statistics data view for ${_selectedStat} with data: $data');

    // Implementar visualizaciones específicas según el tipo de estadística
    switch (_selectedStat) {
      case 'peak-hours':
      case 'least-hours':
        return _buildHoursChart(data);
      case 'busy-days':
      case 'least-days':
        return _buildDaysHighlight(data);
      case 'busy-days-combined':
        return _buildCombinedDaysView(data);
      case 'gender-distribution':
        // Handle gender distribution view specifically
        return _buildGenderDistributionView(data);
      case 'age-distribution':
        // Handle age distribution view specifically
        return _buildAgeDistributionView(data);
      case 'most-visited':
      case 'least-visited':
        // Use individual view for now, but we'll create a combined view
        return _buildVisitedCategoryView(data, _selectedStat);
      case 'visited-categories-combined':
        // New combined view for most and least visited categories
        return _buildCombinedVisitedCategoriesView(data);
      case 'gender-age-combined':
        // New combined view for gender and age distribution
        return _buildCombinedGenderAgeDistributionView(data);
      case 'most-visited-historical':
      case 'least-visited-historical':
        return _buildCategoryBarChart(data);
      case 'emotion-percentage':
        return _buildEmotionPieChart(data);
      case 'most-frequent-emotions':
        // Special handling for most-frequent-emotions
        if (data is! Map || data.isEmpty) {
          return const Center(child: Text('No hay datos disponibles'));
        }
        // Use a simpler approach to directly render the data
        return _buildFrequentEmotionsView(data);
      case 'emotion-comparison':
        // Updated to handle new structure and responsiveness
        return _buildEmotionComparisonChart(data);
      case 'emotional-differences-by-category':
        return _buildEmotionalDifferencesByCategoryView(data);
      case 'age-gender-distribution-by-category':
        return _buildAgeGenderDistributionByCategory(data);
      case 'preferred-category-by-gender':
        return _buildPreferredCategoryView(data);
      default:
        // Genérico
        return const Center(
            child: Text(
                'No hay una visualización específica implementada para este tipo de estadística.'));
    }
  }

  // Visualizador para categoría más visitada y menos visitada
  Widget _buildVisitedCategoryView(dynamic data, String statType) {
    print('Building visited category view with data: $data');

    if (data == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Extract data correctly based on API response structure
    String categoryName = '';
    int visitCount = 0;

    try {
      // Check the data structure and extract values
      if (data is Map) {
        if (data.containsKey('most_visited_category')) {
          categoryName = data['most_visited_category'].toString();
          visitCount = (data['count'] is int)
              ? data['count']
              : int.tryParse(data['count'].toString()) ?? 0;
        } else if (data.containsKey('least_visited_category')) {
          categoryName = data['least_visited_category'].toString();
          visitCount = (data['count'] is int)
              ? data['count']
              : int.tryParse(data['count'].toString()) ?? 0;
        } else {
          // Try to get the first key-value pair if the structure is different
          final entry = data.entries.first;
          categoryName = entry.key;
          visitCount = (entry.value is int)
              ? entry.value
              : int.tryParse(entry.value.toString()) ?? 0;
        }
      }
    } catch (e) {
      print('Error parsing visited category data: $e');
      return Center(child: Text('Error al procesar datos: $e'));
    }

    // Define title and icon based on statistic type
    final bool isMostVisited = statType == 'most-visited';
    final String title =
        isMostVisited ? 'Categoría Más Visitada' : 'Categoría Menos Visitada';
    final Color cardColor =
        isMostVisited ? Colors.green.shade50 : Colors.orange.shade50;
    final Color accentColor = isMostVisited ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Category Card
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: accentColor.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Category Icon & Name
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Category Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(categoryName),
                            size: 60,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Category Name
                      Text(
                        categoryName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Visit Count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total de Visitas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$visitCount',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Explanation text
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              isMostVisited
                  ? 'Esta es la categoría que ha recibido el mayor número de visitas por parte de los clientes.'
                  : 'Esta es la categoría que ha recibido el menor número de visitas por parte de los clientes.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Get icon for category
  IconData _getCategoryIcon(String category) {
    // Primero buscar en nuestro mapa de iconos personalizados
    final String iconName = _categoryIconMap[category.toLowerCase()] ?? '';

    if (iconName.isNotEmpty) {
      // Si encontramos un ícono personalizado, usarlo
      return _getIconDataFromName(iconName);
    }

    // Fallback a la lógica original para compatibilidad
    switch (category.toLowerCase()) {
      case 'alcohol':
        return Icons.liquor;
      case 'snacks':
        return Icons.cookie;
      case 'frutas':
        return Icons.shopping_basket; // A basket icon to represent fruits
      case 'vegetales':
        return Icons.eco; // Better icon for vegetables
      case 'carnes':
        return Icons.restaurant_menu;
      case 'lácteos':
      case 'lacteos':
        return Icons.egg;
      case 'panadería':
      case 'panaderia':
        return Icons.bakery_dining;
      case 'bebidas':
        return Icons.local_drink;
      case 'limpieza':
        return Icons.cleaning_services;
      case 'cuidado personal':
        return Icons.face;
      default:
        return Icons.category;
    }
  }

  // Visualizador para distribuciones (edad/sexo)
  Widget _buildDistributionView(dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var entry in data.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: entry.value is int && entry.value > 0
                      ? _normalizeValue(entry.value, data.values)
                      : 0.1,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(2),
                  minHeight: 12,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cantidad: ${entry.value}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Visualizador para categorías preferidas por sexo
  Widget _buildPreferredCategoryView(dynamic data) {
    print('Building preferred category view with data: $data');

    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Extract the data field which contains gender preferences
    var genderData = data['data'] ?? data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminados el título y subtítulo
          const SizedBox(height: 24),

          // Responsive layout for the gender cards
          LayoutBuilder(
            builder: (context, constraints) {
              // Use row for wider screens, column for narrower screens
              bool useRow = constraints.maxWidth > 700;

              if (useRow) {
                // Side by side layout for wider screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildGenderPreferenceCard(
                        gender: 'Male',
                        data: genderData['Male'],
                        isLeft: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGenderPreferenceCard(
                        gender: 'Female',
                        data: genderData['Female'],
                        isLeft: false,
                      ),
                    ),
                  ],
                );
              } else {
                // Stacked layout for narrower screens
                return Column(
                  children: [
                    _buildGenderPreferenceCard(
                      gender: 'Male',
                      data: genderData['Male'],
                      isLeft: true,
                    ),
                    const SizedBox(height: 24),
                    _buildGenderPreferenceCard(
                      gender: 'Female',
                      data: genderData['Female'],
                      isLeft: false,
                    ),
                  ],
                );
              }
            },
          ),

          // Eliminado el texto explicativo de abajo
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Widget to build individual gender preference card
  Widget _buildGenderPreferenceCard({
    required String gender,
    required dynamic data,
    required bool isLeft,
  }) {
    final bool isMale = gender.toLowerCase() == 'male';
    final String title = isMale ? 'Hombres' : 'Mujeres';
    final Color cardColor = isMale
        ? Theme.of(context).brightness == Brightness.dark
            ? Colors.blue.shade900
            : Colors.blue.shade50
        : Theme.of(context).brightness == Brightness.dark
            ? Colors.pink.shade900
            : Colors.pink.shade50;
    final Color accentColor = isMale ? Colors.blue : Colors.pink;
    final IconData genderIcon = isMale ? Icons.man : Icons.woman;

    // Extract data
    String categoryName = data != null && data['category'] != null
        ? data['category'].toString()
        : 'No disponible';
    int visitCount = data != null && data['count'] is int
        ? data['count']
        : int.tryParse(data?['count']?.toString() ?? '0') ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Gender title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  genderIcon,
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Category and visit count
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Category icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(categoryName),
                      size: 72,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Category name
                Text(
                  categoryName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Visit count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 20,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$visitCount visitas',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Visualizador para categorías mejor evaluadas (Ahora Top Visitadas)
  Widget _buildTopCategoriesView(List<dynamic> data) {
    print('Building top categories view with data: $data');

    if (data is! List || data.isEmpty) {
      print(
          'Error: Invalid data format for top categories. Expected non-empty List.');
      return const Center(
        child: Text('No hay datos disponibles para mostrar el ranking.'),
      );
    }

    // Convert data items to Map<String, dynamic>
    List<Map<String, dynamic>> topCategories = data.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      } else {
        try {
          return Map<String, dynamic>.from(item as Map);
        } catch (_) {
          print('Error: Could not convert item to Map<String, dynamic>: $item');
          return <String, dynamic>{};
        }
      }
    }).toList();

    topCategories = topCategories.where((map) => map.isNotEmpty).toList();

    if (topCategories.isEmpty) {
      print('Error: No valid category data after filtering.');
      return const Center(
        child: Text('No hay datos válidos para mostrar el ranking.'),
      );
    }

    // Ensure we have at least one category
    while (topCategories.length < 3) {
      topCategories.add({
        'category': 'N/A',
        'rank': topCategories.length + 1,
        'happy_count': 0
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Top Categorías Mejor Evaluadas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              bool useRow = constraints.maxWidth > 600;
              final children = topCategories.take(3).map((categoryData) {
                // Extract data from the new format
                final rank = categoryData['rank'] as int? ?? 0;
                final category = categoryData['category'] as String? ?? 'Error';

                Widget card = _buildTopCategoryCard(
                  rank: rank,
                  category: category,
                );

                return useRow ? Expanded(child: card) : card;
              }).toList();

              if (useRow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (children.isNotEmpty) children[0],
                    if (children.length > 1) const SizedBox(width: 16),
                    if (children.length > 1) children[1],
                    if (children.length > 2) const SizedBox(width: 16),
                    if (children.length > 2) children[2],
                  ],
                );
              } else {
                return Column(
                  children: [
                    if (children.isNotEmpty) children[0],
                    if (children.length > 1) const SizedBox(height: 16),
                    if (children.length > 1) children[1],
                    if (children.length > 2) const SizedBox(height: 16),
                    if (children.length > 2) children[2],
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Helper widget para una tarjeta del podio (sin mostrar contador)
  Widget _buildTopCategoryCard({
    required int rank,
    required String category,
  }) {
    Color cardColor;
    Color iconColor;
    Color borderColor;
    IconData iconData;

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    switch (rank) {
      case 1:
        cardColor = isDarkMode
            ? Colors.yellow.shade900.withOpacity(0.3)
            : const Color(0xFFFFF9C4);
        iconColor =
            isDarkMode ? Colors.yellow.shade600 : const Color(0xFFFBC02D);
        borderColor =
            isDarkMode ? Colors.yellow.shade700 : const Color(0xFFFBC02D);
        iconData = Icons.emoji_events;
        break;
      case 2:
        cardColor = isDarkMode
            ? Colors.grey.shade800.withOpacity(0.5)
            : const Color(0xFFF5F5F5);
        iconColor = isDarkMode ? Colors.grey.shade400 : const Color(0xFFB0BEC5);
        borderColor =
            isDarkMode ? Colors.grey.shade500 : const Color(0xFFB0BEC5);
        iconData = Icons.military_tech; // Medalla (podría ser diferente)
        break;
      case 3: // Bronce
        cardColor = isDarkMode
            ? Colors.brown.shade800.withOpacity(0.5)
            : const Color(0xFFFFE0B2);
        iconColor = isDarkMode
            ? Colors.brown.shade300
            : const Color(0xFFD7CCC8); // Ajustado para más contraste
        borderColor =
            isDarkMode ? Colors.brown.shade400 : const Color(0xFFA1887F);
        iconData = Icons.military_tech; // Medalla
        break;
      default:
        cardColor = Colors.grey.shade200;
        iconColor = Colors.grey.shade600;
        borderColor = Colors.grey.shade400;
        iconData = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      constraints: const BoxConstraints(
          minHeight: 220), // Altura mínima para consistencia
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Espaciar elementos verticalmente
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono
          Icon(
            iconData,
            size: 48,
            color: iconColor,
          ),
          const SizedBox(height: 16),

          // Nombre de la categoría
          Text(
            category,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16), // Keep spacing before rank

          // Ranking
          Text(
            '#$rank',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor, // Usar el color del icono para el rank
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Normaliza un valor para visualizaciones de barras
  double _normalizeValue(int value, Iterable<dynamic> allValues) {
    final max =
        allValues.fold<int>(0, (prev, e) => e is int && e > prev ? e : prev);
    if (max == 0) return 0.1; // valor mínimo para visualización
    return value / max;
  }

  IconData _getIconForStatistic(String statType) {
    switch (statType) {
      case 'peak-hours':
        return Icons.access_time;
      case 'least-hours':
        return Icons.access_time_filled;
      case 'busy-days':
        return Icons.calendar_today;
      case 'least-days':
        return Icons.calendar_month;
      case 'most-frequent-emotions':
        return Icons.emoji_emotions;
      case 'gender-distribution':
        return Icons.people;
      case 'age-distribution':
        return Icons.person;
      case 'gender-age-combined':
        return Icons.groups;
      case 'emotion-percentage':
        return Icons.pie_chart;
      case 'emotion-comparison':
        return Icons.compare;
      // Iconos para las nuevas estadísticas
      case 'least-visited-historical':
        return Icons.trending_down;
      case 'most-visited-historical':
        return Icons.trending_up;
      case 'visited-categories-historical':
        return Icons.history;
      case 'preferred-category-by-gender':
        return Icons.category;
      case 'top-successful-categories':
        return Icons.star;
      case 'emotional-differences-by-category':
        return Icons.mood;
      case 'age-gender-distribution-by-category':
        return Icons.groups;
      default:
        return Icons.bar_chart;
    }
  }

  // Visualizador para horas pico y horas menos concurridas (gráfico de puntos)
  Widget _buildHoursChart(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Convertir datos para el gráfico
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
    final sortedEntries = data.entries.toList();
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

    // Titulo del gráfico según el tipo de estadística
    final String chartTitle = _selectedStat == 'peak-hours'
        ? 'Horas con mayor afluencia de clientes'
        : 'Horas con menor afluencia de clientes';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(builder: (context, constraints) {
        // Adjust chart based on available width
        double chartHeight = constraints.maxWidth > 600 ? 300 : 250;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              chartTitle,
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
                margin: const EdgeInsets.all(0),
                primaryXAxis: CategoryAxis(
                  title: AxisTitle(text: 'Día de la semana'),
                  labelIntersectAction: AxisLabelIntersectAction.rotate45,
                  labelRotation: constraints.maxWidth < 400 ? 45 : 0,
                  maximumLabels: constraints.maxWidth < 400 ? 6 : 12,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Hora del día'),
                  labelFormat: '{value}:00',
                  minimum: 0,
                  maximum: 24,
                  interval: 4,
                ),
                legend: Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'punto: {point.fullLabel}',
                ),
                zoomPanBehavior: ZoomPanBehavior(
                  enablePanning: true,
                  enablePinching: true,
                  enableDoubleTapZooming: true,
                  enableSelectionZooming: true,
                  enableMouseWheelZooming: true,
                ),
                series: <CartesianSeries>[
                  LineSeries<HourData, String>(
                    dataSource: chartData,
                    xValueMapper: (HourData data, _) => data.hour,
                    yValueMapper: (HourData data, _) => data.count,
                    name: 'Horas',
                    color: Theme.of(context).colorScheme.primary,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 8,
                      width: 8,
                      shape: DataMarkerType.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leyenda alineada exactamente con los días de la semana del eje X
            Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: chartData.map((data) {
                  // Cada tarjeta tiene el mismo ancho relativo para alinearse con su punto en el gráfico
                  return Container(
                    width: (constraints.maxWidth / chartData.length) - 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.fullLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: constraints.maxWidth > 600 ? 12 : 10,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Visualizador para días más y menos concurridos
  Widget _buildCombinedDaysView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Obtener directamente los nombres de los días
    String mostBusyDayEn = data['data']?['most_busy_day'] as String? ??
        data['most_busy_day'] as String? ??
        'No disponible';
    String leastBusyDayEn = data['data']?['least_busy_day'] as String? ??
        data['least_busy_day'] as String? ??
        'No disponible';

    // Traducir días de inglés a español si es necesario
    final Map<String, String> dayTranslations = {
      'Monday': 'Lunes',
      'Tuesday': 'Martes',
      'Wednesday': 'Miércoles',
      'Thursday': 'Jueves',
      'Friday': 'Viernes',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo'
    };

    // Traducir los días
    String mostBusyDayName = dayTranslations[mostBusyDayEn] ?? mostBusyDayEn;
    String leastBusyDayName = dayTranslations[leastBusyDayEn] ?? leastBusyDayEn;

    // Calcular fechas para la semana anterior (7 días hasta hoy)
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    // Crear una lista de días en el rango de la semana anterior hasta hoy
    final List<Map<String, dynamic>> pastWeekDaysInfo = [];

    // Generar información para cada día de la semana pasada
    for (int i = 0; i < 7; i++) {
      final date = weekAgo.add(Duration(days: i));
      // Format weekday name in Spanish
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

      // Get initial letter of the day
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminamos el título pero mantenemos el espacio
          const SizedBox(height: 24),

          // Calendario semanal (diseño según la imagen)
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

                // Días de la semana en formato visual similar a la imagen
                LayoutBuilder(builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: pastWeekDaysInfo.map((dayInfo) {
                      // Determinamos si es el día más o menos concurrido
                      final bool isMostBusy = dayInfo['isMostBusy'];
                      final bool isLeastBusy = dayInfo['isLeastBusy'];

                      // Color del día basado en los criterios
                      Color? bgColor;
                      if (isMostBusy) {
                        bgColor = const Color(0xFFE8F5E9); // Verde claro
                      } else if (isLeastBusy) {
                        bgColor = const Color(0xFFFFF3E0); // Naranja claro
                      }

                      return _buildCalendarDay(
                        letter: dayInfo['letter'],
                        fullName: dayInfo['full'],
                        date: dayInfo['date'].toString(),
                        isHighlighted: isMostBusy || isLeastBusy,
                        bgColor: bgColor,
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tarjetas de información según la imagen
          Row(
            children: [
              // Tarjeta día más concurrido (verde claro)
              Expanded(
                child: Container(
                  height:
                      300, // Establecer altura fija para igualar las tarjetas de categorías
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // Verde claro
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono y título
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
                      // Añadir espacio para que el contenido sea más alto
                      const SizedBox(height: 48),

                      // Círculo con icono (similar a la tarjeta de categoría)
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.calendar_today,
                              size: 40,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Día de la semana centrado en grande
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

                      const Spacer(), // Espacio flexible para empujar el siguiente elemento hacia abajo

                      // Indicador de afluencia en la parte inferior
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mayor afluencia',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Tarjeta día menos concurrido (naranja claro)
              Expanded(
                child: Container(
                  height:
                      300, // Establecer altura fija para igualar las tarjetas de categorías
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0), // Naranja claro
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono y título
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
                      // Añadir espacio para que el contenido sea más alto
                      const SizedBox(height: 48),

                      // Círculo con icono (similar a la tarjeta de categoría)
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.calendar_today,
                              size: 40,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Día de la semana centrado en grande
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

                      const Spacer(), // Espacio flexible para empujar el siguiente elemento hacia abajo

                      // Indicador de afluencia en la parte inferior
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 20,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Menor afluencia',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
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
        ],
      ),
    );
  }

  // Widget para mostrar un día en el calendario semanal
  Widget _buildCalendarDay({
    required String letter,
    required String fullName,
    required String date,
    bool isHighlighted = false,
    Color? bgColor,
  }) {
    return Column(
      children: [
        // Letra del día (M, J, V, etc.)
        Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Nombre completo del día
        Text(
          fullName,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        // Número del día con círculo/fondo si está resaltado
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  // Visualizador para días más y menos concurridos
  Widget _buildDaysHighlight(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Convertir datos para el gráfico
    final List<DayData> chartData = [];

    // Obtener y ordenar entradas por día de la semana (lunes a domingo)
    final Map<String, int> dayOrder = {
      'Lunes': 1,
      'Martes': 2,
      'Miércoles': 3,
      'Jueves': 4,
      'Viernes': 5,
      'Sábado': 6,
      'Domingo': 7
    };

    final sortedEntries = data.entries.toList();
    sortedEntries.sort((a, b) {
      final int dayA = dayOrder[a.key.toString()] ?? 0;
      final int dayB = dayOrder[b.key.toString()] ?? 0;
      return dayA.compareTo(dayB);
    });

    for (var entry in sortedEntries) {
      chartData.add(DayData(
        day: entry.key.toString(),
        count: (entry.value as num).toInt(),
      ));
    }

    // Título del gráfico según el tipo de estadística
    final String chartTitle = _selectedStat == 'busy-days'
        ? 'Días con mayor afluencia de clientes'
        : 'Días con menor afluencia de clientes';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            chartTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cantidad de visitantes por día de la semana',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                title: AxisTitle(text: 'Día'),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Visitantes'),
              ),
              legend: Legend(isVisible: false),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                ColumnSeries<DayData, String>(
                  dataSource: chartData,
                  xValueMapper: (DayData data, _) => data.day,
                  yValueMapper: (DayData data, _) => data.count,
                  name: 'Visitantes',
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tarjetas de resumen
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: chartData.map((data) {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.day,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${data.count} visitantes',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Visualizador para categorías más y menos visitadas (gráfico de barras)
  Widget _buildCategoryBarChart(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Convertir datos para el gráfico
    final List<CategoryData> chartData = [];

    // Ordenamos las categorías según visitantes (mayor a menor o menor a mayor)
    final sortedEntries = data.entries.toList();
    if (_selectedStat == 'most-visited' ||
        _selectedStat == 'most-visited-historical') {
      sortedEntries.sort((a, b) => (b.value as num).compareTo(a.value as num));
    } else {
      sortedEntries.sort((a, b) => (a.value as num).compareTo(b.value as num));
    }

    for (var entry in sortedEntries) {
      chartData.add(CategoryData(
        category: entry.key.toString(),
        count: (entry.value as num).toInt(),
      ));
    }

    // Título del gráfico según el tipo de estadística
    String chartTitle;
    if (_selectedStat == 'most-visited') {
      chartTitle = 'Categorías más visitadas';
    } else if (_selectedStat == 'most-visited-historical') {
      chartTitle = 'Categorías más visitadas históricamente';
    } else if (_selectedStat == 'least-visited') {
      chartTitle = 'Categorías menos visitadas';
    } else {
      chartTitle = 'Categorías menos visitadas históricamente';
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(builder: (context, constraints) {
        // Adjust chart height based on container width
        double chartHeight = constraints.maxWidth > 600 ? 300 : 250;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              chartTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cantidad de visitantes por categoría',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              width: constraints.maxWidth,
              child: SfCartesianChart(
                margin: const EdgeInsets.all(10),
                primaryXAxis: CategoryAxis(
                  title: AxisTitle(text: 'Categoría'),
                  labelRotation: 45,
                  labelAlignment: LabelAlignment.start,
                  maximumLabels: constraints.maxWidth < 400 ? 3 : 6,
                  labelIntersectAction: AxisLabelIntersectAction.rotate45,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Visitantes'),
                  labelFormat: '{value}',
                ),
                legend: Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                zoomPanBehavior: ZoomPanBehavior(
                  enablePanning: true,
                  enablePinching: true,
                  enableDoubleTapZooming: true,
                  enableSelectionZooming: true,
                  enableMouseWheelZooming: true,
                ),
                series: <CartesianSeries>[
                  ColumnSeries<CategoryData, String>(
                    dataSource: chartData,
                    xValueMapper: (CategoryData data, _) => data.category,
                    yValueMapper: (CategoryData data, _) => data.count,
                    name: 'Visitantes',
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                    width: 0.7, // Makes bars thinner to fit better
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Responsive cards layout
            constraints.maxWidth > 500
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: _buildCategoryCards(chartData),
                  )
                : SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _buildCategoryCards(chartData,
                          isHorizontalScroll: true),
                    ),
                  ),
          ],
        );
      }),
    );
  }

  List<Widget> _buildCategoryCards(List<CategoryData> chartData,
      {bool isHorizontalScroll = false}) {
    return chartData.map((data) {
      return Container(
        width: isHorizontalScroll ? 160 : null,
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.only(right: 8, bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  data.category,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${data.count} visitantes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // Visualizador para porcentaje de emociones (gráfico circular)
  Widget _buildEmotionPieChart(dynamic data) {
    if (data is! Map || data.isEmpty) {
      print('Error: emotion-percentage data is empty or not a map: $data');
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Debug log the data structure
    print('Emotion percentage data: $data');
    print('Data type: ${data.runtimeType}');
    print('Categories: ${data.keys.toList()}');

    // Create pie charts for each category
    List<Widget> categoryCharts = [];

    try {
      data.forEach((category, emotionData) {
        if (emotionData is Map) {
          // Convert emotion data to chart data
          List<EmotionPercentageData> chartData = [];

          emotionData.forEach((emotion, percentage) {
            if (percentage is num) {
              chartData.add(EmotionPercentageData(
                emotion: emotion.toString(),
                percentage: percentage.toDouble(),
              ));
            }
          });

          // Only create chart if we have data
          if (chartData.isNotEmpty) {
            // Sort by percentage descending for better visualization
            chartData.sort((a, b) => b.percentage.compareTo(a.percentage));

            // Create a card with pie chart for this category
            categoryCharts.add(
              SizedBox(
                width: 320, // Increased from 240 to make charts larger
                height: 320, // Increased from 240 to make charts larger
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.all(8), // Increased margin
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category title
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16), // Larger padding
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 16, // Increased font size
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Pie chart
                      SizedBox(
                        height: 180, // Increased from 130 to make chart larger
                        child: SfCircularChart(
                          margin: EdgeInsets.zero,
                          legend: Legend(isVisible: false),
                          series: <CircularSeries>[
                            DoughnutSeries<EmotionPercentageData, String>(
                              dataSource: chartData,
                              xValueMapper: (EmotionPercentageData data, _) =>
                                  _translateEmotion(data.emotion),
                              yValueMapper: (EmotionPercentageData data, _) =>
                                  data.percentage,
                              pointColorMapper:
                                  (EmotionPercentageData data, _) =>
                                      _getEmotionColorForChart(data.emotion),
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: false),
                              enableTooltip: true,
                              innerRadius: '60%',
                            ),
                          ],
                        ),
                      ),

                      // Legend text below
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              top: 0), // Adjusted padding
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4, // More spacing
                            runSpacing: 4, // More spacing
                            children: chartData.map((data) {
                              final emotionColor =
                                  _getEmotionColorForChart(data.emotion);

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3), // More padding
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: emotionColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: emotionColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, // Slightly larger dot
                                      height: 8, // Slightly larger dot
                                      decoration: BoxDecoration(
                                        color: emotionColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_translateEmotion(data.emotion)}: ${data.percentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 12, // Increased font size
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
      });
    } catch (e) {
      print('Error rendering emotion pie charts: $e');
      return Center(child: Text('Error: $e'));
    }

    if (categoryCharts.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Changed: Use SingleChildScrollView for the whole view instead of nested scrolling
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminados el título y subtítulo
          const SizedBox(height: 16), // Added spacing

          // Center the horizontally scrollable row of charts
          Center(
            child: Column(
              children: categoryCharts.isEmpty
                  ? [const Center(child: Text('No hay datos disponibles'))]
                  : _arrangeChartsInPairs(categoryCharts),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get specific colors for emotion chart
  Color _getEmotionColorForChart(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green; // Feliz
      case 'sad':
        return Colors.blue; // Triste
      case 'surprise':
      case 'surprised':
        return Colors.amber; // Sorprendido
      case 'neutral':
        return Colors.grey; // Neutral
      case 'angry':
        return Colors.red; // Enojado
      case 'fear':
        return Colors.purple; // Miedo
      case 'disgust':
        return Colors.brown; // Disgusto
      case 'calm':
        return Colors.lightBlue; // Calmado
      case 'confused':
        return Colors.blueGrey; // Confundido
      case 'anxious':
        return Colors.orange; // Ansioso
      case 'bored':
        return Colors.grey.shade700; // Aburrido
      case 'excited':
        return Colors.pink; // Emocionado
      case 'stressed':
        return Colors.deepOrange; // Estresado
      case 'tired':
        return Colors.indigo; // Cansado
      case 'content':
        return Colors.lightGreen; // Contento
      case 'disappointed':
        return Colors.redAccent; // Decepcionado
      case 'annoyed':
        return Colors.deepPurple; // Irritado
      case 'hopeful':
        return Colors.cyan; // Esperanzado
      case 'frustrated':
        return Colors.amber.shade900; // Frustrado
      default:
        return Colors.grey;
    }
  }

  // Helper to get appropriate color for each emotion
  Color _getEmotionColor(String emotion, int index, List<Color> colors) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return colors[0];
      case 'neutral':
        return colors[1];
      case 'sad':
        return colors[2];
      case 'surprise':
        return colors[3];
      case 'angry':
        return colors[4];
      case 'fear':
        return colors[5];
      case 'disgust':
        return colors[6];
      default:
        return colors[index % colors.length];
    }
  }

  // Helper to translate emotions to Spanish
  String _translateEmotion(String emotion) {
    switch (emotion.toUpperCase()) {
      case 'HAPPY':
        return 'Feliz';
      case 'NEUTRAL':
        return 'Neutral';
      case 'SAD':
        return 'Triste';
      case 'SURPRISE':
      case 'SURPRISED':
        return 'Sorprendido';
      case 'ANGRY':
        return 'Enojado';
      case 'FEAR':
        return 'Miedo';
      case 'DISGUST':
        return 'Disgusto';
      case 'CALM':
        return 'Calmado';
      case 'CONFUSED':
        return 'Confundido';
      case 'ANXIOUS':
        return 'Ansioso';
      case 'BORED':
        return 'Aburrido';
      case 'EXCITED':
        return 'Emocionado';
      case 'STRESSED':
        return 'Estresado';
      case 'TIRED':
        return 'Cansado';
      case 'CONTENT':
        return 'Contento';
      case 'DISAPPOINTED':
        return 'Decepcionado';
      case 'ANNOYED':
        return 'Irritado';
      case 'HOPEFUL':
        return 'Esperanzado';
      case 'FRUSTRATED':
        return 'Frustrado';
      default:
        return emotion;
    }
  }

  // Visualizador simplificado para emociones más frecuentes por categoría
  Widget _buildFrequentEmotionsView(dynamic data) {
    print('Building frequent emotions view with data: $data');

    // Directly check if data is a Map and not null/empty
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    List<Widget> emotionCards = [];

    try {
      // Convertir el mapa a una lista de entradas y ordenar por conteo descendente
      final sortedEmotions = data.entries.toList();
      sortedEmotions.sort((a, b) {
        final countA = (a.value is int) ? a.value : 0;
        final countB = (b.value is int) ? b.value : 0;
        return countB.compareTo(countA); // Descending order
      });

      for (var entry in sortedEmotions) {
        final emotion = entry.key.toString();
        final count = (entry.value is int) ? entry.value : 0;
        final translatedEmotion = _translateEmotion(emotion);
        final icon = _getEmotionIcon(emotion);
        final color = _getEmotionColorForCard(emotion);

        emotionCards.add(
          Card(
            elevation: 2,
            color:
                Theme.of(context).cardColor, // Usa el color de fondo del tema
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 180, // Increased width from 150 to 180
              padding: const EdgeInsets.symmetric(
                  vertical: 20, horizontal: 16), // Added vertical padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icono de la emoción
                  Icon(
                    icon,
                    size: 48, // Increased icon size from 40 to 48
                    color: color,
                  ),
                  const SizedBox(height: 16), // Increased spacing

                  // Nombre de la emoción
                  Text(
                    translatedEmotion,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Conteo
                  Text(
                    '$count clientes',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error rendering emotion cards: $e');
      return Center(child: Text('Error: $e'));
    }

    if (emotionCards.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Usar Wrap para un diseño responsive
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Alineado a la izquierda
        children: [
          // Eliminamos el título y subtítulo
          const SizedBox(height: 24),

          // Usar Wrap para que las tarjetas se ajusten
          Center(
            child: Wrap(
              spacing: 16, // Espacio horizontal
              runSpacing: 16, // Espacio vertical
              alignment: WrapAlignment.center, // Centrar las tarjetas
              children: emotionCards,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get specific color for emotion card styling
  Color _getEmotionColorForCard(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'calm':
        return Colors.teal;
      case 'surprise':
      case 'surprised':
        return Colors.amber;
      case 'angry':
        return Colors.red;
      case 'fear':
        return Colors.purple;
      case 'disgust':
        return Colors.brown;
      case 'neutral':
        return Colors.grey;
      case 'confused':
        return Colors.blueGrey;
      case 'anxious':
        return Colors.orange;
      case 'bored':
        return Colors.grey.shade700;
      case 'excited':
        return Colors.pink;
      case 'stressed':
        return Colors.deepOrange;
      case 'tired':
        return Colors.indigo;
      case 'content':
        return Colors.lightGreen;
      case 'disappointed':
        return Colors.redAccent;
      case 'annoyed':
        return Colors.deepPurple;
      case 'hopeful':
        return Colors.cyan;
      case 'frustrated':
        return Colors.amber.shade900;
      default:
        return Theme.of(context).colorScheme.primary; // Color por defecto
    }
  }

  // Visualizador para comparación de emociones por día
  Widget _buildEmotionComparisonChart(dynamic data) {
    print(
        'Building statistics data view for emotion-comparison with raw data: $data');

    // Check if the data is in the expected format with nested 'data' object
    if (data is Map && data.containsKey('data')) {
      // Extract the actual emotion data from the nested 'data' key
      data = data['data'];
      print('Extracted nested data: $data');
    }

    if (data is! Map || data.isEmpty) {
      print('Error: Invalid or empty data format for emotion comparison');
      return const Center(child: Text('No hay datos disponibles'));
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
      'TOTALS': 'Totales',
    };

    // Orden de los días para la tabla
    final List<String> orderedDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
      'TOTALS'
    ];

    // Extraer datos de la respuesta
    List<Map<String, dynamic>> tableData = [];
    Map<String, dynamic> periodInfo = {};

    // Check for period_info
    if (data.containsKey('period_info')) {
      periodInfo = data['period_info'] as Map<String, dynamic>? ?? {};
    }

    // Loop through the days and extract the emotion counts
    bool hasData = false; // Track if we have any non-zero data

    for (var day in orderedDays) {
      if (!data.containsKey(day)) continue;

      final dayData = data[day] as Map<String, dynamic>? ?? {};
      final happyCount = dayData['HAPPY'] ?? 0;
      final sadCount = dayData['SAD'] ?? 0;

      if (happyCount > 0 || sadCount > 0) {
        hasData = true;
      }

      // Determinar ganador del día
      String winner = "none";
      if (happyCount > sadCount) {
        winner = "happy";
      } else if (sadCount > happyCount) {
        winner = "sad";
      } else if (happyCount > 0) {
        // Tie if counts are equal and non-zero
        winner = "tie";
      }

      tableData.add({
        'day': dayTranslations[day] ?? day,
        'happy': happyCount,
        'sad': sadCount,
        'winner': winner,
        'isTotal': day == 'TOTALS'
      });
    }

    // If no data was found, display the "no data" message
    if (!hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_neutral, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No hay datos de emociones registrados',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    // Colores para las emociones
    final Map<String, Color> emotionColors = {
      'HAPPY': Colors.green,
      'SAD': Colors.blue,
    };

    // Determinar el título según el período
    String title;
    if (periodInfo['period'] == 'week') {
      title = 'Comparación Semanal de Emociones';
    } else if (periodInfo['period'] == 'month') {
      final monthName = periodInfo['month'] != null
          ? DateFormat('MMMM', 'es').format(DateTime(2022, periodInfo['month']))
          : 'Mes Actual';
      final year = periodInfo['year'] ?? DateTime.now().year;
      title = 'Comparación Mensual de Emociones ($monthName $year)';
    } else {
      title = 'Comparación de Emociones por Día';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminamos título y descripción
          const SizedBox(height: 8),
          const SizedBox(height: 16),

          // Leyenda
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildEmotionLegendItem('Feliz', emotionColors['HAPPY']!,
                    Icons.sentiment_very_satisfied),
                _buildEmotionLegendItem('Triste', emotionColors['SAD']!,
                    Icons.sentiment_very_dissatisfied),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text('Mayor', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_down,
                        color: Colors.grey, size: 18),
                    const SizedBox(width: 4),
                    Text('Menor', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.balance, color: Colors.purple, size: 18),
                    const SizedBox(width: 4),
                    Text('Empate',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),

          // Table Container - giving it a fixed width constraint to ensure it's visible
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DataTable(
                  columnSpacing: 8.0,
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 48,
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('Día')),
                    DataColumn(label: Text('Feliz'), numeric: true),
                    DataColumn(label: Text('Triste'), numeric: true),
                  ],
                  rows: tableData.map((dayData) {
                    final isTotal = dayData['isTotal'] == true;
                    return DataRow(
                      color:
                          MaterialStateProperty.resolveWith<Color?>((states) {
                        if (isTotal)
                          return Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1);
                        if (tableData.indexOf(dayData) % 2 != 0)
                          return Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.03);
                        return null;
                      }),
                      cells: [
                        DataCell(Text(dayData['day'],
                            style: TextStyle(
                                fontWeight: isTotal
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
                        DataCell(_buildEmotionCountCell(
                          dayData['happy'],
                          emotionColors['HAPPY']!,
                          (!isTotal && dayData['winner'] == 'happy')
                              ? Icons.emoji_events
                              : ((!isTotal && dayData['winner'] == 'sad')
                                  ? Icons.trending_down
                                  : null),
                          isWinner: (!isTotal && dayData['winner'] == 'happy'),
                          isTie: (!isTotal && dayData['winner'] == 'tie'),
                        )),
                        DataCell(_buildEmotionCountCell(
                          dayData['sad'],
                          emotionColors['SAD']!,
                          (!isTotal && dayData['winner'] == 'sad')
                              ? Icons.emoji_events
                              : ((!isTotal && dayData['winner'] == 'happy')
                                  ? Icons.trending_down
                                  : null),
                          isWinner: (!isTotal && dayData['winner'] == 'sad'),
                          isTie: (!isTotal && dayData['winner'] == 'tie'),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Resumen ganador general
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildTotalEmotionsWidget(tableData),
          ),
        ],
      ),
    );
  }

  // Construir celda de conteo de emociones con ícono (Updated for DataTable)
  Widget _buildEmotionCountCell(int count, Color color, IconData? iconData,
      {bool isWinner = false, bool isTie = false}) {
    // Added isWinner flag
    Color iconColor = Colors.grey;
    if (isWinner) iconColor = Colors.amber; // Winner icon is amber
    if (isTie) iconColor = Colors.purple; // Tie icon is purple

    return Row(
      mainAxisAlignment: MainAxisAlignment.end, // Align numeric content to end
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: isWinner || isTie
                ? FontWeight.bold
                : FontWeight.normal, // Bold if winner or tie
            fontSize: 13, // Consistent font size
            color: count > 0
                ? null
                : Colors.grey, // Use default color or grey if zero
          ),
        ),
        if (iconData != null && !isTie) ...[
          const SizedBox(width: 4),
          Icon(
            iconData,
            size: 16, // Smaller icon
            color: iconColor, // Use determined icon color
          ),
        ],
        // Show the balance icon for ties
        if (isTie) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.balance,
            size: 16,
            color: iconColor, // Purple for ties
          ),
        ],
      ],
    );
  }

  // Construir elemento de leyenda para emociones
  Widget _buildEmotionLegendItem(String label, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  // Construir widget de resumen total
  Widget _buildTotalEmotionsWidget(List<Map<String, dynamic>> data) {
    // Calcular totales directamente de los datos de la tabla que recibimos
    int totalHappy = 0;
    int totalSad = 0;

    // Find the total row in the data directly
    final totalRow = data.firstWhere(
      (row) => row['isTotal'] == true,
      orElse: () => {'happy': 0, 'sad': 0, 'isTotal': true},
    );

    // Use the values from the TOTALS row
    totalHappy = totalRow['happy'] as int;
    totalSad = totalRow['sad'] as int;

    print('Total counts from data: HAPPY=$totalHappy, SAD=$totalSad');

    String winnerText;
    IconData winnerIcon;
    Color winnerColor;

    if (totalHappy > totalSad) {
      winnerText = "Feliz es la emoción predominante";
      winnerIcon = Icons.sentiment_very_satisfied;
      winnerColor = Colors.green;
    } else if (totalSad > totalHappy) {
      winnerText = "Triste es la emoción predominante";
      winnerIcon = Icons.sentiment_very_dissatisfied;
      winnerColor = Colors.blue;
    } else if (totalHappy == 0 && totalSad == 0) {
      winnerText = "No hay datos de emociones registrados";
      winnerIcon = Icons.sentiment_neutral;
      winnerColor = Colors.grey;
    } else {
      winnerText = "Las emociones están empatadas";
      winnerIcon = Icons.balance;
      winnerColor = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: winnerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: winnerColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                winnerIcon,
                color: winnerColor,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                winnerText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: winnerColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTotalCountWidget(
                "Total Feliz",
                totalHappy,
                Colors.green,
                Icons.sentiment_very_satisfied,
              ),
              _buildTotalCountWidget(
                "Total Triste",
                totalSad,
                Colors.blue,
                Icons.sentiment_very_dissatisfied,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Construir widget de conteo total para una emoción
  Widget _buildTotalCountWidget(
      String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: count > 0 ? color : Colors.grey,
          ),
        ),
      ],
    );
  }

  // Visualizador para diferencias emocionales por categoría con íconos de sexo
  Widget _buildEmotionalDifferencesByCategoryView(dynamic data) {
    print('Building emotional differences by category with data: $data');

    if (data == null || data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Extract the data object which contains categories and gender emotions
    Map<String, dynamic> emotionalData;

    if (data.containsKey("data")) {
      emotionalData = Map<String, dynamic>.from(data["data"]);
    } else {
      emotionalData = Map<String, dynamic>.from(data);
    }

    if (emotionalData.isEmpty) {
      return const Center(child: Text('No se encontraron datos emocionales'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Definir íconos y colores para las emociones
    final Map<String, Map<String, dynamic>> emotionInfo = {
      'HAPPY': {
        'icon': Icons.sentiment_very_satisfied,
        'color': Colors.green,
        'label': 'Feliz'
      },
      'SAD': {
        'icon': Icons.sentiment_very_dissatisfied,
        'color': Colors.red.shade700,
        'label': 'Triste'
      },
      'CALM': {
        'icon': Icons.sentiment_neutral,
        'color': Colors.blue,
        'label': 'Calmado'
      },
      'SURPRISED': {
        'icon': Icons.sentiment_satisfied_alt,
        'color': Colors.amber,
        'label': 'Sorprendido'
      },
      'SURPRISE': {
        'icon': Icons.sentiment_satisfied_alt,
        'color': Colors.amber,
        'label': 'Sorprendido'
      },
      'ANGRY': {
        'icon': Icons.mood_bad,
        'color': Colors.deepOrange,
        'label': 'Enojado'
      },
      'FEAR': {
        'icon': Icons.face_retouching_natural,
        'color': Colors.purple,
        'label': 'Miedo'
      },
      'DISGUST': {
        'icon': Icons.sick,
        'color': Colors.brown,
        'label': 'Disgusto'
      },
      'NEUTRAL': {
        'icon': Icons.sentiment_neutral,
        'color': Colors.grey,
        'label': 'Neutral'
      },
      'CONFUSED': {
        'icon': Icons.psychology,
        'color': Colors.blueGrey,
        'label': 'Confundido'
      },
      'ANXIOUS': {
        'icon': Icons.running_with_errors,
        'color': Colors.orange,
        'label': 'Ansioso'
      },
      'BORED': {
        'icon': Icons.bedtime,
        'color': Colors.grey.shade700,
        'label': 'Aburrido'
      },
      'EXCITED': {
        'icon': Icons.emoji_emotions,
        'color': Colors.pink,
        'label': 'Emocionado'
      },
      'STRESSED': {
        'icon': Icons.warning_amber,
        'color': Colors.deepOrange,
        'label': 'Estresado'
      },
      'TIRED': {
        'icon': Icons.hotel,
        'color': Colors.indigo,
        'label': 'Cansado'
      },
      'CONTENT': {
        'icon': Icons.sentiment_satisfied_alt,
        'color': Colors.lightGreen,
        'label': 'Contento'
      },
      'DISAPPOINTED': {
        'icon': Icons.thumb_down_alt,
        'color': Colors.redAccent,
        'label': 'Decepcionado'
      },
      'ANNOYED': {
        'icon': Icons.highlight_off,
        'color': Colors.deepPurple,
        'label': 'Irritado'
      },
      'HOPEFUL': {
        'icon': Icons.emoji_nature,
        'color': Colors.cyan,
        'label': 'Esperanzado'
      },
      'FRUSTRATED': {
        'icon': Icons.do_not_disturb,
        'color': Colors.amber.shade900,
        'label': 'Frustrado'
      }
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eliminados el título y subtítulo
          const SizedBox(height: 24),

          // Category cards
          ...emotionalData.entries.map((entry) {
            final String categoryName = entry.key;
            final Map<String, dynamic> genderData =
                Map<String, dynamic>.from(entry.value);

            return Card(
              margin: const EdgeInsets.only(bottom: 24.0),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(categoryName),
                          size: 28,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          categoryName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Gender sections
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Male section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Male header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.man,
                                    size: 22,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hombres',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Male emotion cards
                              if (genderData.containsKey('male') &&
                                  genderData['male'] is Map &&
                                  genderData['male'].isNotEmpty)
                                ...genderData['male'].entries.map((emotion) {
                                  final String emotionName = emotion.key;
                                  final int count = emotion.value;

                                  final emotionData =
                                      emotionInfo.containsKey(emotionName)
                                          ? emotionInfo[emotionName]!
                                          : {
                                              'icon': Icons.emoji_emotions,
                                              'color': Colors.grey,
                                              'label': emotionName
                                            };

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          emotionData['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: emotionData['color']
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              emotionData['icon'],
                                              size: 20,
                                              color: emotionData['color'],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              emotionData['label'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: emotionData['color'],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: emotionData['color']
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: emotionData['color'],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Text(
                                      'No hay datos para hombres',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Vertical divider
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 1,
                          height: 200, // Adjust height based on content
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),

                        // Female section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Female header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.woman,
                                    size: 22,
                                    color: Colors.pink.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mujeres',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.pink.shade400,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Female emotion cards
                              if (genderData.containsKey('female') &&
                                  genderData['female'] is Map &&
                                  genderData['female'].isNotEmpty)
                                ...genderData['female'].entries.map((emotion) {
                                  final String emotionName = emotion.key;
                                  final int count = emotion.value;

                                  final emotionData =
                                      emotionInfo.containsKey(emotionName)
                                          ? emotionInfo[emotionName]!
                                          : {
                                              'icon': Icons.emoji_emotions,
                                              'color': Colors.grey,
                                              'label': emotionName
                                            };

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          emotionData['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: emotionData['color']
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              emotionData['icon'],
                                              size: 20,
                                              color: emotionData['color'],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              emotionData['label'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: emotionData['color'],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: emotionData['color']
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: emotionData['color'],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Text(
                                      'No hay datos para mujeres',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
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
            );
          }).toList(),
        ],
      ),
    );
  }

  // NEW: Visualizador para distribución de edad y sexo por categoría
  // Mantener el estado del panel expandido y del sexo seleccionado
  final Map<String, bool> _expandedCategories =
      {}; // Use a map to track expanded state per category
  String? _expandedCategoryName; // Track which category is expanded by name
  final Map<String, String> _selectedGenderForCategory =
      {}; // category -> 'Male' or 'Female'

  Widget _buildAgeGenderDistributionByCategory(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(
          child: Text('No hay datos disponibles para esta estadística.'));
    }

    // Convertir data (Map<String, List<Map<String, dynamic>>>) a una lista de entradas
    final List<MapEntry<String, dynamic>> categories =
        (data as Map<String, dynamic>).entries.toList();
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: categories.map((entry) {
          String categoryName = entry.key;
          List<dynamic> distributionList =
              entry.value; // List of maps for the category

          // Ensure gender is selected for the current category
          if (!_selectedGenderForCategory.containsKey(categoryName)) {
            _selectedGenderForCategory[categoryName] = 'Male'; // Default
          }
          String selectedGender = _selectedGenderForCategory[categoryName]!;

          // Filtrar la lista por el sexo seleccionado
          List<Map<String, dynamic>> filteredData = distributionList
              .where((item) => item['gender'] == selectedGender)
              .map((item) => Map<String, dynamic>.from(item)) // Ensure Map type
              .toList();

          // Ordenar los rangos de edad
          filteredData.sort((a, b) {
            // Simple sort based on the start of the age range string
            String rangeA = a['age_range'] ?? '';
            String rangeB = b['age_range'] ?? '';
            int startAgeA =
                int.tryParse(rangeA.split('-').first.replaceAll('+', '')) ?? 0;
            int startAgeB =
                int.tryParse(rangeB.split('-').first.replaceAll('+', '')) ?? 0;
            return startAgeA.compareTo(startAgeB);
          });

          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            surfaceTintColor: colorScheme.surfaceVariant.withOpacity(0.1),
            elevation: 3, // Slightly higher elevation for Material Design feel
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ExpansionTile(
              key:
                  Key(categoryName), // Important for preserving expansion state
              initiallyExpanded: _expandedCategoryName == categoryName,
              onExpansionChanged: (expanded) {
                setState(() {
                  // If expanding this tile, close any others by setting this as the only expanded one
                  // If collapsing, just set to null
                  _expandedCategoryName = expanded ? categoryName : null;

                  // If expanding, ensure the gender selection is reset to default
                  if (expanded) {
                    _selectedGenderForCategory[categoryName] = 'Male';
                  }
                });
              },
              // Add Material Design animation and style properties
              maintainState:
                  true, // Maintain state when collapsed to improve animation
              expandedCrossAxisAlignment: CrossAxisAlignment.center,
              expandedAlignment: Alignment.center,
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              iconColor: colorScheme.primary,
              collapsedIconColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                _getCategoryIcon(categoryName),
                color: _expandedCategoryName == categoryName
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withOpacity(0.8),
                size: 26,
              ),
              title: Text(
                categoryName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _expandedCategoryName == categoryName
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${filteredData.isEmpty ? "Sin datos" : "${filteredData.length} registros"} para esta categoría',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Selector de Sexo (Masculino/Femenino)
                      Center(
                        child: ToggleButtons(
                          isSelected: [
                            selectedGender == 'Male',
                            selectedGender == 'Female',
                          ],
                          onPressed: (int genderIndex) {
                            setState(() {
                              _selectedGenderForCategory[categoryName] =
                                  genderIndex == 0 ? 'Male' : 'Female';
                            });
                          },
                          borderRadius: BorderRadius.circular(
                              30.0), // More rounded for MD3
                          selectedColor: selectedGender == 'Male'
                              ? colorScheme.onPrimary
                              : Colors.white,
                          color: selectedGender == 'Male'
                              ? colorScheme.primary
                              : Colors.pink.shade400,
                          fillColor: selectedGender == 'Male'
                              ? colorScheme.primary
                              : Colors.pink.shade400,
                          constraints: const BoxConstraints(
                              minHeight: 40.0, minWidth: 120.0),
                          children: const <Widget>[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Masculino'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Femenino'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mostrar datos de edad para el sexo seleccionado
                      if (filteredData.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'No hay datos para el sexo seleccionado en esta categoría.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 16.0, // Espacio horizontal entre tarjetas
                          runSpacing:
                              16.0, // Espacio vertical entre filas de tarjetas
                          alignment: WrapAlignment
                              .center, // Centrar las tarjetas si no llenan el ancho
                          children: filteredData.map((ageData) {
                            String ageRange = ageData['age_range'] ?? 'N/A';
                            int count = ageData['count'] ?? 0;
                            return _buildAgeRangeCardWithGender(
                              ageRange,
                              count,
                              isFemale: selectedGender == 'Female',
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Helper Widget para la tarjeta de rango de edad
  Widget _buildAgeRangeCardWithGender(String ageRange, int count,
      {bool isFemale = false}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Adjust color based on gender
    final Color primaryColor =
        isFemale ? Colors.pink.shade400 : Colors.blue.shade700;

    // Dynamic color for the card's chip
    final Color chipColor = isFemale
        ? Colors.pink.shade50
        : colorScheme.primaryContainer.withOpacity(0.8);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFemale
              ? Colors.pink.shade100
              : colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      color: colorScheme.surface, // Removed conditional pink background
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Para que la columna se ajuste al contenido
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Edad',
              style: textTheme.labelMedium?.copyWith(
                color: isFemale
                    ? Colors.pink.shade700
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ageRange,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isFemale
                      ? Colors.pink.shade800
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(
                color: isFemale
                    ? Colors.pink.shade200
                    : colorScheme.outline.withOpacity(0.5)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 18, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  '$count ${count == 1 ? 'persona' : 'personas'}',
                  style: textTheme.titleMedium?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Visualizador combinado para categorías más y menos visitadas
  Widget _buildCombinedVisitedCategoriesView(dynamic data) {
    print('Building combined visited categories view with data: $data');

    // Data structure might already be the inner map after modification in _loadStatistics
    if (data == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Extract data from the combined response
    String mostVisitedCategory = '';
    int mostVisitedCount = 0;
    String leastVisitedCategory = '';
    int leastVisitedCount = 0;

    try {
      if (data is Map) {
        // Check if data comes from 'historical-categories' endpoint
        if (data.containsKey('most_visited') &&
            data['most_visited'] is Map &&
            data.containsKey('least_visited') &&
            data['least_visited'] is Map) {
          final mostVisitedData = data['most_visited'] as Map;
          final leastVisitedData = data['least_visited'] as Map;

          mostVisitedCategory =
              mostVisitedData['category']?.toString() ?? 'No disponible';
          mostVisitedCount = (mostVisitedData['count'] is int)
              ? mostVisitedData['count']
              : int.tryParse(mostVisitedData['count']?.toString() ?? '0') ?? 0;

          leastVisitedCategory =
              leastVisitedData['category']?.toString() ?? 'No disponible';
          leastVisitedCount = (leastVisitedData['count'] is int)
              ? leastVisitedData['count']
              : int.tryParse(leastVisitedData['count']?.toString() ?? '0') ?? 0;
        } else {
          // Original structure from weekly/monthly combined calls
          mostVisitedCategory =
              data['most_visited_category']?.toString() ?? 'No disponible';
          mostVisitedCount = (data['most_visited_count'] is int)
              ? data['most_visited_count']
              : int.tryParse(data['most_visited_count']?.toString() ?? '0') ??
                  0;

          leastVisitedCategory =
              data['least_visited_category']?.toString() ?? 'No disponible';
          leastVisitedCount = (data['least_visited_count'] is int)
              ? data['least_visited_count']
              : int.tryParse(data['least_visited_count']?.toString() ?? '0') ??
                  0;
        }
      }
    } catch (e) {
      print('Error parsing combined visited categories data: $e');
      return Center(child: Text('Error al procesar datos: $e'));
    }

    // REMOVED SingleChildScrollView wrapper here
    return Padding(
      // Changed SingleChildScrollView to Padding
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminamos el título y subtítulo
          const SizedBox(height: 24),

          // Responsive layout for the cards
          LayoutBuilder(
            builder: (context, constraints) {
              // Use row for wider screens, column for narrower screens
              bool useRow = constraints.maxWidth > 600;

              if (useRow) {
                // Side by side layout for wider screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        category: mostVisitedCategory,
                        count: mostVisitedCount,
                        isPopular: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCategoryCard(
                        category: leastVisitedCategory,
                        count: leastVisitedCount,
                        isPopular: false,
                      ),
                    ),
                  ],
                );
              } else {
                // Stacked layout for narrower screens
                return Column(
                  children: [
                    _buildCategoryCard(
                      category: mostVisitedCategory,
                      count: mostVisitedCount,
                      isPopular: true,
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryCard(
                      category: leastVisitedCategory,
                      count: leastVisitedCount,
                      isPopular: false,
                    ),
                  ],
                );
              }
            },
          ),

          // Eliminamos el texto explicativo, solo mantenemos el texto de datos históricos
          const SizedBox(height: 24),

          // Show that this is historical data
          Text(
            'Datos históricos acumulados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.secondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget for a single category card (reused for both most and least visited)
  Widget _buildCategoryCard({
    required String category,
    required int count,
    required bool isPopular,
  }) {
    // Define visual properties based on popularity
    final String title =
        isPopular ? 'Categoría Más Visitada' : 'Categoría Menos Visitada';
    final Color textColor =
        isPopular ? Colors.green.shade800 : Colors.brown.shade800;
    final Color bgColor = isPopular
        ? const Color(0xFFE8F5E9) // Light green
        : const Color(0xFFFFF3E0); // Light orange/peach

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 48),

            // Category content (center aligned)
            Center(
              child: Column(
                children: [
                  // Category icon in circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(category),
                        size: 40,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category name
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Visit count with person icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count visitas',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visualizador combinado para distribución por sexo y edad
  Widget _buildCombinedGenderAgeDistributionView(dynamic data) {
    print('Building gender/age view with data: $data');

    // Comprobar primero si tenemos datos básicos para mostrar
    if (data == null) {
      return _buildNoDataView(
          'No hay datos disponibles para los parámetros seleccionados.');
    }

    // La estructura puede venir en diferentes formatos. Intentar adaptarnos a ambos.
    Map<String, dynamic> genderData = {'male': 0, 'female': 0};
    Map<String, dynamic> ageData = {};

    // Extraer datos de gender y age
    if (data.containsKey('data')) {
      final dataContent = data['data'];
      print('Data content: $dataContent');

      if (dataContent is Map) {
        // Formato 1: data contiene gender y age
        if (dataContent.containsKey('gender')) {
          var genderContent = dataContent['gender'];
          print('Gender content: $genderContent');

          if (genderContent is Map) {
            // Verificar claves en minúsculas
            if (genderContent.containsKey('male')) {
              genderData['male'] = genderContent['male'] ?? 0;
            }
            if (genderContent.containsKey('female')) {
              genderData['female'] = genderContent['female'] ?? 0;
            }

            // Verificar claves en mayúsculas (en caso de que vengan así de la API)
            if (genderContent.containsKey('Male')) {
              genderData['male'] = genderContent['Male'] ?? 0;
            }
            if (genderContent.containsKey('Female')) {
              genderData['female'] = genderContent['Female'] ?? 0;
            }
          }
        }

        if (dataContent.containsKey('age')) {
          var ageContent = dataContent['age'];
          print('Age content: $ageContent');

          // Si age.ages existe, usar eso como la estructura de datos de edad
          if (ageContent is Map) {
            if (ageContent.containsKey('ages')) {
              ageData = Map<String, dynamic>.from(ageContent['ages']);
            } else {
              // Si no hay 'ages', usar el contenido directamente
              ageData = Map<String, dynamic>.from(ageContent);
            }
          }

          // Ver qué hay dentro de ageData
          print('Processed age data: $ageData');

          // Comprobar si necesitamos revisar más estructuras anidadas
          if (ageData.isEmpty && ageContent is Map) {
            // Buscar datos en estructuras secundarias como 'monthly' o 'overall'
            if (ageContent.containsKey('monthly')) {
              var monthlyData = ageContent['monthly'];
              if (monthlyData is Map &&
                  _selectedMonth != null &&
                  _selectedYear != null) {
                final monthKey =
                    "${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}";
                if (monthlyData.containsKey(monthKey)) {
                  ageData = monthlyData[monthKey];
                  print('Found age data in monthly[$monthKey]: $ageData');
                }
              }
            } else if (ageContent.containsKey('overall')) {
              ageData = ageContent['overall'];
              print('Found age data in overall: $ageData');
            }
          }

          // Verificar datos directamente en las estructuras de rango de edad
          // Compatibilidad con monthly y weekly en el documento JSON proporcionado
          if (ageData.isEmpty || ageData.values.every((v) => v == 0)) {
            // Convertir claves como "19-30" a datos procesables
            final ageRanges = {
              "19-30": 0,
              "0-18": 0,
              "31-45": 0,
              "46-60": 0,
              "60+": 0
            };

            // Buscar estos rangos en los datos
            if (ageContent is Map) {
              for (var key in ageRanges.keys) {
                // Buscar en monthly
                if (ageContent.containsKey('monthly')) {
                  var monthly = ageContent['monthly'];
                  if (monthly is Map &&
                      _selectedMonth != null &&
                      _selectedYear != null) {
                    final monthKey =
                        "${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}";
                    if (monthly.containsKey(monthKey) &&
                        monthly[monthKey] is Map &&
                        monthly[monthKey].containsKey(key)) {
                      ageRanges[key] = monthly[monthKey][key];
                    }
                  }
                }

                // Buscar en overall
                if (ageContent.containsKey('overall') &&
                    ageContent['overall'] is Map &&
                    ageContent['overall'].containsKey(key)) {
                  ageRanges[key] = ageContent['overall'][key];
                }
              }

              // Si encontramos algún dato, usar esos rangos
              if (ageRanges.values.any((v) => v != 0)) {
                ageData = Map<String, dynamic>.from(ageRanges);
                print('Using age ranges from document: $ageData');
              }
            }
          }
        }
      }
    } else if (data.containsKey('gender') && data.containsKey('age')) {
      // Formato 2: data es gender y age directamente
      if (data['gender'] is Map) {
        var genderContent = data['gender'];

        // Verificar claves en minúsculas
        if (genderContent.containsKey('male')) {
          genderData['male'] = genderContent['male'] ?? 0;
        }
        if (genderContent.containsKey('female')) {
          genderData['female'] = genderContent['female'] ?? 0;
        }

        // Verificar claves en mayúsculas
        if (genderContent.containsKey('Male')) {
          genderData['male'] = genderContent['Male'] ?? 0;
        }
        if (genderContent.containsKey('Female')) {
          genderData['female'] = genderContent['Female'] ?? 0;
        }
      }

      if (data['age'] is Map) {
        var ageContent = data['age'];
        if (ageContent.containsKey('ages')) {
          ageData = Map<String, dynamic>.from(ageContent['ages']);
        } else {
          ageData = Map<String, dynamic>.from(ageContent);
        }
      }
    }

    print('Final processed gender data: $genderData');
    print('Final processed age data: $ageData');

    // Verificamos si tenemos datos de sexo o edad (aunque sea uno solo)
    bool hasGenderData = genderData.isNotEmpty &&
        (genderData['male'] > 0 || genderData['female'] > 0);
    bool hasAgeData =
        ageData.isNotEmpty && ageData.values.any((v) => v != null && v > 0);

    // Si no hay datos específicos, mostrar un mensaje
    if (!hasGenderData && !hasAgeData) {
      return _buildNoDataView(
          'No hay datos demográficos para el período seleccionado.');
    }

    // Obtener el título del período
    String periodTitle = '';
    if (_selectedCategoryPeriodType == 'week' && _selectedWeekKey != null) {
      DateTime weekDate = DateTime.parse(_selectedWeekKey!);
      periodTitle =
          'Semana del ${DateFormat('dd/MM/yyyy', 'es_ES').format(weekDate)}';
    } else if (_selectedCategoryPeriodType == 'month' &&
        _selectedMonthKey != null) {
      final parts = _selectedMonthKey!.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.tryParse(parts[1]) ?? 1;
        periodTitle = '${_formatMonthName(month).capitalize()} $year';
      }
    } else if (_selectedCategoryPeriodType == 'historic') {
      periodTitle = 'Datos históricos acumulados';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Eliminado el título principal
            // Solo mostramos el período seleccionado
            Center(
              child: Text(
                periodTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ),

            const SizedBox(height: 24),

            // -- SECCIÓN DE GÉNERO --
            if (hasGenderData) ...[
              // Usar un estilo similar al de "Categorías preferidas por sexo"
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use row for wider screens, column for narrower screens
                  bool useRow = constraints.maxWidth > 700;

                  if (useRow) {
                    // Side by side layout for wider screens
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGenderDemographicCard(
                            gender: 'Male',
                            count: genderData['male'],
                            total: genderData['male'] + genderData['female'],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGenderDemographicCard(
                            gender: 'Female',
                            count: genderData['female'],
                            total: genderData['male'] + genderData['female'],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Stacked layout for narrower screens
                    return Column(
                      children: [
                        _buildGenderDemographicCard(
                          gender: 'Male',
                          count: genderData['male'],
                          total: genderData['male'] + genderData['female'],
                        ),
                        const SizedBox(height: 16),
                        _buildGenderDemographicCard(
                          gender: 'Female',
                          count: genderData['female'],
                          total: genderData['male'] + genderData['female'],
                        ),
                      ],
                    );
                  }
                },
              ),
            ],

            const SizedBox(height: 24),

            // -- SECCIÓN DE EDAD --
            if (hasAgeData) ...[
              // Eliminado el título de rangos de edad
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5, // Hacerlo más corto en altura
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAgeRangeCard('0-18', _getAgeCount(ageData, '0-18')),
                  _buildAgeRangeCard('19-30', _getAgeCount(ageData, '19-30')),
                  _buildAgeRangeCard('31-45', _getAgeCount(ageData, '31-45')),
                  _buildAgeRangeCard('46-60', _getAgeCount(ageData, '46-60')),
                  _buildAgeRangeCard('60+', _getAgeCount(ageData, '60+')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add this new method to build the gender demographic card
  Widget _buildGenderDemographicCard(
      {required String gender, required int count, required int total}) {
    final bool isMale = gender.toLowerCase() == 'male';
    final String title = isMale ? 'Hombres' : 'Mujeres';
    final Color cardColor = isMale
        ? Theme.of(context).brightness == Brightness.dark
            ? Colors.blue.shade900
            : Colors.blue.shade50
        : Theme.of(context).brightness == Brightness.dark
            ? Colors.pink.shade900
            : Colors.pink.shade50;
    final Color accentColor = isMale ? Colors.blue : Colors.pink;
    final IconData genderIcon = isMale ? Icons.man : Icons.woman;

    // Calculate percentage
    double percentage = total > 0 ? (count / total * 100) : 0;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Gender title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  genderIcon,
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Gender count and percentage
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'personas',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.percent,
                        size: 20,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Replace the _buildAgeRangeCard method with this improved version
  Widget _buildAgeRangeCard(String ageRange, int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Age range label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                ageRange,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Count
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            // Label
            Text(
              'personas',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Replace the _buildNewWeekSelector method with this improved version
  Widget _buildNewWeekSelector() {
    if (_availableWeeks.isEmpty) {
      // Mostrar un Dropdown deshabilitado sin mensaje
      return DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Seleccionar semana',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.calendar_view_week),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: const [],
        onChanged: null,
        disabledHint: const Text('Sin semanas disponibles'),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedWeekKey,
      decoration: InputDecoration(
        labelText: 'Seleccionar semana',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: const Icon(Icons.calendar_view_week),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      items: _availableWeeks.map((weekKey) {
        return DropdownMenuItem(
          value: weekKey,
          child: Text(_formatWeekLabel(weekKey)),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null && newValue != _selectedWeekKey) {
          setState(() {
            _selectedWeekKey = newValue;
            _statisticsData = null; // Clear data to force reload
          });
          _loadStatistics(); // Load new data immediately
        }
      },
    );
  }

  // Replace the _buildNewMonthSelector method with this improved version
  Widget _buildNewMonthSelector() {
    if (_availableMonths.isEmpty) {
      // Mostrar un Dropdown deshabilitado sin mensaje
      return DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Seleccionar mes',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.calendar_month),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: const [],
        onChanged: null,
        disabledHint: const Text('Sin meses disponibles'),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedMonthKey,
      decoration: InputDecoration(
        labelText: 'Seleccionar mes',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: const Icon(Icons.calendar_month),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      items: _availableMonths.map((monthKey) {
        // monthKey es tipo '2025-04'
        final parts = monthKey.split('-');
        String label = monthKey;
        if (parts.length == 2) {
          final year = parts[0];
          final month = int.tryParse(parts[1]) ?? 1;
          label = '${_formatMonthName(month).capitalize()} $year';
        }
        return DropdownMenuItem(
          value: monthKey,
          child: Text(label),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null && newValue != _selectedMonthKey) {
          setState(() {
            _selectedMonthKey = newValue;
            _statisticsData = null; // Clear data to force reload
          });
          _loadStatistics(); // Load new data immediately
        }
      },
    );
  }

  // Método para mostrar mensaje cuando no hay datos
  Widget _buildNoDataView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Prueba con otras fechas o período',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // Forzar recarga de datos
              _controller.clearCache(_selectedStat);
              _loadStatistics();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar datos'),
          ),
        ],
      ),
    );
  }

  // Construir tarjeta para sexo
  Widget _buildGenderCard(
      String gender, int count, IconData icon, Color color) {
    // Determine percentage based on gender
    final int maleCount = gender == 'Masculino' ? count : 0;
    final int femaleCount = gender == 'Femenino' ? count : 0;
    final int totalCount = gender == 'Masculino'
        ? count +
            (int.tryParse(
                    _statisticsData?['data']?['female']?.toString() ?? '0') ??
                0)
        : count +
            (int.tryParse(
                    _statisticsData?['data']?['male']?.toString() ?? '0') ??
                0);

    final double percentage = totalCount > 0 ? (count / totalCount * 100) : 0;
    final String percentageStr = percentage.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: gender == 'Masculino'
            ? const Color(0xFFE3EEFF)
            : const Color(0xFFFEE6EC),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gender,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: gender == 'Masculino'
                      ? Colors.blue.shade700
                      : Colors.pink.shade400,
                ),
              ),
              Text(
                '$percentageStr%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: gender == 'Masculino'
                      ? Colors.blue.shade700
                      : Colors.pink.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Visualizador para distribución por sexo
  Widget _buildGenderDistributionView(dynamic data) {
    if (data == null) {
      return _buildNoDataView('No hay datos de sexo disponibles');
    }

    // Extraer datos de sexo
    final int maleCount = data['male'] is int
        ? data['male']
        : int.tryParse(data['male'].toString()) ?? 0;

    final int femaleCount = data['female'] is int
        ? data['female']
        : int.tryParse(data['female'].toString()) ?? 0;

    final totalCount = maleCount + femaleCount;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eliminado el título
            const SizedBox(height: 16),

            // Mostrar datos en tarjetas
            Row(
              children: [
                // Masculino
                Expanded(
                  child: _buildGenderCard(
                    'Masculino',
                    maleCount,
                    Icons.man,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                // Femenino
                Expanded(
                  child: _buildGenderCard(
                    'Femenino',
                    femaleCount,
                    Icons.woman,
                    Colors.pink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Visualizador para distribución por edad
  Widget _buildAgeDistributionView(dynamic data) {
    if (data == null || (data is Map && data.isEmpty)) {
      return _buildNoDataView('No hay datos de edad disponibles');
    }

    // Extract age data from document structure
    final Map<String, int> processedAgeData = {};

    try {
      // First try to process direct data format
      if (data is Map) {
        // Try to extract from document structure like in the example
        // Check if data has keys like "0-18", "19-30", etc.
        final ageRanges = ["0-18", "19-30", "31-45", "46-60", "60+"];

        bool hasDirectRanges = false;
        for (var range in ageRanges) {
          if (data.containsKey(range)) {
            hasDirectRanges = true;
            int value = data[range] is int
                ? data[range]
                : int.tryParse(data[range].toString()) ?? 0;
            processedAgeData[range] = value;
          }
        }

        // If no direct ranges found, check in 'overall' if it exists
        if (!hasDirectRanges && data.containsKey('overall')) {
          final overall = data['overall'];
          if (overall is Map) {
            for (var range in ageRanges) {
              if (overall.containsKey(range)) {
                int value = overall[range] is int
                    ? overall[range]
                    : int.tryParse(overall[range].toString()) ?? 0;
                processedAgeData[range] = value;
              }
            }
          }
        }

        // If still no data, check in monthly/weekly
        if (processedAgeData.isEmpty) {
          if (data.containsKey('monthly') && data['monthly'] is Map) {
            final monthlyData = data['monthly'];
            if (_selectedMonth != null && _selectedYear != null) {
              final monthKey =
                  "${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}";
              if (monthlyData.containsKey(monthKey) &&
                  monthlyData[monthKey] is Map) {
                for (var range in ageRanges) {
                  if (monthlyData[monthKey].containsKey(range)) {
                    int value = monthlyData[monthKey][range] is int
                        ? monthlyData[monthKey][range]
                        : int.tryParse(
                                monthlyData[monthKey][range].toString()) ??
                            0;
                    processedAgeData[range] = value;
                  }
                }
              }
            }
          } else if (data.containsKey('weekly') && data['weekly'] is Map) {
            final weeklyData = data['weekly'];
            if (_selectedCategoryWeek != null) {
              final formatter = DateFormat('yyyy-MM-dd');
              final weekKey = formatter.format(_selectedCategoryWeek!);
              if (weeklyData.containsKey(weekKey) &&
                  weeklyData[weekKey] is Map) {
                for (var range in ageRanges) {
                  if (weeklyData[weekKey].containsKey(range)) {
                    int value = weeklyData[weekKey][range] is int
                        ? weeklyData[weekKey][range]
                        : int.tryParse(weeklyData[weekKey][range].toString()) ??
                            0;
                    processedAgeData[range] = value;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error processing age data: $e');
    }

    // If we still have no data, show a message
    if (processedAgeData.isEmpty) {
      return _buildNoDataView('No hay datos de edad en el formato esperado');
    }

    // Create a consistent order of age ranges
    final orderedRanges = ["0-18", "19-30", "31-45", "46-60", "60+"];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Distribución por edad',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Tarjetas de rango de edad - layout más compacto
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2, // More compact ratio
              ),
              itemCount: orderedRanges.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final range = orderedRanges[index];
                final count = processedAgeData[range] ?? 0;
                return _buildAgeRangeCardWithGender(range, count);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Visualizador combinado para categorías más y menos visitadas
  Widget _buildHistoricalVisitedCategoriesView(dynamic data) {
    print('Building historical visited categories view with data: $data');

    if (data == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Extract data from the combined response
    String mostVisitedCategory = '';
    int mostVisitedCount = 0;
    String leastVisitedCategory = '';
    int leastVisitedCount = 0;

    try {
      if (data is Map) {
        mostVisitedCategory =
            data['most_visited_category']?.toString() ?? 'No disponible';
        mostVisitedCount = (data['most_visited_count'] is int)
            ? data['most_visited_count']
            : int.tryParse(data['most_visited_count']?.toString() ?? '0') ?? 0;

        leastVisitedCategory =
            data['least_visited_category']?.toString() ?? 'No disponible';
        leastVisitedCount = (data['least_visited_count'] is int)
            ? data['least_visited_count']
            : int.tryParse(data['least_visited_count']?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      print('Error parsing historical visited categories data: $e');
      return Center(child: Text('Error al procesar datos: $e'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Eliminamos el título y subtítulo
          const SizedBox(height: 24),

          // Responsive layout for the cards
          LayoutBuilder(
            builder: (context, constraints) {
              // Use row for wider screens, column for narrower screens
              bool useRow = constraints.maxWidth > 700;

              if (useRow) {
                // Side by side layout for wider screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        category: mostVisitedCategory,
                        count: mostVisitedCount,
                        isPopular: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCategoryCard(
                        category: leastVisitedCategory,
                        count: leastVisitedCount,
                        isPopular: false,
                      ),
                    ),
                  ],
                );
              } else {
                // Stacked layout for narrower screens
                return Column(
                  children: [
                    _buildCategoryCard(
                      category: mostVisitedCategory,
                      count: mostVisitedCount,
                      isPopular: true,
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryCard(
                      category: leastVisitedCategory,
                      count: leastVisitedCount,
                      isPopular: false,
                    ),
                  ],
                );
              }
            },
          ),

          // Eliminamos el texto explicativo
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Helper method for category emojis
  String _getCategoryEmoji(String category) {
    final Map<String, String> categoryEmojis = {
      'Snacks': '🍿',
      'Alcohol': '🍷',
      'Bebidas': '🥤',
      'Frutas': '🍌',
      'Verduras': '🥦',
      'Lácteos': '🥛',
      'Carnes': '🥩',
      'Panadería': '🍞',
      'Dulces': '🍬',
      'Limpieza': '🧹',
      'Electrónicos': '📱',
      'Ropa': '👕',
    };

    return categoryEmojis[category] ??
        '🏆'; // Default trophy emoji if category not found
  }

  // Helper to get emotion icon
  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toUpperCase()) {
      case 'HAPPY':
        return Icons.sentiment_very_satisfied;
      case 'SAD':
        return Icons.sentiment_very_dissatisfied;
      case 'ANGRY':
        return Icons.mood_bad;
      case 'CALM':
        return Icons.sentiment_satisfied;
      case 'NEUTRAL':
        return Icons.sentiment_neutral;
      case 'FEAR':
        return Icons.face_retouching_natural;
      case 'DISGUST':
        return Icons.sick;
      case 'CONFUSED':
        return Icons.psychology;
      case 'SURPRISE':
      case 'SURPRISED':
        return Icons.sentiment_satisfied_alt;
      case 'ANXIOUS':
        return Icons.running_with_errors;
      case 'BORED':
        return Icons.bedtime;
      case 'EXCITED':
        return Icons.emoji_emotions;
      case 'STRESSED':
        return Icons.warning_amber;
      case 'TIRED':
        return Icons.hotel;
      case 'CONTENT':
        return Icons.sentiment_satisfied_alt;
      case 'DISAPPOINTED':
        return Icons.thumb_down_alt;
      case 'ANNOYED':
        return Icons.highlight_off;
      case 'HOPEFUL':
        return Icons.emoji_nature;
      case 'FRUSTRATED':
        return Icons.do_not_disturb;
      default:
        return Icons.emoji_emotions;
    }
  }

  // Helper method to arrange charts in a horizontal scrollable row
  List<Widget> _arrangeChartsInPairs(List<Widget> charts) {
    // Create a single scrollable row with all charts
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...charts.map((chart) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: chart,
                )),
          ],
        ),
      ),
    ];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Método para calcular el porcentaje
  double _calculatePercentage(dynamic value, Map<String, dynamic> genderData) {
    final int valueInt =
        value is int ? value : int.tryParse(value.toString()) ?? 0;
    final int maleCount = genderData['male'] is int
        ? genderData['male']
        : int.tryParse(genderData['male'].toString()) ?? 0;
    final int femaleCount = genderData['female'] is int
        ? genderData['female']
        : int.tryParse(genderData['female'].toString()) ?? 0;
    final int totalCount = maleCount + femaleCount;

    if (totalCount == 0) return 0.0;
    return double.parse((valueInt / totalCount * 100).toStringAsFixed(1));
  }

  // Método para obtener cuenta de edad según el rango
  int _getAgeCount(Map<String, dynamic> ageData, String range) {
    if (ageData.containsKey(range)) {
      var count = ageData[range];
      if (count is int) return count;
      return int.tryParse(count.toString()) ?? 0;
    }
    return 0;
  }

  // Obtener nombre del mes
  String _formatMonthName(int? month) {
    if (month == null) return '';

    switch (month) {
      case 1:
        return 'enero';
      case 2:
        return 'febrero';
      case 3:
        return 'marzo';
      case 4:
        return 'abril';
      case 5:
        return 'mayo';
      case 6:
        return 'junio';
      case 7:
        return 'julio';
      case 8:
        return 'agosto';
      case 9:
        return 'septiembre';
      case 10:
        return 'octubre';
      case 11:
        return 'noviembre';
      case 12:
        return 'diciembre';
      default:
        return '';
    }
  }

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
      'restaurant_menu': Icons.restaurant_menu,
      'eco': Icons.eco,
      'face': Icons.face,
    };

    return iconMap[name] ?? Icons.category;
  }

  // Cargar datos de categorías para iconos personalizados
  Future<void> _loadCategoryIcons() async {
    try {
      // Obtener el token desde AuthController
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('No se encontró el token de autenticación');
      }

      // Cargar categorías
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

      if (mounted) {
        setState(() {
          _categories = categories;
          _categoryIconMap = iconMap;
        });
      }
    } catch (e) {
      print('Error cargando iconos de categorías: $e');
      // No mostramos error ya que esto es secundario a la funcionalidad principal
    }
  }

  // Cargar estadísticas según la opción seleccionada
  Future<void> _loadStatistics() async {
    if (_isLoading) return;

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

      Map<String, String>? params;
      dynamic data;

      if (_selectedStat == 'visited-categories-combined') {
        data = await _controller.getHistoricalVisitedCategoriesStatistics(
            token: token);
      } else if (_selectedStat == 'busy-days-combined') {
        data = await _controller.getBusyDaysStatistics(token: token);
      } else if (_selectedStat == 'gender-age-combined') {
        if (_selectedCategoryPeriodType == 'month') {
          if (_availableMonths.isNotEmpty) {
            _selectedMonthKey = _availableMonths.first;
          } else {
            _selectedMonthKey = null;
          }
        } else if (_selectedCategoryPeriodType == 'week') {
          if (_availableWeeks.isNotEmpty) {
            _selectedWeekKey = _availableWeeks.first;
          } else {
            _selectedWeekKey = null;
          }
        }
        params = {'period': _selectedCategoryPeriodType};
        if (_selectedCategoryPeriodType == 'week' && _selectedWeekKey != null) {
          params['date'] = _selectedWeekKey!;
        } else if (_selectedCategoryPeriodType == 'month' &&
            _selectedMonthKey != null) {
          final parts = _selectedMonthKey!.split('-');
          params['year'] = parts[0];
          params['month'] = parts[1];
        }
        data = await _controller.getGenderAgeDistributionStatistics(
            params: params, token: token);
      } else if (_selectedStat == 'top-successful-categories') {
        data = await _controller.getTopSuccessfulCategories(token: token);
      } else {
        if (_requiresParams(_selectedStat)) {
          params = {'period': _selectedPeriod};
          if (_selectedPeriod == 'week') {
            params['date'] = DateFormat('yyyy-MM-dd').format(_selectedDate);
            if (_selectedStat == 'emotion-comparison' &&
                _selectedEndDate != null) {
              params['end_date'] =
                  DateFormat('yyyy-MM-dd').format(_selectedEndDate!);
            }
          } else if (_selectedPeriod == 'month') {
            params['month'] = _selectedMonth.toString();
            params['year'] = _selectedYear.toString();
          }
        }
        data = await _controller.getStatistics(_selectedStat,
            params: params, token: token);
      }

      if (mounted) {
        setState(() {
          _statisticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadStatistics: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
}
