class HeatmapLocation {
  final String locationId;
  final double avgCount;
  final int maxCount;
  final int totalReadings;
  final DateTime lastUpdate;

  HeatmapLocation({
    required this.locationId,
    required this.avgCount,
    required this.maxCount,
    required this.totalReadings,
    required this.lastUpdate,
  });

  factory HeatmapLocation.fromJson(Map<String, dynamic> json) {
    return HeatmapLocation(
      locationId: json['location_id'],
      avgCount: json['avgCount'].toDouble(),
      maxCount: json['maxCount'],
      totalReadings: json['totalReadings'],
      lastUpdate: DateTime.parse(json['lastUpdate']),
    );
  }
}

class StoreLayout {
  final double width;
  final double height;
  final List<ZoneDefinition> zones;

  StoreLayout({
    required this.width,
    required this.height,
    required this.zones,
  });
}

class ZoneDefinition {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final String category;

  ZoneDefinition({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.category,
  });
}

// Example store layout for testing
final demoStoreLayout = StoreLayout(
  width: 1000,
  height: 700,
  zones: [
    ZoneDefinition(
      id: 'ZONE_1',
      name: 'Entrance',
      x: 50,
      y: 600,
      width: 150,
      height: 80,
      category: 'Entrance',
    ),
    ZoneDefinition(
      id: 'ZONE_2',
      name: 'Electronics',
      x: 250,
      y: 100,
      width: 300,
      height: 200,
      category: 'Electronics',
    ),
    ZoneDefinition(
      id: 'ZONE_3',
      name: 'Clothing',
      x: 600,
      y: 100,
      width: 300,
      height: 200,
      category: 'Clothing',
    ),
    ZoneDefinition(
      id: 'ZONE_4',
      name: 'Grocery',
      x: 250,
      y: 400,
      width: 300,
      height: 200,
      category: 'Grocery',
    ),
    ZoneDefinition(
      id: 'ZONE_5',
      name: 'Home & Kitchen',
      x: 600,
      y: 400,
      width: 300,
      height: 200,
      category: 'Home',
    ),
  ],
);
