import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab_instrument_identifier/models/prediction.dart';
import 'package:lab_instrument_identifier/models/scan_history.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/screens/detail_screen.dart';
import 'package:lab_instrument_identifier/screens/results_screen.dart';

void main() {
  group('superficies adaptables de resultados', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'usa roles del esquema en modo ${brightness.name}',
        (tester) async {
          final colorScheme = _buildColorScheme(brightness);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                predictionNotifierProvider.overrideWith(
                  (ref) => _PredictionSuccessNotifier(ref),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
                home: const ResultsScreen(imagePath: 'captura-prueba.jpg'),
              ),
            ),
          );

          final category = tester.widget<Container>(
            find.byKey(const Key('resultsCategoryBadge')),
          );
          final categoryDecoration = category.decoration! as BoxDecoration;
          expect(
            categoryDecoration.color,
            colorScheme.surfaceContainerHighest,
          );

          final categoryText = tester.widget<Text>(find.text('Óptica'));
          expect(categoryText.style?.color, colorScheme.onSurfaceVariant);

          final alternative = tester.widget<Container>(
            find.byKey(const Key('resultsAlternative-Probeta')),
          );
          final alternativeDecoration =
              alternative.decoration! as BoxDecoration;
          expect(alternativeDecoration.color, colorScheme.surfaceContainerLow);
          expect(
            alternativeDecoration.border,
            Border.all(color: colorScheme.outlineVariant),
          );

          final information = tester.widget<Container>(
            find.byKey(const Key('resultsInformationCard')),
          );
          final informationDecoration =
              information.decoration! as BoxDecoration;
          expect(
            informationDecoration.color,
            colorScheme.surfaceContainerHighest,
          );
        },
      );
    }
  });

  group('superficies adaptables del detalle', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'usa roles del esquema en modo ${brightness.name}',
        (tester) async {
          final colorScheme = _buildColorScheme(brightness);
          final scan = _buildScan();

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
                home: DetailScreen(scanId: scan.id, scan: scan),
              ),
            ),
          );

          final imageSurface = tester.widget<Container>(
            find.byKey(const Key('detailImageSurface')),
          );
          final imageDecoration = imageSurface.decoration! as BoxDecoration;
          expect(imageDecoration.color, colorScheme.surfaceContainerHighest);

          final category = tester.widget<Container>(
            find.byKey(const Key('detailCategoryBadge')),
          );
          final categoryDecoration = category.decoration! as BoxDecoration;
          expect(
            categoryDecoration.color,
            colorScheme.surfaceContainerHighest,
          );

          final alternative = tester.widget<Container>(
            find.byKey(const Key('detailAlternative-Probeta')),
          );
          final alternativeDecoration =
              alternative.decoration! as BoxDecoration;
          expect(alternativeDecoration.color, colorScheme.surfaceContainerLow);
          expect(
            alternativeDecoration.border,
            Border.all(color: colorScheme.outlineVariant),
          );

          final technicalInfo = tester.widget<ExpansionTile>(
            find.byKey(const Key('detailTechnicalInfo')),
          );
          final technicalShape = technicalInfo.shape! as RoundedRectangleBorder;
          expect(technicalShape.side.color, colorScheme.outlineVariant);
        },
      );
    }
  });
}

/// Crea esquemas controlados para comprobar que la UI no usa colores fijos.
ColorScheme _buildColorScheme(Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: const Color(0xFF3457D5),
    brightness: brightness,
  );
}

/// Notifier de prueba que evita ejecutar el modelo y entrega datos conocidos.
class _PredictionSuccessNotifier extends PredictionNotifier {
  _PredictionSuccessNotifier(super.ref) {
    state = const PredictionState.success([
      Prediction(
        name: 'Microscopio',
        confidence: 0.91,
        category: 'Óptica',
        description: 'Instrumento empleado para observar muestras pequeñas.',
      ),
      Prediction(
        name: 'Probeta',
        confidence: 0.06,
        category: 'Medición',
      ),
    ]);
  }
}

/// Registro completo que activa todas las superficies relevantes del detalle.
ScanHistory _buildScan() {
  return ScanHistory(
    id: 'scan-tema',
    timestamp: DateTime(2026, 8, 11, 9, 30),
    imagePath: 'imagen-inexistente.jpg',
    predictedInstrument: 'Microscopio',
    confidence: 0.91,
    top3Predictions: const [
      Prediction(
        name: 'Microscopio',
        confidence: 0.91,
        category: 'Óptica',
      ),
      Prediction(
        name: 'Probeta',
        confidence: 0.06,
        category: 'Medición',
      ),
    ],
  );
}
