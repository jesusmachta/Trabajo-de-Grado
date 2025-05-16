import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/heatmap_controller.dart';
import '../models/heatmap_data.dart';
import '../widgets/heatmap_legend.dart';

class HeatmapView extends StatefulWidget {
  const HeatmapView({Key? key}) : super(key: key);

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  late HeatmapController _controller;
  List<HeatmapLocation> _heatmapData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Store layout
  final StoreLayout _storeLayout = demoStoreLayout;

  // Maximum activity value for scaling
  double _maxActivity = 0;

  @override
  void initState() {
    super.initState();
    // El controller se inicializará en didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar el controlador una vez que el context esté disponible
    _controller = HeatmapController(context);
    _fetchHeatmapData();
  }

  Future<void> _fetchHeatmapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await _controller.getAggregatedHeatmapData();

      // Find max activity for scaling
      double maxVal = 0;
      for (var location in data) {
        if (location.avgCount > maxVal) {
          maxVal = location.avgCount;
        }
      }

      setState(() {
        _heatmapData = data;
        _maxActivity = maxVal > 0 ? maxVal : 1; // Avoid division by zero
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Heat Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHeatmapData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.1,
                        maxScale: 3.0,
                        child: Center(
                          child: Container(
                            width: _storeLayout.width,
                            height: _storeLayout.height,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              color: Colors.grey[200],
                            ),
                            child: Stack(
                              children: [
                                // Draw store zones
                                ..._storeLayout.zones.map((zone) => Positioned(
                                      left: zone.x,
                                      top: zone.y,
                                      width: zone.width,
                                      height: zone.height,
                                      child: _buildZone(zone),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Add legend at bottom
                    const HeatmapLegend(),
                  ],
                ),
    );
  }

  Widget _buildZone(ZoneDefinition zone) {
    // Find the heatmap data for this zone
    final zoneData = _heatmapData.firstWhere(
      (element) => element.locationId == zone.id,
      orElse: () => HeatmapLocation(
        locationId: zone.id,
        avgCount: 0,
        maxCount: 0,
        totalReadings: 0,
        lastUpdate: DateTime.now(),
      ),
    );

    // Calculate intensity between 0.0 and 1.0
    final intensity =
        _maxActivity > 0 ? (zoneData.avgCount / _maxActivity) : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black45),
        color: _getHeatColor(intensity),
      ),
      child: Stack(
        children: [
          // Zone name
          Positioned(
            top: 5,
            left: 5,
            child: Text(
              zone.name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Activity level
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Activity: ${zoneData.avgCount.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to get color based on intensity
  Color _getHeatColor(double intensity) {
    // Clamp intensity between 0.0 and 1.0
    intensity = intensity.clamp(0.0, 1.0);

    if (intensity < 0.3) {
      // Blue to green (cold)
      return Color.lerp(
        Colors.blue.withOpacity(0.5),
        Colors.green.withOpacity(0.5),
        intensity / 0.3,
      )!;
    } else if (intensity < 0.7) {
      // Green to yellow (moderate)
      return Color.lerp(
        Colors.green.withOpacity(0.5),
        Colors.yellow.withOpacity(0.7),
        (intensity - 0.3) / 0.4,
      )!;
    } else {
      // Yellow to red (hot)
      return Color.lerp(
        Colors.yellow.withOpacity(0.7),
        Colors.red.withOpacity(0.8),
        (intensity - 0.7) / 0.3,
      )!;
    }
  }
}
