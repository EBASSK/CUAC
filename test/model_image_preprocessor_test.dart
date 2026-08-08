import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lab_instrument_identifier/config/app_config.dart';
import 'package:lab_instrument_identifier/services/model_image_preprocessor.dart';

void main() {
  test('produce un tensor RGB 224x224 normalizado entre 0 y 1', () {
    final source = img.Image(width: 3, height: 2);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    final encodedImage = Uint8List.fromList(img.encodePng(source));

    final tensor = const ModelImagePreprocessor().preprocess(encodedImage);

    expect(tensor, hasLength(1));
    expect(tensor.first, hasLength(AppConfig.modelInputSize));
    expect(tensor.first.first, hasLength(AppConfig.modelInputSize));
    expect(tensor.first.first.first, hasLength(3));
    expect(tensor.first.first.first[0], closeTo(1, 0.001));
    expect(tensor.first.first.first[1], closeTo(0, 0.001));
    expect(tensor.first.first.first[2], closeTo(0, 0.001));
  });

  test('rechaza bytes que no representan una imagen', () {
    expect(
      () => const ModelImagePreprocessor().preprocess(
        Uint8List.fromList([1, 2, 3]),
      ),
      throwsFormatException,
    );
  });
}
