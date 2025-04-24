import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../controllers/statistics_controller.dart';
import '../models/chart_data.dart';
import 'widgets/statistic_card.dart';
import 'widgets/statistics_selector.dart';

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

  const StatisticsView({super.key, this.toggleTheme});

  @override
  StatisticsViewState createState() => StatisticsViewState();
}

// Make the state class public by removing the underscore
class StatisticsViewState extends State<StatisticsView> {
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

  // Method to update the selected stat from outside
  void updateSelectedStat(String stat) {
    if (_selectedStat != stat) {
      setState(() {
        _selectedStat = stat;
      });
      _loadStatistics();
    }
  }

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

  // Cargar estadísticas según la opción seleccionada
  Future<void> _loadStatistics() async {
    // Si ya estamos cargando, evitar múltiples llamadas
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      print('Cargando estadísticas para: $_selectedStat');
      print('Período: $_selectedPeriod');
      print('Fecha: ${_selectedDate.toString()}');
      print('Fecha fin: ${_selectedEndDate?.toString() ?? "No seleccionada"}');
      print('Mes: $_selectedMonth');
      print('Año: $_selectedYear');

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
          if (_selectedPeriod == 'week') {
            final formatter = DateFormat('yyyy-MM-dd');
            params['date'] = formatter.format(_selectedDate);

            if (_selectedEndDate != null) {
              params['end_date'] = formatter.format(_selectedEndDate!);
            }
          } else if (_selectedPeriod == 'month' &&
              _selectedMonth != null &&
              _selectedYear != null) {
            params['month'] = _selectedMonth.toString();
            params['year'] = _selectedYear.toString();
          }
        }
      }

      print('Parámetros enviados a la API: $params');

      // Special handling for combined busy days
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
        // Limpiar caché para asegurar datos frescos
        _controller.clearCache(_selectedStat);

        final data = await _controller.getGenderAgeDistributionStatistics(
            params: params);

        print('Datos recibidos de la API: $data');

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
                _selectedMonth = currentMonth;
                _selectedYear = currentYear;

                // Limpiar caché para asegurar datos frescos
                _controller.clearCache(_selectedStat);
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
    return Padding(
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
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat('dd/MM/yyyy')
                                        .format(_selectedDate),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
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
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedEndDate != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(_selectedEndDate!)
                                        : 'No seleccionada',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
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
                    : _statisticsData == null
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
                        : _buildStatisticsContent(),
          ),
        ],
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
        content: const Center(child: Text('Datos no disponibles')),
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
        return Icons.shopping_basket; // A basket icon to represent fruits
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
    // Return a placeholder
    return Center(child: Text('Datos no disponibles'));
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
                  title: AxisTitle(text: 'Hora del día'),
                  labelIntersectAction: AxisLabelIntersectAction.rotate45,
                  labelRotation: constraints.maxWidth < 400 ? 45 : 0,
                  maximumLabels: constraints.maxWidth < 400 ? 6 : 12,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Cantidad de visitantes'),
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
          // Título (mantener color azul como se indicó)
          Text(
            'Días de la Semana con Más y Menos Afluencia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // Verde claro
                    borderRadius: BorderRadius.circular(16),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Tarjeta día menos concurrido (naranja claro)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0), // Naranja claro
                    borderRadius: BorderRadius.circular(16),
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
          Text(
            'Visualización de emociones por categoría',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona una gráfica para ver detalles o navega entre categorías.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),

          // Removed scroll indicator since we're using page-level scrolling

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
        return Theme.of(context)
            .colorScheme
            .primary; // Use app's blue theme color for "Feliz"
      case 'sad':
        return Colors.green; // Green for "Triste"
      case 'surprise':
        return Colors.amber; // Yellow/Amber for "Sorprendido"
      case 'neutral':
        return Colors.grey;
      case 'angry':
        return Colors.red;
      case 'fear':
        return Colors.purple;
      case 'disgust':
        return Colors.brown;
      case 'calm':
        return Colors.lightBlue;
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

          // Get color based on category
          final Color bgColor = category == 'Alcohol'
              ? Colors.red.shade50
              : category == 'Snacks'
                  ? Colors.green.shade50
                  : category == 'Frutas'
                      ? Colors.purple.shade50
                      : category == 'Vegetales'
                          ? Colors.teal.shade50
                          : Colors.blue.shade50;

          categoryWidgets.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category name at top
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  // Emotion in center with icon
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getEmotionIcon(emotion),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _translateEmotion(emotion),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User count at bottom right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'usuarios',
                          style: TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Emociones más frecuentes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Emociones predominantes detectadas por categoría',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Responsive grid layout
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use grid with 2 columns for wider screens, 1 column for narrower screens
                bool useTwoColumns = constraints.maxWidth > 600;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: useTwoColumns ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio:
                        3.0, // Make cards much shorter (3:1 ratio)
                  ),
                  itemCount: categoryWidgets.length,
                  itemBuilder: (context, index) => categoryWidgets[index],
                );
              },
            ),
          ),
        ],
      ),
    );
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

    // Mapeo de emociones a español e iconos Material
    final Map<String, Map<String, dynamic>> emotionTranslations = {
      'HAPPY': {'es': 'Feliz', 'icon': Icons.sentiment_very_satisfied},
      'SAD': {'es': 'Triste', 'icon': Icons.sentiment_very_dissatisfied},
      'ANGRY': {'es': 'Enojado', 'icon': Icons.mood_bad},
      'CONFUSED': {'es': 'Confundido', 'icon': Icons.sentiment_neutral},
      'DISGUSTED': {'es': 'Disgustado', 'icon': Icons.sick},
      'SURPRISED': {
        'es': 'Sorprendido',
        'icon': Icons.sentiment_very_satisfied_outlined
      },
      'CALM': {'es': 'Calmado', 'icon': Icons.sentiment_satisfied_alt},
      'FEAR': {'es': 'Temeroso', 'icon': Icons.sentiment_dissatisfied},
      'UNKNOWN': {'es': 'Desconocido', 'icon': Icons.help_outline},
    };

    // Categorías y sus íconos Material
    final Map<String, IconData> categoryIcons = {
      'Alcohol': Icons.liquor,
      'Frutas': Icons.apple,
      'Vegetales': Icons.eco,
      'Snacks': Icons.fastfood,
      'Dairy': Icons.water_drop,
      'Meat': Icons.restaurant,
      'Bakery': Icons.bakery_dining,
    };

    // Estado para rastrear qué categoría está expandida
    Map<String, bool> expandedState = {};

    return StatefulBuilder(builder: (context, setState) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diferencias emocionales por categoría',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Periodo: Semana',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Fecha de corte: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Mostrar tarjetas por categoría en formato expandible
              ...data.entries.map((categoryEntry) {
                final String categoryName = categoryEntry.key;

                // Inicializar el estado expandido si no existe
                expandedState.putIfAbsent(categoryName, () => false);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header de categoría (siempre visible y clicable)
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Cerrar todas las demás categorías
                            final wasExpanded =
                                expandedState[categoryName] ?? false;
                            expandedState.forEach((key, _) {
                              expandedState[key] = false;
                            });
                            // Invertir el estado de la categoría clicada
                            expandedState[categoryName] = !wasExpanded;
                          });
                        },
                        borderRadius: BorderRadius.vertical(
                          top: const Radius.circular(8),
                          bottom: Radius.circular(
                              expandedState[categoryName]! ? 0 : 8),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.vertical(
                              top: const Radius.circular(8),
                              bottom: Radius.circular(
                                  expandedState[categoryName]! ? 0 : 8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                categoryIcons[categoryName] ?? Icons.category,
                                size: 24,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  categoryName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Icon(
                                expandedState[categoryName]!
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Contenido expandible
                      if (expandedState[categoryName]!)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              // Hombres
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.man,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'HOMBRES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (categoryEntry.value is Map &&
                                        categoryEntry.value['male'] != null &&
                                        categoryEntry.value['male']
                                                ['predominant_emotion'] !=
                                            null)
                                      Column(
                                        children: [
                                          Icon(
                                            emotionTranslations[categoryEntry
                                                            .value['male']
                                                        ['predominant_emotion']]
                                                    ?['icon'] ??
                                                Icons.help_outline,
                                            size: 32,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            emotionTranslations[categoryEntry
                                                            .value['male']
                                                        ['predominant_emotion']]
                                                    ?['es'] ??
                                                'No disponible',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${categoryEntry.value['male']['count']} evaluaciones',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.help_outline,
                                            size: 32,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'No disponible',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            'Sin datos',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              // Línea vertical separadora
                              Container(
                                height: 80,
                                width: 1,
                                color: Colors.grey[300],
                              ),

                              // Mujeres
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.woman,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'MUJERES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (categoryEntry.value is Map &&
                                        categoryEntry.value['female'] != null &&
                                        categoryEntry.value['female']
                                                ['predominant_emotion'] !=
                                            null)
                                      Column(
                                        children: [
                                          Icon(
                                            emotionTranslations[categoryEntry
                                                            .value['female']
                                                        ['predominant_emotion']]
                                                    ?['icon'] ??
                                                Icons.help_outline,
                                            size: 32,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            emotionTranslations[categoryEntry
                                                            .value['female']
                                                        ['predominant_emotion']]
                                                    ?['es'] ??
                                                'No disponible',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${categoryEntry.value['female']['count']} evaluaciones',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.help_outline,
                                            size: 32,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'No disponible',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            'Sin datos',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
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
              }).toList(),
            ],
          ),
        ),
      );
    });
  }

  // Visualizador para distribución por edad y género por categoría
  Widget _buildAgeGenderDistributionByCategoryView(dynamic data) {
    if (data is! Map || data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Estado para rastrear qué categoría está expandida
    Map<String, bool> expandedState = {};

    return StatefulBuilder(builder: (context, setState) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título
              Text(
                'Distribución por Edad y Género por Categoría',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Mostrar datos por categoría en formato expandible
              ...data.entries.map((categoryEntry) {
                final String categoryName = categoryEntry.key;
                final Map<String, dynamic> genderData = categoryEntry.value;

                // Inicializar el estado expandido si no existe
                expandedState.putIfAbsent(categoryName, () => false);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Encabezado de categoría (siempre visible)
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Cerrar todas las demás categorías
                            final wasExpanded =
                                expandedState[categoryName] ?? false;
                            expandedState.forEach((key, _) {
                              expandedState[key] = false;
                            });
                            // Invertir el estado de la categoría clicada
                            expandedState[categoryName] = !wasExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.vertical(
                              top: const Radius.circular(12),
                              bottom: Radius.circular(
                                  expandedState[categoryName]! ? 0 : 12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(categoryName),
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                expandedState[categoryName]!
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Contenido expandible
                      if (expandedState[categoryName]!)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selector de género
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Masculino'),
                                    selected: true,
                                    onSelected: (_) {},
                                    backgroundColor: Colors.blue.shade50,
                                    selectedColor: Colors.blue.shade100,
                                    labelStyle: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Text('Femenino'),
                                    selected: true,
                                    onSelected: (_) {},
                                    backgroundColor: Colors.pink.shade50,
                                    selectedColor: Colors.pink.shade100,
                                    labelStyle: TextStyle(
                                      color: Colors.pink.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Datos de edad para masculino
                              if (genderData.containsKey('male') &&
                                  genderData['male'] is List &&
                                  genderData['male'].isNotEmpty)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children:
                                      genderData['male'].map<Widget>((ageItem) {
                                    final ageRange =
                                        _formatAgeRange(ageItem['age'] ?? 0);
                                    final count = ageItem['count'] ?? 0;

                                    return _buildAgeCard(
                                      ageRange: ageRange,
                                      count: count,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 16),

                              // Datos de edad para femenino
                              if (genderData.containsKey('female') &&
                                  genderData['female'] is List &&
                                  genderData['female'].isNotEmpty)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: genderData['female']
                                      .map<Widget>((ageItem) {
                                    final ageRange =
                                        _formatAgeRange(ageItem['age'] ?? 0);
                                    final count = ageItem['count'] ?? 0;

                                    return _buildAgeCard(
                                      ageRange: ageRange,
                                      count: count,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    );
                                  }).toList(),
                                ),

                              // Mensaje cuando no hay datos
                              if ((genderData['male'] == null ||
                                      genderData['male'].isEmpty) &&
                                  (genderData['female'] == null ||
                                      genderData['female'].isEmpty))
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No hay datos disponibles para esta categoría',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[600],
                                      ),
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
    });
  }

  // Método auxiliar para formatear el rango de edad
  String _formatAgeRange(int age) {
    if (age < 18) return 'Menor de 18';
    if (age >= 18 && age <= 25) return '18-25 años';
    if (age >= 26 && age <= 35) return '26-35 años';
    if (age >= 36 && age <= 45) return '36-45 años';
    if (age >= 46 && age <= 55) return '46-55 años';
    return 'Mayor de 55';
  }

  // Método auxiliar para construir una tarjeta de edad
  Widget _buildAgeCard(
      {required String ageRange, required int count, required Color color}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edad',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ageRange,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'personas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
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
        // Check if data is nested under 'data' key
        final dataMap = data.containsKey('data') ? data['data'] : data;

        mostVisitedCategory =
            dataMap['most_visited_category']?.toString() ?? 'No disponible';
        mostVisitedCount = (dataMap['most_visited_count'] is int)
            ? dataMap['most_visited_count']
            : int.tryParse(dataMap['most_visited_count']?.toString() ?? '0') ??
                0;

        leastVisitedCategory =
            dataMap['least_visited_category']?.toString() ?? 'No disponible';
        leastVisitedCount = (dataMap['least_visited_count'] is int)
            ? dataMap['least_visited_count']
            : int.tryParse(dataMap['least_visited_count']?.toString() ?? '0') ??
                0;
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

  // Visualizador combinado para distribución por género y edad
  Widget _buildCombinedGenderAgeDistributionView(dynamic data) {
    print('Building gender/age view with data: $data');

    // Comprobar primero si tenemos datos básicos para mostrar
    if (data == null) {
      return _buildNoDataView(
          'No hay datos disponibles para los parámetros seleccionados.');
    }

    // La estructura puede venir en diferentes formatos. Intentar adaptarnos a ambos.
    Map<String, dynamic> genderData = {};
    Map<String, dynamic> ageData = {};

    // Extraer datos de gender y age
    if (data.containsKey('data')) {
      final dataContent = data['data'];

      if (dataContent is Map) {
        // Formato 1: data contiene gender y age
        if (dataContent.containsKey('gender')) {
          genderData = Map<String, dynamic>.from(dataContent['gender']);
        }

        if (dataContent.containsKey('age')) {
          ageData = Map<String, dynamic>.from(dataContent['age']);
        }
      }
    } else if (data.containsKey('gender') && data.containsKey('age')) {
      // Formato 2: data es gender y age directamente
      genderData = Map<String, dynamic>.from(data['gender']);
      ageData = Map<String, dynamic>.from(data['age']);
    }

    print('Processed gender data: $genderData');
    print('Processed age data: $ageData');

    // Si no hay datos específicos, mostrar un mensaje
    if ((genderData.isEmpty ||
            (genderData['male'] == 0 && genderData['female'] == 0)) &&
        ageData.isEmpty) {
      return _buildNoDataView(
          'No hay datos demográficos para el período seleccionado.');
    }

    // Resto del código para mostrar la vista...
    return Column(
      children: [
        // Selectores de período y fechas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de período (semana/mes)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Período:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
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
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedPeriod = newSelection.first;
                          // Si cambiamos a mes, resetear fecha de fin
                          if (_selectedPeriod == 'month') {
                            _selectedEndDate = null;

                            // Asegurar que tenemos mes y año seleccionados
                            if (_selectedMonth == null) {
                              _selectedMonth = DateTime.now().month;
                            }
                            if (_selectedYear == null) {
                              _selectedYear = DateTime.now().year;
                            }
                          } else {
                            // Si cambiamos a semana, establecer fecha fin
                            _selectedEndDate =
                                _selectedDate.add(const Duration(days: 6));
                            // Si la fecha de fin es futura, limitarla a hoy
                            final now = DateTime.now();
                            if (_selectedEndDate!.isAfter(now)) {
                              _selectedEndDate = now;
                            }
                          }

                          // Forzar recarga de datos
                          _controller.clearCache(_selectedStat);
                          _statisticsData = null;
                        });

                        // Recargar estadísticas inmediatamente
                        _loadStatistics();
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Theme.of(context).colorScheme.primary;
                            }
                            return Theme.of(context).colorScheme.surfaceVariant;
                          },
                        ),
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Theme.of(context).colorScheme.onPrimary;
                            }
                            return Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Selector de fechas según el período
              if (_selectedPeriod == 'week') ...[
                Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rango de fechas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.start),
                        label: Text('Inicio: ${_formatDate(_selectedDate)}'),
                        onPressed: () async {
                          await _selectDate(context);
                          // Recargar inmediatamente después de seleccionar
                          if (mounted) {
                            _controller.clearCache(_selectedStat);
                            _loadStatistics();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.event_repeat),
                        label: Text(
                          'Fin: ${_selectedEndDate != null ? _formatDate(_selectedEndDate!) : "No seleccionado"}',
                        ),
                        onPressed: () async {
                          await _selectEndDate(context);
                          // Recargar inmediatamente después de seleccionar
                          if (mounted) {
                            _controller.clearCache(_selectedStat);
                            _loadStatistics();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedPeriod == 'month') ...[
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mes y año:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Mes: ${_formatMonthName(_selectedMonth)} ${_selectedYear}',
                        ),
                        onPressed: () async {
                          await _selectMonth(context);
                          // Recargar inmediatamente después de seleccionar
                          if (mounted) {
                            _controller.clearCache(_selectedStat);
                            _loadStatistics();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón para actualizar manualmente
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                      onPressed: () {
                        // Forzar recarga de datos
                        _controller.clearCache(_selectedStat);
                        _loadStatistics();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Sección de resultados
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    'Distribución demográfica',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPeriod == 'week'
                        ? 'Semana del ${_formatDate(_selectedDate)} al ${_formatDate(_selectedEndDate ?? _selectedDate.add(const Duration(days: 6)))}'
                        : 'Mes de ${_formatMonthName(_selectedMonth)} de ${_selectedYear}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Distribución por género
                  Text(
                    'Distribución por género',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjetas de género
                  Row(
                    children: [
                      // Masculino
                      Expanded(
                        child: _buildGenderCard(
                          'Masculino',
                          genderData['male'] is int
                              ? genderData['male']
                              : int.tryParse(genderData['male'].toString()) ??
                                  0,
                          Icons.man,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Femenino
                      Expanded(
                        child: _buildGenderCard(
                          'Femenino',
                          genderData['female'] is int
                              ? genderData['female']
                              : int.tryParse(genderData['female'].toString()) ??
                                  0,
                          Icons.woman,
                          Colors.pink,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Distribución por edad
                  Text(
                    'Distribución por edad',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Gráfico de edades o mensaje cuando no hay datos
                  ageData.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.show_chart_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay datos de edad para este período',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildAgeDistributionChart(ageData),
                ],
              ),
            ),
          ),
        ),
      ],
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

  // Construir tarjeta para género
  Widget _buildGenderCard(
      String gender, int count, IconData icon, Color color) {
    final total = ((_statisticsData?['data']?['gender']?['male'] ?? 0) +
            (_statisticsData?['data']?['gender']?['female'] ?? 0))
        .toDouble();

    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 42,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              gender,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir gráfico de distribución de edad
  Widget _buildAgeDistributionChart(Map<String, dynamic> ageData) {
    print('Building age chart with data: $ageData');

    // Transformar los datos para la visualización
    final List<Map<String, dynamic>> chartData = [];

    // Verificar si los datos ya están en forma de edades promedio
    bool isAverageAges = true;
    for (var key in ageData.keys) {
      if (key.contains('-') || key == '51+') {
        isAverageAges = false;
        break;
      }
    }

    if (isAverageAges) {
      print('Datos de edad promedio detectados');

      // Agrupar edades en rangos para visualización
      final Map<String, int> groupedAges = {
        '0-18': 0,
        '19-25': 0,
        '26-35': 0,
        '36-50': 0,
        '51+': 0,
      };

      // Ordenar las edades numéricamente
      final List<MapEntry<String, dynamic>> sortedEntries =
          ageData.entries.toList();
      sortedEntries.sort((a, b) {
        final int ageA = int.tryParse(a.key) ?? 0;
        final int ageB = int.tryParse(b.key) ?? 0;
        return ageA.compareTo(ageB);
      });

      // Agrupar edades en rangos
      for (var entry in sortedEntries) {
        final int age = int.tryParse(entry.key) ?? 0;
        final int count = entry.value is int
            ? entry.value
            : int.tryParse(entry.value.toString()) ?? 0;

        if (age <= 18) {
          groupedAges['0-18'] = (groupedAges['0-18'] ?? 0) + count;
        } else if (age <= 25) {
          groupedAges['19-25'] = (groupedAges['19-25'] ?? 0) + count;
        } else if (age <= 35) {
          groupedAges['26-35'] = (groupedAges['26-35'] ?? 0) + count;
        } else if (age <= 50) {
          groupedAges['36-50'] = (groupedAges['36-50'] ?? 0) + count;
        } else {
          groupedAges['51+'] = (groupedAges['51+'] ?? 0) + count;
        }
      }

      // Convertir a formato de gráfico
      groupedAges.forEach((range, count) {
        if (count > 0) {
          // Solo agregar rangos con datos
          chartData.add({'edad': range, 'count': count});
        }
      });
    } else {
      print('Datos de rangos de edad detectados');
      // API antigua con rangos fijos
      if (ageData.containsKey('0-18'))
        chartData.add({'edad': '0-18', 'count': ageData['0-18'] ?? 0});
      if (ageData.containsKey('19-25'))
        chartData.add({'edad': '19-25', 'count': ageData['19-25'] ?? 0});
      if (ageData.containsKey('26-35'))
        chartData.add({'edad': '26-35', 'count': ageData['26-35'] ?? 0});
      if (ageData.containsKey('36-50'))
        chartData.add({'edad': '36-50', 'count': ageData['36-50'] ?? 0});
      if (ageData.containsKey('51+'))
        chartData.add({'edad': '51+', 'count': ageData['51+'] ?? 0});
    }

    // Si no hay datos después de procesar, mostrar mensaje
    if (chartData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.show_chart_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay datos de edad para este período',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    print('Datos procesados para gráfico: $chartData');

    // Colores para las barras del gráfico
    final List<Color> barColors = [
      const Color(0xFF6200EA), // Deep Purple
      const Color(0xFF00BFA5), // Teal
      const Color(0xFFFFAB00), // Amber
      const Color(0xFFE64A19), // Deep Orange
      const Color(0xFF5D4037), // Brown
    ];

    return SizedBox(
      height: 300,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          title: AxisTitle(text: 'Rango de edad'),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'Cantidad'),
          labelFormat: '{value}',
          majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5]),
        ),
        series: <CartesianSeries>[
          ColumnSeries<Map<String, dynamic>, String>(
            dataSource: chartData,
            xValueMapper: (Map<String, dynamic> data, _) => data['edad'],
            yValueMapper: (Map<String, dynamic> data, _) => data['count'],
            name: 'Edad',
            pointColorMapper: (Map<String, dynamic> data, index) =>
                barColors[index % barColors.length],
            borderRadius: BorderRadius.circular(8),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.top,
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
        palette: barColors,
      ),
    );
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
        return Icons.sentiment_very_dissatisfied;
      case 'DISGUST':
        return Icons.mood_bad;
      case 'CONFUSED':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
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
}
