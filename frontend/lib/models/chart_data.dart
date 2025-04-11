// Modelos de datos para gráficos

// Datos para gráfico de horas
class HourData {
  final String hour;
  final double count;

  HourData({required this.hour, required this.count});
}

// Datos para gráfico de días
class DayData {
  final String day;
  final int count;

  DayData({required this.day, required this.count});
}

// Datos para gráfico de categorías
class CategoryData {
  final String category;
  final int count;

  CategoryData({required this.category, required this.count});
}

// Datos para gráfico de emociones
class EmotionData {
  final String emotion;
  final int count;
  final double percentage;

  EmotionData(
      {required this.emotion, required this.count, required this.percentage});
}

// Datos para gráfico de géneros
class GenderData {
  final String gender;
  final int count;
  final double percentage;

  GenderData(
      {required this.gender, required this.count, required this.percentage});
}

// Datos para gráfico de edades
class AgeData {
  final String range;
  final int count;

  AgeData({required this.range, required this.count});
}
