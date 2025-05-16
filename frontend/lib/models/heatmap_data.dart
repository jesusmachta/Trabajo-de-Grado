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
