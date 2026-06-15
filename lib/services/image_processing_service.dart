import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._internal();
  final Logger _logger = Logger();

  factory ImageProcessingService() {
    return _instance;
  }

  ImageProcessingService._internal();

  /// Carga imagen desde ruta y la procesa
  Future<Uint8List?> loadAndProcessImage(String imagePath) async {
    try {
      _logger.i('Procesando imagen: $imagePath');

      final file = File(imagePath);
      if (!file.existsSync()) {
        throw Exception('Archivo no encontrado: $imagePath');
      }

      // Leer archivo
      final bytes = await file.readAsBytes();

      // Validar tamaño
      if (bytes.length > AppConfig.maxImageSizeBytes) {
        _logger.w('Imagen muy grande, comprimiendo...');
        return await _compressImage(bytes);
      }

      return bytes;
    } catch (e) {
      _logger.e('Error procesando imagen: $e');
      return null;
    }
  }

  /// Comprime imagen
  Future<Uint8List?> _compressImage(Uint8List imageBytes) async {
    try {
      _logger.i('Comprimiendo imagen...');

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        _logger.w('No se pudo decodificar la imagen');
        return imageBytes;
      }

      final resized = img.copyResize(
        image,
        width: image.width > 1024 ? 1024 : image.width,
      );

      final compressed = img.encodeJpg(resized, quality: 70);

      _logger.i(
        'Imagen comprimida: ${imageBytes.length} -> ${compressed.length} bytes',
      );

      return Uint8List.fromList(compressed);
    } catch (e) {
      _logger.e('Error comprimiendo imagen: $e');
      return imageBytes;
    }
  }

  /// Valida calidad de imagen (tamaño, formato, iluminación)
  Future<ImageValidationResult> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);

      // Validar existencia
      if (!file.existsSync()) {
        return ImageValidationResult(
          isValid: false,
          message: 'Archivo no encontrado',
        );
      }

      // Validar tamaño
      final size = file.lengthSync();
      if (size > AppConfig.maxImageSizeBytes) {
        return ImageValidationResult(
          isValid: false,
          message: 'Imagen muy grande (máx: 5MB)',
        );
      }

      // Validar formato y calidad básica
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return ImageValidationResult(
          isValid: false,
          message: 'Formato de imagen no válido',
        );
      }

      // Validar dimensiones mínimas
      if (image.width < 224 || image.height < 224) {
        return ImageValidationResult(
          isValid: false,
          message: 'Imagen muy pequeña (mín: 224x224)',
        );
      }

      // Calcular brillo promedio para detectar iluminación pobre
      double totalBrightness = 0;
      int pixelCount = 0;

      for (int y = 0; y < image.height; y += 10) { // Sample cada 10 píxeles
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixelSafe(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
          totalBrightness += brightness;
          pixelCount++;
        }
      }

      final avgBrightness = totalBrightness / pixelCount;

      // Si la imagen es muy oscura o muy clara, advertir
      if (avgBrightness < 50) {
        _logger.w('Imagen muy oscura (brillo promedio: ${avgBrightness.toStringAsFixed(1)})');
      } else if (avgBrightness > 200) {
        _logger.w('Imagen muy clara (brillo promedio: ${avgBrightness.toStringAsFixed(1)})');
      }

      return ImageValidationResult(
        isValid: true,
        message: 'Imagen válida',
        brightness: avgBrightness,
      );
    } catch (e) {
      return ImageValidationResult(
        isValid: false,
        message: 'Error validando imagen: $e',
      );
    }
  }

  /// Obtiene miniatura de imagen
  Future<Uint8List?> getThumbnail(
    String imagePath, {
    int size = 128,
  }) async {
    try {
      _logger.i('Generando miniatura...');

      final file = File(imagePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
      );

      return Uint8List.fromList(img.encodeJpg(thumbnail));
    } catch (e) {
      _logger.e('Error generando miniatura: $e');
      return null;
    }
  }

  /// Obtiene información de imagen
  Future<ImageInfo?> getImageInfo(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      return ImageInfo(
        path: imagePath,
        size: bytes.length,
        width: image.width,
        height: image.height,
        format: _detectFormat(bytes),
        lastModified: file.lastModifiedSync(),
      );
    } catch (e) {
      _logger.e('Error obteniendo info de imagen: $e');
      return null;
    }
  }

  /// Detecta formato de imagen
  String _detectFormat(Uint8List bytes) {
    if (bytes.length < 4) return 'unknown';

    // JPG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && 
        bytes[1] == 0x50 && 
        bytes[2] == 0x4E && 
        bytes[3] == 0x47) {
      return 'png';
    }

    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'gif';
    }

    return 'unknown';
  }

  /// Guarda imagen en directorio de aplicación
  Future<String?> saveImage(Uint8List imageBytes, String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/scans');

      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(imageBytes);

      _logger.i('Imagen guardada: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Error guardando imagen: $e');
      return null;
    }
  }

  /// Elimina imagen
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        await file.delete();
        _logger.i('Imagen eliminada: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error eliminando imagen: $e');
      return false;
    }
  }
}

/// Resultado de validación de imagen
class ImageValidationResult {
  final bool isValid;
  final String message;
  final int? width;
  final int? height;
  final double? brightness; // Brillo promedio 0-255

  ImageValidationResult({
    required this.isValid,
    required this.message,
    this.width,
    this.height,
    this.brightness,
  });

  @override
  String toString() => 'ImageValidationResult(isValid: $isValid, message: $message, brightness: $brightness)';
}

/// Información de imagen
class ImageInfo {
  final String path;
  final int size;
  final int width;
  final int height;
  final String format;
  final DateTime lastModified;

  ImageInfo({
    required this.path,
    required this.size,
    required this.width,
    required this.height,
    required this.format,
    required this.lastModified,
  });

  String get sizeInMB => '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  String get dimensions => '${width}x$height';

  @override
  String toString() => 'ImageInfo(format: $format, dimensions: $dimensions, size: $sizeInMB)';
}
