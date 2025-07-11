class HeatmapLocation {
  final String sensorId;
  final double avgPrincipal;
  final double avgMedium;
  final double avgFar;
  final int maxPrincipal;
  final int totalReadings;
  final DateTime lastUpdate;

  HeatmapLocation({
    required this.sensorId,
    required this.avgPrincipal,
    required this.avgMedium,
    required this.avgFar,
    required this.maxPrincipal,
    required this.totalReadings,
    required this.lastUpdate,
  });

  factory HeatmapLocation.fromJson(Map<String, dynamic> json) {
    // Debug para ver qué contiene el JSON
    print('JSON recibido: $json');

    return HeatmapLocation(
      sensorId: json['sensor_id'],
      avgPrincipal: json['avgPrincipal']?.toDouble() ?? 0.0,
      avgMedium: json['avgMedium']?.toDouble() ?? 0.0,
      avgFar: json['avgFar']?.toDouble() ?? 0.0,
      maxPrincipal: json['maxPrincipal'] ?? 0,
      totalReadings: json['totalReadings'] ?? 0,
      lastUpdate: json.containsKey('lastUpdate')
          ? DateTime.parse(json['lastUpdate'])
          : DateTime.now(),
    );
  }
}

class StoreCategory {
  final String id;
  final String name;
  final int tipoProducto;
  final String icon;
  final bool isActive;

  StoreCategory({
    required this.id,
    required this.name,
    required this.tipoProducto,
    required this.icon,
    required this.isActive,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['_id'],
      name: json['Categoria_Producto'],
      tipoProducto: json['Tipo_Producto'],
      icon: json['icon'] ?? 'category',
      isActive: json['isActive'] ?? false,
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

  // Create a StoreLayout from a list of categories
  factory StoreLayout.fromCategories(List<StoreCategory> categories) {
    // Create a layout with the categories arranged in a grid
    const double width = 1000;
    const double height = 700;
    int numCategories = categories.length;

    // Determine grid layout based on number of categories
    int rows = (numCategories > 4) ? 2 : 1;
    int cols = (numCategories / rows).ceil();

    double cellWidth = width / cols;
    double cellHeight = height / rows;

    List<ZoneDefinition> zones = [];

    // Add entrance zone
    zones.add(
      ZoneDefinition(
        id: 'entrance',
        name: 'Entrada',
        x: 50,
        y: height - 100,
        width: 150,
        height: 80,
        category: 'Entrada',
        tipoProducto: 0,
        icon: 'storefront',
      ),
    );

    // Add category zones in a grid layout
    for (int i = 0; i < categories.length; i++) {
      int row = i ~/ cols;
      int col = i % cols;

      zones.add(
        ZoneDefinition(
          id: categories[i].tipoProducto.toString(),
          name: categories[i].name,
          x: col * cellWidth + 50,
          y: row * cellHeight + 100,
          width: cellWidth - 50,
          height: cellHeight - 50,
          category: categories[i].name,
          tipoProducto: categories[i].tipoProducto,
          icon: categories[i].icon,
        ),
      );
    }

    return StoreLayout(
      width: width,
      height: height,
      zones: zones,
    );
  }
}

class ZoneDefinition {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final String category;
  final int tipoProducto;
  final String icon;

  ZoneDefinition({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.category,
    required this.tipoProducto,
    required this.icon,
  });
}
