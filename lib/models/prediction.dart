// Niveles de confianza para clasificar la precisión de las predicciones
enum ConfidenceLevel { high, medium, low }

// Modelo de datos principal para representar una predicción de instrumento
// Esta clase se usa tanto para resultados de IA como para almacenamiento en BD
class Prediction {
  final String name;        // Nombre del instrumento identificado (ej: "Microscopio")
  final double confidence;  // Nivel de confianza entre 0.0 y 1.0
  final String category;    // Categoría del instrumento (ej: "Óptica", "Medición")
  final String? description; // Descripción opcional del instrumento
  final String? imageUrl;   // URL de imagen de referencia (opcional)

  const Prediction({
    required this.name,
    required this.confidence,
    required this.category,
    this.description,
    this.imageUrl,
  });

  /// Convierte la confianza a porcentaje para mostrar al usuario
  /// Ejemplo: 0.85 → 85
  int getConfidencePercent() {
    return (confidence * 100).toInt();
  }

  /// Determina el nivel de confianza basado en umbrales predefinidos
  /// Se usa para mostrar colores y emojis diferentes en la UI
  ConfidenceLevel getConfidenceLevel() {
    if (confidence >= 0.8) return ConfidenceLevel.high;    // Verde - muy confiable
    if (confidence >= 0.5) return ConfidenceLevel.medium;  // Naranja - moderadamente confiable
    return ConfidenceLevel.low;                            // Rojo - poco confiable
  }

  /// Devuelve un color basado en el nivel de confianza
  /// Se usa para indicadores visuales en la interfaz
  String getConfidenceColor() {
    final level = getConfidenceLevel();
    switch (level) {
      case ConfidenceLevel.high:
        return '#10B981'; // Verde - éxito
      case ConfidenceLevel.medium:
        return '#F59E0B'; // Naranja - advertencia
      case ConfidenceLevel.low:
        return '#EF4444'; // Rojo - error
    }
  }

  /// Serializa el objeto a JSON para almacenamiento en base de datos
  /// Convierte el objeto Dart en un Map que puede ser convertido a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  /// Crea un objeto Prediction desde JSON
  /// Deserializa datos de la base de datos de vuelta a objeto Dart
  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      name: json['name'] as String,
      confidence: json['confidence'] as double,
      category: json['category'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
