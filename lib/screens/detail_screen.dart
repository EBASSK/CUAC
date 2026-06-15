import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../providers/providers.dart';
import '../config/theme.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String scanId;
  final ScanHistory? scan;

  const DetailScreen({
    Key? key,
    required this.scanId,
    this.scan,
  }) : super(key: key);

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  ScanHistory? _scan;
  bool _isFavorite = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _scan = widget.scan;
    _isFavorite = _scan?.isFavorite ?? false;
    _notesController = TextEditingController(text: _scan?.userNotes ?? '');

    // Si no se pasó el scan, cargarlo desde la BD
    if (_scan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScan();
      });
    }
  }

  Future<void> _loadScan() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final scan = await db.getScanById(widget.scanId);
      if (scan != null && mounted) {
        setState(() {
          _scan = scan;
          _isFavorite = scan.isFavorite;
          _notesController.text = scan.userNotes ?? '';
        });
      }
    } catch (e) {
      // Manejar error
      print('Error cargando scan: $e');
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final scan = _scan!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del escaneo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppTheme.errorColor : null,
            ),
            onPressed: () => _toggleFavorite(scan),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Eliminar'),
                onTap: () => _deleteScan(scan),
              ),
              PopupMenuItem(
                child: const Text('Compartir'),
                onTap: () => _shareScan(scan),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del escaneo
            _buildImageSection(scan),

            const SizedBox(height: AppTheme.paddingLG),

            // Predicción principal
            _buildPredictionSection(scan),

            const SizedBox(height: AppTheme.paddingLG),

            // Información de tiempo
            _buildTimestampSection(scan),

            const SizedBox(height: AppTheme.paddingLG),

            // Top 3 predicciones
            if (scan.top3Predictions.isNotEmpty) ...[
              Text(
                'Otras predicciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildAlternativePredictions(scan),
              const SizedBox(height: AppTheme.paddingLG),
            ],

            // Notas
            Text(
              'Notas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Agrega notas sobre este escaneo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.paddingLG),

            // Botones de acción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveNotes(scan),
                icon: const Icon(Icons.save),
                label: const Text('Guardar notas'),
              ),
            ),

            const SizedBox(height: AppTheme.paddingMD),

            // Información técnica
            _buildTechnicalInfo(scan),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(ScanHistory scan) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        color: AppTheme.lightGrey,
        image: _imageFileExists(scan.imagePath)
            ? DecorationImage(
                image: FileImage(File(scan.imagePath)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !_imageFileExists(scan.imagePath)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Imagen no disponible',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildPredictionSection(ScanHistory scan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instrumento detectado',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.predictedInstrument,
                        style:
                            Theme.of(context).textTheme.headlineSmall,
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
                          'Categoría',
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getConfidenceColor(scan.confidence),
                    boxShadow: [
                      BoxShadow(
                        color: _getConfidenceColor(scan.confidence)
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
                          '${scan.confidencePercentage}%',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
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
    );
  }

  Widget _buildTimestampSection(ScanHistory scan) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha y hora',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(scan.timestamp),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativePredictions(ScanHistory scan) {
    return Column(
      children: scan.top3Predictions.skip(1).map((prediction) {
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
    );
  }

  Widget _buildTechnicalInfo(ScanHistory scan) {
    return ExpansionTile(
      title: const Text('Información técnica'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: const BorderSide(color: AppTheme.lightGrey),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTechItem('ID del escaneo', scan.id),
              _buildTechItem('Ruta de imagen', scan.imagePath),
              _buildTechItem(
                'Confianza (decimal)',
                scan.confidence.toStringAsFixed(4),
              ),
              _buildTechItem('Total de predicciones', '${scan.top3Predictions.length}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(ScanHistory scan) async {
    await ref
        .read(historyNotifierProvider.notifier)
        .toggleFavorite(scan.id);

    setState(() => _isFavorite = !_isFavorite);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite ? '⭐ Agregado a favoritos' : '✓ Removido de favoritos',
        ),
      ),
    );
  }

  Future<void> _deleteScan(ScanHistory scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar escaneo'),
        content: const Text('¿Estás seguro de que deseas eliminar este escaneo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(historyNotifierProvider.notifier).deleteScan(scan.id);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Escaneo eliminado')),
      );
    }
  }

  void _shareScan(ScanHistory scan) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compartir: próximamente')),
    );
  }

  Future<void> _saveNotes(ScanHistory scan) async {
    final updated = scan.copyWith(userNotes: _notesController.text);
    await ref.read(databaseServiceProvider).updateScan(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Notas guardadas')),
      );
    }
  }

  bool _imageFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
