import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../models/prediction.dart';
import '../config/theme.dart';


class ResultsScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ResultsScreen({
    Key? key,
    required this.imagePath,
  }) : super(key: key);

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado de predicción usando Riverpod
    // predictionNotifierProvider gestiona el estado del análisis de IA
    final predictionState = ref.watch(predictionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // Volver a la pantalla anterior
        ),
      ),
      // Mostrar diferentes UI según el estado del análisis
      body: predictionState.when(
        idle: () => _buildEmptyState(context),           // Sin análisis iniciado
        loading: () => _buildLoadingState(),             // Analizando imagen
        success: (predictions) => _buildSuccessState(context, predictions), // Análisis completado
        error: (error) => _buildErrorState(context, error), // Error en análisis
      ),
    );
  }

  /// Estado vacío: cuando no hay imagen para analizar
  /// Se muestra cuando el usuario llega sin haber capturado una imagen
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin imagen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Captura una imagen para ver el resultado',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(), // Volver a cámara
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capturar'),
          ),
        ],
      ),
    );
  }

  /// Estado de carga: mientras se ejecuta el análisis de IA
  /// Muestra progreso visual para mantener al usuario informado
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(), // Spinner de carga
          const SizedBox(height: 16),
          Text(
            'Analizando imagen...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor espera',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Tarjeta con consejos para mejorar la precisión
  Widget _buildTipsCard(BuildContext context) {
    return Card(
      color: const Color(0xFFF59E0B).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Consejos para mejor precisión',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Para obtener mejores resultados:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _buildTipItem('📸 Toma la foto desde arriba, centrando el instrumento'),
            _buildTipItem('💡 Asegúrate de buena iluminación sin sombras fuertes'),
            _buildTipItem('🎯 Enfoca bien el instrumento sin objetos alrededor'),
            _buildTipItem('📏 Mantén una distancia adecuada (20-30 cm)'),
            _buildTipItem('🔄 Prueba diferentes ángulos si no funciona'),
          ],
        ),
      ),
    );
  }

  /// Item individual de consejo
  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        tip,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumGrey,
            ),
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    List<Prediction> predictions,
  ) {
    if (predictions.isEmpty) {
      return _buildErrorState(context, 'No se obtuvieron predicciones');
    }

    final topPrediction = predictions.first;
    final top3 = predictions.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Predicción Principal
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instrumento Detectado',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              topPrediction.name,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGrey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topPrediction.category,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.mediumGrey,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Indicador de confianza circular
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getConfidenceColor(topPrediction.confidence),
                          boxShadow: [
                            BoxShadow(
                              color: _getConfidenceColor(topPrediction.confidence)
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${topPrediction.confidence.toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Confianza',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingMD),

          // Consejos si la confianza es baja
          if (topPrediction.confidence < 0.7) _buildTipsCard(context),

          const SizedBox(height: AppTheme.paddingMD),

          // Otras opciones (Top 3)
          Text(
            'Otras opciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...top3.skip(1).map((prediction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.paddingMD),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lightGrey),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prediction.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prediction.category,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text('${prediction.confidence.toStringAsFixed(0)}%'),
                      backgroundColor: _getConfidenceColor(prediction.confidence)
                          .withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: AppTheme.paddingMD),

          // Información del instrumento
          if (topPrediction.description != null) ...[
            Text(
              'Información',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingMD),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Text(
                topPrediction.description ??
                    'Instrumento de laboratorio identificado correctamente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMD),
          ],

          // Notas del usuario
          Text(
            'Notas (opcional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Agrega notas sobre este escaneo...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingLG),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Nuevo escaneo'),
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: AppTheme.paddingMD),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Guardado en historial')),
                    );
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) context.go('/history');
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingMD),

          // Botón compartir
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Compartir resultado'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Compartir: próximamente'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error en la predicción',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
