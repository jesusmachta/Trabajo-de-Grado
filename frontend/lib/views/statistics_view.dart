import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../controllers/statistics_controller.dart';
import '../models/chart_data.dart';
import 'widgets/statistic_card.dart';
import 'widgets/statistics_selector.dart';

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
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  final StatisticsController _controller = StatisticsController();
  bool _isLoading = false;
  String _selectedStat = 'peak-hours';
  String _selectedPeriod = 'week';
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedEndDate;
  int? _selectedMonth;
  int? _selectedYear;
  // Change to dynamic to accept both Map and List
  dynamic _statisticsData;
  String? _error;

  // Opciones para el período
  final List<Map<String, String>> _periodOptions = [
    {'value': 'week', 'label': 'Semana'},
    {'value': 'month', 'label': 'Mes'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  // Cargar las estadísticas desde el API
  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Preparar parámetros según el tipo de estadística
      Map<String, String>? params;

      if (_requiresParams(_selectedStat)) {
        if (_selectedStat == 'emotion-comparison') {
          // Para comparación de emociones, crear parámetros específicos
          params = {'period': _selectedPeriod};

          // Add debug output to verify parameters
          print('Loading emotion-comparison with period: $_selectedPeriod');

          if (_selectedPeriod == 'week') {
            // Format dates as YYYY-MM-DD for the API
            final formatter = DateFormat('yyyy-MM-dd');
            final startDate = _selectedDate;
            // Add start date
            params['date'] = formatter.format(startDate);
            print('Using start date: ${params['date']}');

            // Add end date if available
            if (_selectedEndDate != null) {
              params['end_date'] = formatter.format(_selectedEndDate!);
              print('Using end date: ${params['end_date']}');
            }
          } else if (_selectedPeriod == 'month') {
            // Format month and year for the API
            if (_selectedMonth != null && _selectedYear != null) {
              params['month'] = _selectedMonth.toString();
              params['year'] = _selectedYear.toString();
              print('Using month: ${params['month']}, year: ${params['year']}');
            }
          }

          // Always clear cache for emotion-comparison
          _controller.clearCache('emotion-comparison');
          print('Cleared cache for emotion-comparison to ensure fresh data');
        } else if (_selectedStat.contains('visited') ||
            _selectedStat.contains('distribution')) {
          // Para otras estadísticas parametrizadas
          params = {'period': _selectedPeriod};

          // Determinar el formato de la fecha según el período
          if (_selectedPeriod == 'week' || _selectedPeriod == 'month') {
            final formatter = DateFormat('yyyy-MM-dd');
            DateTime startDate;

            if (_selectedPeriod == 'week') {
              startDate = _selectedDate;
            } else {
              // Para período mensual
              if (_selectedMonth != null && _selectedYear != null) {
                // Usar el primer día del mes seleccionado
                startDate = DateTime(_selectedYear!, _selectedMonth!, 1);
              } else {
                // Usar el primer día del mes actual si no hay selección
                final now = DateTime.now();
                startDate = DateTime(now.year, now.month, 1);
              }
            }

            final formattedDate = formatter.format(startDate);
            params = {
              'period': _selectedPeriod,
              'date': formattedDate,
            };
          }
        }
      }

      // Clear any previous error state
      if (mounted) {
        setState(() {
          _error = null;
        });
      }

      // Reset data if endpoint changed to prevent showing stale data
      if (mounted && _statisticsData != null) {
        setState(() {
          _statisticsData = null;
        });
      }

      // Special handling for combined statistics
      if (_selectedStat == 'busy-days-combined') {
        final data = await _controller.getBusyDaysStatistics();

        if (mounted) {
          setState(() {
            _statisticsData = data;
            _isLoading = false;
          });
        }
        return;
      }

      // Special handling for combined most/least visited categories
      if (_selectedStat == 'visited-categories-combined') {
        final data = await _controller.getVisitedCategoriesStatistics();

        if (mounted) {
          setState(() {
            _statisticsData = data;
            _isLoading = false;
          });
        }
        return;
      }

      // Special handling for combined historical visited categories
      if (_selectedStat == 'visited-categories-historical') {
        final data =
            await _controller.getHistoricalVisitedCategoriesStatistics();

        if (mounted) {
          setState(() {
            _statisticsData = data;
            _isLoading = false;
          });
        }
        return;
      }

      // Special handling for combined gender and age distribution
      if (_selectedStat == 'gender-age-combined') {
        final data = await _controller.getGenderAgeDistributionStatistics(
            params: params);

        if (mounted) {
          setState(() {
            _statisticsData = data;
            _isLoading = false;
          });
        }
        return;
      }

      // Special handling for top successful categories (podium visualization)
      if (_selectedStat == 'top-successful-categories') {
        try {
          print('Loading top successful categories');
          final topCategoriesData =
              await _controller.getTopSuccessfulCategories();

          print(
              'Received top categories data: $topCategoriesData (${topCategoriesData.runtimeType})');

          if (mounted) {
            setState(() {
              // Store the list directly, not as a map with 'data' key
              _statisticsData = topCategoriesData;
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error loading top successful categories: $e');
          if (mounted) {
            setState(() {
              _error = e.toString();
              _isLoading = false;
            });
          }
        }
        return;
      }

      // For regular statistics, including emotion-comparison
      final data =
          await _controller.getStatistics(_selectedStat, params: params);

      // Print received data for debugging
      if (_selectedStat == 'emotion-comparison') {
        print('Received data for emotion-comparison: $data');
      }

      if (mounted) {
        setState(() {
          _statisticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar estadísticas: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Verifica si el endpoint seleccionado requiere parámetros
  bool _requiresParams(String endpoint) {
    return [
      'age-distribution',
      'gender-distribution',
      'gender-age-combined',
      'most-visited',
      'least-visited',
      'emotion-comparison',
      // Nuevas estadísticas que pueden requerir parámetros
      'emotional-differences-by-category'
      // 'age-gender-distribution-by-category' - removed as it doesn't require parameters
    ].contains(endpoint);
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
      builder: (BuildContext context) {
        int selectedYear = currentYear;
        int selectedMonth = currentMonth;

        return AlertDialog(
          title: const Text('Seleccionar mes'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de año
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left),
                        onPressed: () {
                          if (selectedYear > 2020) {
                            setState(() {
                              selectedYear--;
                            });
                          }
                        },
                      ),
                      Text(
                        '$selectedYear',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right),
                        onPressed: () {
                          if (selectedYear < now.year) {
                            setState(() {
                              selectedYear++;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grid de meses
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(12, (index) {
                      final int month = index + 1;
                      // Deshabilitar meses futuros en el año actual
                      final bool isDisabled =
                          selectedYear == now.year && month > now.month;
                      final bool isSelected = month == selectedMonth &&
                          selectedYear == selectedYear;

                      return InkWell(
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  selectedMonth = month;
                                });
                              },
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isDisabled
                                    ? Theme.of(context)
                                        .disabledColor
                                        .withOpacity(0.1)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _getMonthName(month),
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : isDisabled
                                      ? Theme.of(context).disabledColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedYear = selectedYear;
                  _selectedMonth = selectedMonth;

                  // Clear cache for emotion-comparison to ensure fresh data
                  if (_selectedStat == 'emotion-comparison') {
                    _controller.clearCache(_selectedStat);
                    _statisticsData = null;
                  }
                });
                _loadStatistics();
              },
              child: const Text('Seleccionar'),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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

            // Mostrar selectores adicionales si es necesario
            if (_requiresParams(_selectedStat)) ...[
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
                                    Icons.calendar_today,
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

            // Refresh button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
            Expanded(
              child: _isLoading
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
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
                      : _statisticsData == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                          : _buildStatisticsContent(),
            ),
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

    if (_statisticsData == null) {
      return const Center(
        child: Text('No hay datos disponibles'),
      );
    }

    // Special handling for top-successful-categories which is already a List
    if (_selectedStat == 'top-successful-categories') {
      // Obtener el título de la estadística seleccionada
      final selectedStatOption = _controller.getStatisticsOptions().firstWhere(
            (option) => option['value'] == _selectedStat,
            orElse: () => {'value': _selectedStat, 'label': 'Estadística'},
          );

      return StatisticCard(
        title: selectedStatOption['label']!,
        icon: _getIconForStatistic(_selectedStat),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultados:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildTopCategoriesView(_statisticsData),
            ),
          ],
        ),
      );
    }

    // For all other statistics that use the Map structure with 'data' field
    final data = _statisticsData!['data'];
    if (data == null) {
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
            Expanded(child: content),
          ],
        ),
      );
    }

    // Para todas las demás estadísticas, usar el formato normal
    return StatisticCard(
      title: selectedStatOption['label']!,
      icon: _getIconForStatistic(_selectedStat),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mostrar información sobre el período seleccionado si aplica
          if (_requiresParams(_selectedStat) &&
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

          Text(
            'Resultados:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
      case 'age-distribution':
        return _buildDistributionView(data);
      case 'most-visited':
      case 'least-visited':
        // Use individual view for now, but we'll create a combined view
        return _buildVisitedCategoryView(data, _selectedStat);
      case 'visited-categories-combined':
        // New combined view for most and least visited categories
        return _buildCombinedVisitedCategoriesView(data);
      case 'visited-categories-historical':
        // Combined view for historical most and least visited categories
        return _buildHistoricalVisitedCategoriesView(data);
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
      case 'preferred-category-by-gender':
        return _buildPreferredCategoryView(data);
      case 'emotional-differences-by-category':
        return _buildEmotionalDifferencesByCategoryView(data);
      case 'age-gender-distribution-by-category':
        return _buildAgeGenderDistributionByCategoryView(data);
      default:
        // Mostrar datos como texto para el resto de estadísticas
        return Center(
          child: SelectableText(
            data.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );
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
    switch (category.toLowerCase()) {
      case 'alcohol':
        return Icons.liquor;
      case 'snacks':
        return Icons.cookie;
      case 'frutas':
        return Icons.apple;
      case 'vegetales':
        return Icons.emoji_food_beverage;
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

  // Visualizador para distribuciones (edad/género)
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

  // Visualizador para categorías preferidas por género
  Widget _buildPreferredCategoryView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Categorías Preferidas por Género',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Análisis histórico de las categorías más visitadas por hombres y mujeres',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
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
                        gender: 'male',
                        data: data['male'],
                        isLeft: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGenderPreferenceCard(
                        gender: 'female',
                        data: data['female'],
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
                      gender: 'male',
                      data: data['male'],
                      isLeft: true,
                    ),
                    const SizedBox(height: 24),
                    _buildGenderPreferenceCard(
                      gender: 'female',
                      data: data['female'],
                      isLeft: false,
                    ),
                  ],
                );
              }
            },
          ),

          // Explanation text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'Estas estadísticas muestran las preferencias de compra por género basadas en todos los datos históricos recopilados.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
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

  // Visualizador para categorías mejor evaluadas
  Widget _buildTopCategoriesView(dynamic data) {
    print('Top categories view - data type: ${data.runtimeType}');
    print('Top categories data content: $data');

    // Initialize an empty list to store our processed categories
    List<Map<String, dynamic>> processedCategories = [];

    try {
      // If data is already a List<Map<String, dynamic>> or List
      if (data is List) {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            processedCategories.add(item);
          } else if (item is Map) {
            // Convert to the right type with consistent keys
            processedCategories.add({
              'category': item['category']?.toString() ?? 'Sin nombre',
              'happy_count': item['happy_count'] is int
                  ? item['happy_count']
                  : int.tryParse(item['happy_count'].toString()) ?? 0,
              'emoji': item['emoji']?.toString() ??
                  _getCategoryEmoji(item['category']?.toString() ?? '')
            });
          }
        }
      }

      print('Processed categories: $processedCategories');
    } catch (e) {
      print('Error processing top categories data: $e');
      return Center(child: Text('Error al procesar datos: $e'));
    }

    if (processedCategories.isEmpty) {
      return const Center(
          child: Text('No hay categorías con emociones positivas'));
    }

    final int categoriesCount = processedCategories.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Categorías Mejor Evaluadas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Podium visualization
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            height: MediaQuery.of(context).size.height * 0.4,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Base line
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),

                // Podium positions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd place (left)
                    if (categoriesCount >= 2)
                      _buildPodiumPosition(
                        processedCategories[1],
                        2,
                        Colors.grey.shade400,
                        '🥈',
                        height: MediaQuery.of(context).size.height * 0.25,
                      ),

                    const SizedBox(width: 10),

                    // 1st place (center)
                    if (categoriesCount >= 1)
                      _buildPodiumPosition(
                        processedCategories[0],
                        1,
                        Colors.amber,
                        '🏆',
                        height: MediaQuery.of(context).size.height * 0.35,
                      ),

                    const SizedBox(width: 10),

                    // 3rd place (right)
                    if (categoriesCount >= 3)
                      _buildPodiumPosition(
                        processedCategories[2],
                        3,
                        Colors.brown.shade300,
                        '🥉',
                        height: MediaQuery.of(context).size.height * 0.18,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Legend
          Text(
            'Basado en reacciones positivas de los clientes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.secondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to build a single podium position
  Widget _buildPodiumPosition(Map<String, dynamic> categoryData, int position,
      Color color, String trophy,
      {required double height}) {
    final String categoryName = categoryData['category'] ?? 'Sin nombre';
    final int happyCount = categoryData['happy_count'] ?? 0;
    final String emoji = categoryData['emoji'] ?? '🏆';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Trophy or medal
          Text(
            trophy,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),

          // Category emoji
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),

          // Category name
          Text(
            categoryName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Reactions count
          Text(
            '$happyCount 😄',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),

          // Podium block
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                position.toString(),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
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

    // Ordenar las horas para mostrarlas cronológicamente
    final sortedEntries = data.entries.toList();
    sortedEntries.sort((a, b) {
      final int timeA = int.tryParse(a.key.toString().split(':')[0]) ?? 0;
      final int timeB = int.tryParse(b.key.toString().split(':')[0]) ?? 0;
      return timeA.compareTo(timeB);
    });

    for (var entry in sortedEntries) {
      chartData.add(HourData(
        hour: entry.key.toString(),
        count: (entry.value as num).toDouble(),
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
            const SizedBox(height: 8),
            Text(
              'Cantidad de visitantes por hora del día',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              width: constraints.maxWidth,
              child: SfCartesianChart(
                margin: const EdgeInsets.all(0),
                primaryXAxis: CategoryAxis(
                  title: AxisTitle(text: 'Hora'),
                  labelIntersectAction: AxisLabelIntersectAction.rotate45,
                  labelRotation: constraints.maxWidth < 400 ? 45 : 0,
                  maximumLabels: constraints.maxWidth < 400 ? 6 : 12,
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
                  LineSeries<HourData, String>(
                    dataSource: chartData,
                    xValueMapper: (HourData data, _) => data.hour,
                    yValueMapper: (HourData data, _) => data.count,
                    name: 'Visitantes',
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
            // Leyenda de datos - now wrapped to stay within container width
            constraints.maxWidth > 500
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildLegendItems(sortedEntries),
                  )
                : SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _buildLegendItems(sortedEntries),
                    ),
                  ),
          ],
        );
      }),
    );
  }

  List<Widget> _buildLegendItems(List<MapEntry> entries) {
    return entries.map((entry) {
      return Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${entry.key}: ${entry.value} visitantes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }).toList();
  }

  // Visualizador para días más y menos concurridos
  Widget _buildCombinedDaysView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Obtener directamente los nombres de los días
    String mostBusyDayEn = data['most_busy_day'] as String? ?? 'No disponible';
    String leastBusyDayEn =
        data['least_busy_day'] as String? ?? 'No disponible';

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

    // Definir días de la semana en orden
    final List<String> weekDays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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

          // Visualización de calendario semanal
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Calendario Semanal',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  // Para pantallas muy pequeñas, mostrar en dos filas
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: weekDays.sublist(0, 4).map((day) {
                            final isMostBusy = day == mostBusyDayName;
                            final isLeastBusy = day == leastBusyDayName;

                            return _buildDayCircle(
                                day: day,
                                isMostBusy: isMostBusy,
                                isLeastBusy: isLeastBusy);
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: weekDays.sublist(4).map((day) {
                            final isMostBusy = day == mostBusyDayName;
                            final isLeastBusy = day == leastBusyDayName;

                            return _buildDayCircle(
                                day: day,
                                isMostBusy: isMostBusy,
                                isLeastBusy: isLeastBusy);
                          }).toList(),
                        ),
                      ],
                    );
                  } else {
                    // Para pantallas normales, mostrar en una fila
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: weekDays.map((day) {
                        final isMostBusy = day == mostBusyDayName;
                        final isLeastBusy = day == leastBusyDayName;

                        return _buildDayCircle(
                            day: day,
                            isMostBusy: isMostBusy,
                            isLeastBusy: isLeastBusy);
                      }).toList(),
                    );
                  }
                }),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Tarjetas de información
          Row(
            children: [
              // Tarjeta del día más concurrido
              Expanded(
                child: _buildDayInfoCard(
                  title: 'Día Más Concurrido',
                  day: mostBusyDayName,
                  count: null, // Sin valor numérico
                  icon: Icons.people,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              // Tarjeta del día menos concurrido
              Expanded(
                child: _buildDayInfoCard(
                  title: 'Día Menos Concurrido',
                  day: leastBusyDayName,
                  count: null, // Sin valor numérico
                  icon: Icons.person_outline,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para mostrar un círculo con la inicial del día
  Widget _buildDayCircle({
    required String day,
    required bool isMostBusy,
    required bool isLeastBusy,
  }) {
    Color bgColor = Theme.of(context).colorScheme.surfaceVariant;
    Color textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (isMostBusy) {
      bgColor = Colors.green;
      textColor = Colors.white;
    } else if (isLeastBusy) {
      bgColor = Colors.orange;
      textColor = Colors.white;
    }

    return Container(
      width: 85, // Ancho fijo para acomodar el nombre completo
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMostBusy || isLeastBusy
                    ? Colors.transparent
                    : Theme.of(context).dividerColor,
                width: 1,
              ),
              boxShadow: isMostBusy || isLeastBusy
                  ? [
                      BoxShadow(
                        color: isMostBusy
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              day[0], // Primera letra del día
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day, // Nombre completo del día
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isMostBusy
                      ? Colors.green
                      : isLeastBusy
                          ? Colors.orange
                          : null,
                  fontWeight: isMostBusy || isLeastBusy
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget para tarjeta informativa de día
  Widget _buildDayInfoCard({
    required String title,
    required String day,
    int? count, // Ahora es opcional
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    day,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  // Solo mostrar el conteo si está disponible
                  if (count != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$count visitantes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

            // Get colors for this chart
            final List<Color> emotionColors = [
              Colors.green, // Happy
              Colors.blue, // Sad
              Colors.lightBlue, // Calm
              Colors.amber, // Neutral
              Colors.orange, // Surprised
              Colors.red, // Angry
              Colors.purple, // Fear
              Colors.brown, // Disgust
              Colors.grey, // Others
            ];

            // Create a card with pie chart for this category
            categoryCharts.add(
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Category title
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Pie chart
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 250,
                        child: SfCircularChart(
                          title: ChartTitle(
                            text: 'Distribución de emociones',
                            textStyle: Theme.of(context).textTheme.titleMedium,
                          ),
                          legend: Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                            overflowMode: LegendItemOverflowMode.wrap,
                          ),
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            format: 'point.x: point.y%',
                            duration: 1000,
                          ),
                          series: <CircularSeries>[
                            PieSeries<EmotionPercentageData, String>(
                              dataSource: chartData,
                              xValueMapper: (EmotionPercentageData data, _) =>
                                  _translateEmotion(data.emotion),
                              yValueMapper: (EmotionPercentageData data, _) =>
                                  data.percentage,
                              dataLabelMapper: (EmotionPercentageData data,
                                      _) =>
                                  '${_translateEmotion(data.emotion)}: ${data.percentage.toStringAsFixed(1)}%',
                              pointColorMapper:
                                  (EmotionPercentageData data, index) =>
                                      _getEmotionColor(
                                          data.emotion, index, emotionColors),
                              dataLabelSettings: DataLabelSettings(
                                isVisible: chartData.length <=
                                    3, // Only show labels if few emotions
                                labelPosition: ChartDataLabelPosition.outside,
                                connectorLineSettings:
                                    const ConnectorLineSettings(
                                  type: ConnectorType.curve,
                                  length: '15%',
                                ),
                              ),
                              enableTooltip: true,
                              explode: true,
                              explodeIndex:
                                  0, // Explode the first segment (highest percentage)
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Legend as text below
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: chartData.map((data) {
                          final emotionColor = _getEmotionColor(data.emotion,
                              chartData.indexOf(data), emotionColors);

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: emotionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: emotionColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: emotionColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_translateEmotion(data.emotion)}: ${data.percentage.toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
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

    // Return a scrollable list of all category pie charts
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Porcentaje de Emociones por Categoría',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Distribución porcentual de emociones detectadas por categoría',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...categoryCharts,
      ],
    );
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
      default:
        return emotion;
    }
  }

  // Visualizador simplificado para emociones más frecuentes por categoría
  Widget _buildFrequentEmotionsView(dynamic data) {
    print('Building frequent emotions view with data: $data');

    if (data == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    List<Widget> categoryWidgets = [];

    try {
      data.forEach((category, value) {
        if (value is Map) {
          final emotion = value['emotion']?.toString() ?? 'Desconocido';
          final count = value['count'] ?? 0;

          // Get emotion color
          final Color emotionColor = _getEmotionColor(emotion, 0, [
            Colors.green,
            Colors.blue,
            Colors.red,
            Colors.lightBlue,
            Colors.amber,
            Colors.purple,
            Colors.brown,
            Colors.orange,
          ]);

          categoryWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: emotionColor.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category header with colored background
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: emotionColor.withOpacity(0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Emotion and count information
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: emotionColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getEmotionIcon(emotion),
                              size: 40,
                              color: emotionColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _translateEmotion(emotion),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: emotionColor,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: emotionColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '$count visitantes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
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
              ),
            ),
          );
        }
      });
    } catch (e) {
      print('Error rendering emotion cards: $e');
      return Center(child: Text('Error: $e'));
    }

    if (categoryWidgets.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: categoryWidgets,
    );
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
        return Icons.sentiment_very_dissatisfied;
      case 'DISGUST':
        return Icons.mood_bad;
      case 'CONFUSED':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Comparación entre felicidad y tristeza detectada',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
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

  // Construir celda de encabezado de tabla (No longer needed with DataTable)
  /* Widget _buildTableHeader(String text) { ... } */

  // Construir celda de tabla básica (No longer needed with DataTable)
  /* Widget _buildTableCell(String text, {bool isBold = false, Color? textColor}) { ... } */

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

  // Visualizador para diferencias emocionales por categoría con íconos de género
  Widget _buildEmotionalDifferencesByCategoryView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Mapeo de emociones a español y emojis
    final Map<String, Map<String, String>> emotionTranslations = {
      'HAPPY': {'es': 'Feliz', 'emoji': '😄'},
      'SAD': {'es': 'Triste', 'emoji': '😢'},
      'ANGRY': {'es': 'Enojado', 'emoji': '😡'},
      'CONFUSED': {'es': 'Confundido', 'emoji': '😕'},
      'DISGUSTED': {'es': 'Disgustado', 'emoji': '🤢'},
      'SURPRISED': {'es': 'Sorprendido', 'emoji': '😲'},
      'CALM': {'es': 'Calmado', 'emoji': '😌'},
      'FEAR': {'es': 'Temeroso', 'emoji': '😨'},
      'UNKNOWN': {'es': 'Desconocido', 'emoji': '❓'},
    };

    // Traducción de categorías a español si es necesario
    final Map<String, String> categoryTranslations = {
      'Alcohol': 'Alcohol',
      'Frutas': 'Frutas',
      'Vegetales': 'Vegetales',
      'Snacks': 'Snacks',
      'Dairy': 'Lácteos',
      'Meat': 'Carnes',
      'Bakery': 'Panadería',
    };

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Diferencias Emocionales por Categoría',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Emociones predominantes por género en cada categoría',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Mostrar tarjetas por categoría
            for (var categoryEntry in data.entries)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getCategoryIcon(categoryEntry.key),
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          categoryTranslations[categoryEntry.key] ??
                              categoryEntry.key,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Mostrar información por género
                    Row(
                      children: [
                        // Hombres
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.man,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hombres',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (categoryEntry.value is Map &&
                                  categoryEntry.value['male'] != null)
                                _buildEmotionCard(
                                  context,
                                  categoryEntry.value['male']
                                      ['predominant_emotion'],
                                  categoryEntry.value['male']['count'],
                                  emotionTranslations,
                                  Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                ),
                              if (categoryEntry.value is Map &&
                                  (categoryEntry.value['male'] == null ||
                                      categoryEntry.value['male']
                                              ['predominant_emotion'] ==
                                          null))
                                _buildNoDataCard(
                                    context,
                                    Theme.of(context)
                                        .colorScheme
                                        .primaryContainer),
                            ],
                          ),
                        ),

                        Container(
                          height: 100,
                          width: 1,
                          color: Theme.of(context).dividerColor,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),

                        // Mujeres
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.woman,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mujeres',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (categoryEntry.value is Map &&
                                  categoryEntry.value['female'] != null)
                                _buildEmotionCard(
                                  context,
                                  categoryEntry.value['female']
                                      ['predominant_emotion'],
                                  categoryEntry.value['female']['count'],
                                  emotionTranslations,
                                  Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                ),
                              if (categoryEntry.value is Map &&
                                  (categoryEntry.value['female'] == null ||
                                      categoryEntry.value['female']
                                              ['predominant_emotion'] ==
                                          null))
                                _buildNoDataCard(
                                    context,
                                    Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer),
                            ],
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

  // Widget para mostrar la emoción con emoji y contador
  Widget _buildEmotionCard(
    BuildContext context,
    String? emotion,
    int count,
    Map<String, Map<String, String>> emotionTranslations,
    Color backgroundColor,
  ) {
    final translatedEmotion = emotion != null
        ? emotionTranslations[emotion]
        : {'es': 'No disponible', 'emoji': '❓'};

    final emotionText = translatedEmotion?['es'] ?? 'No disponible';
    final emotionEmoji = translatedEmotion?['emoji'] ?? '❓';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            emotionEmoji,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            emotionText,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$count visitantes',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget para mostrar cuando no hay datos disponibles
  Widget _buildNoDataCard(BuildContext context, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            '❓',
            style: TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            'Sin datos',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '0 visitantes',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Visualizador para distribución por edad y género por categoría
  Widget _buildAgeGenderDistributionByCategoryView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Distribución por Edad y Género por Categoría',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Mostrar datos por categoría
            ...data.entries.map((categoryEntry) {
              final String categoryName = categoryEntry.key;
              final Map<String, dynamic> genderData = categoryEntry.value;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de categoría
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(categoryName),
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Categoría: $categoryName',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido por género
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección Masculina
                          if (genderData.containsKey('male') &&
                              genderData['male'] is List &&
                              genderData['male'].isNotEmpty)
                            _buildGenderSection(
                              'Masculino',
                              genderData['male'],
                              Icons.male,
                              Colors.blue.shade700,
                            ),

                          const SizedBox(height: 16),

                          // Sección Femenina
                          if (genderData.containsKey('female') &&
                              genderData['female'] is List &&
                              genderData['female'].isNotEmpty)
                            _buildGenderSection(
                              'Femenino',
                              genderData['female'],
                              Icons.female,
                              Colors.pink.shade700,
                            ),

                          // Mensaje si no hay datos para ningún género
                          if ((genderData['male'] == null ||
                                  genderData['male'].isEmpty) &&
                              (genderData['female'] == null ||
                                  genderData['female'].isEmpty))
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No hay datos disponibles para esta categoría',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Método auxiliar para construir la sección de cada género
  Widget _buildGenderSection(
      String genderTitle, List<dynamic> ageData, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de género
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              genderTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tarjetas de edad
        LayoutBuilder(
          builder: (context, constraints) {
            // Determinar cuántas tarjetas por fila basado en el ancho disponible
            int crossAxisCount = constraints.maxWidth > 600
                ? 3
                : constraints.maxWidth > 400
                    ? 2
                    : 1;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ageData.map<Widget>((ageItem) {
                final int age = ageItem['age'] ?? 0;
                final int count = ageItem['count'] ?? 0;

                return Container(
                  width: (constraints.maxWidth / crossAxisCount) - 8,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edad: $age años',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: color),
                          const SizedBox(width: 4),
                          Text(
                            'Cantidad: $count',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Visualizador combinado para categorías más y menos visitadas
  Widget _buildCombinedVisitedCategoriesView(dynamic data) {
    print('Building combined visited categories view with data: $data');

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
      print('Error parsing combined visited categories data: $e');
      return Center(child: Text('Error al procesar datos: $e'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Categorías Más y Menos Visitadas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Comparativa entre las categorías con mayor y menor número de visitas',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
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

          // Explanation text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'Estas estadísticas muestran las preferencias de los clientes al visitar las diferentes categorías de productos de la tienda.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
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
    final Color accentColor = isPopular ? Colors.green : Colors.orange;
    final Color cardColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).cardColor
        : isPopular
            ? Colors.green.shade50
            : Colors.orange.shade50;

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
          // Category title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

          // Category icon and name
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Category icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(category),
                      size: 48,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category name
                Text(
                  category,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Visit count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 18,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count visitas',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

  // Visualizador combinado para distribución por género y edad
  Widget _buildCombinedGenderAgeDistributionView(dynamic data) {
    if (data == null ||
        !data.containsKey('gender') ||
        !data.containsKey('age')) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final genderData = data['gender'] as Map<String, dynamic>;
    final ageData = data['age'] as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Distribución por género y edad',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Container dividido verticalmente en dos partes
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mitad izquierda: Distribución por género
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Distribución por género',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Tarjetas de género en layout horizontal
                      Row(
                        children: [
                          // Tarjeta Masculino
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.blue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Icono de género masculino
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.man,
                                        size: 40,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Etiqueta de género
                                    Text(
                                      'Masculino',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    // Contador
                                    Text(
                                      '${genderData['male'] ?? 0}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Tarjeta Femenino
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.pink.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Icono de género femenino
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.pink.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.woman,
                                        size: 40,
                                        color: Colors.pink,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Etiqueta de género
                                    Text(
                                      'Femenino',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    // Contador
                                    Text(
                                      '${genderData['female'] ?? 0}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pink,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Separador vertical
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).dividerColor,
                ),

                // Mitad derecha: Distribución por edad
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Distribución por edad',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Tarjetas de edad en un scroll
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: ageData.entries.map<Widget>((entry) {
                              // Determinar color e icono basado en el rango de edad
                              late Color color;
                              late IconData icon;

                              if (entry.key == '0-18') {
                                color = Colors.green;
                                icon = Icons.child_care;
                              } else if (entry.key == '19-25') {
                                color = Colors.teal;
                                icon = Icons.school;
                              } else if (entry.key == '26-35') {
                                color = Colors.indigo;
                                icon = Icons.work;
                              } else if (entry.key == '36-50') {
                                color = Colors.amber;
                                icon = Icons.business_center;
                              } else {
                                color = Colors.red;
                                icon = Icons.elderly;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: color.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        // Icono representando el rango de edad
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 24,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Información del rango de edad
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Edad: ${entry.key}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Cantidad
                                              Text(
                                                'Cantidad: ${entry.value}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Valor numérico grande
                                        Text(
                                          '${entry.value}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
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
          Text(
            'Categorías Más y Menos Visitadas Históricamente',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Comparativa entre las categorías con mayor y menor número de visitas históricamente',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
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

          // Explanation text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'Estas estadísticas muestran las preferencias de los clientes al visitar las diferentes categorías de productos de la tienda históricamente.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
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
      'Frutas': '🍎',
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
}
