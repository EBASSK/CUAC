import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/app_config.dart';

/// Convierte una imagen codificada al tensor que exige el modelo desplegado.
///
/// El contrato de salida tiene forma `[1][alto][ancho][3]`: un lote con una
/// imagen, canales RGB y valores normalizados en el intervalo `[0, 1]`.
class ModelImagePreprocessor {
  const ModelImagePreprocessor();

  /// Decodifica [imageBytes], corrige su orientación y crea el tensor de entrada.
  ///
  /// La imagen se redimensiona directamente al tamaño configurado, sin recorte
  /// ni relleno, porque así se prepararon los datos del modelo actual. Lanza
  /// [FormatException] cuando los bytes no representan una imagen decodificable.
  List<List<List<List<double>>>> preprocess(Uint8List imageBytes) {
    img.Image? decodedImage;
    try {
      decodedImage = img.decodeImage(imageBytes);
    } catch (_) {
      throw const FormatException('No se pudo decodificar la imagen');
    }
    if (decodedImage == null) {
      throw const FormatException('No se pudo decodificar la imagen');
    }

    // Materializa la orientación EXIF para que la cámara y el modelo observen
    // la imagen en la misma posición, independientemente del dispositivo.
    final orientedImage = img.bakeOrientation(decodedImage);
    final resizedImage = img.copyResize(
      orientedImage,
      width: AppConfig.modelInputSize,
      height: AppConfig.modelInputSize,
      interpolation: img.Interpolation.cubic,
    );

    // El primer nivel corresponde al lote de tamaño uno; luego se recorren
    // filas, columnas y finalmente los tres canales RGB de cada píxel.
    return [
      List<List<List<double>>>.generate(
        AppConfig.modelInputSize,
        (y) => List<List<double>>.generate(
          AppConfig.modelInputSize,
          (x) {
            final pixel = resizedImage.getPixelSafe(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
  }
}
