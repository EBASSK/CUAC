import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import '../services/camera_service.dart';
import '../providers/providers.dart';
import '../config/theme.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late CameraService _cameraService;
  bool _isInitialized = false;
  bool _isFlashOn = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _cameraService = ref.read(cameraServiceProvider);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      final limits = await _cameraService.getZoomLimits();
      setState(() {
        _isInitialized = true;
        _minZoom = limits['min']!;
        _maxZoom = limits['max']!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _captureAndPredict() async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );

      // Capturar foto
      final image = await _cameraService.takePicture();
      if (image == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al capturar foto')),
        );
        return;
      }

      // Realizar predicción
      await ref.read(predictionNotifierProvider.notifier).predict(image.path);

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      // Navegar a resultados
      if (mounted) {
        context.push('/results', extra: image.path);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    await _cameraService.toggleFlash();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  Future<void> _handleZoom(double value) async {
    await _cameraService.controller?.setZoomLevel(value);
    setState(() => _zoomLevel = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraService.controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capturar')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text('Inicializando cámara...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Vista previa de cámara
          CameraPreview(_cameraService.controller!),

          // Overlay oscuro con marco central
          Container(
            color: Colors.black.withOpacity(0.3),
            child: CustomPaint(
              painter: CameraFramePainter(),
              child: Container(),
            ),
          ),

          // Barra superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón historial
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: () => context.push('/history'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // Título
                    Expanded(
                      child: Center(
                        child: Text(
                          'Escanear Instrumento',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    // Botón configuración
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () => context.push('/settings'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Controles inferiores
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Control de zoom
                  if (_maxZoom > 1.0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Slider(
                            value: _zoomLevel,
                            min: _minZoom,
                            max: _maxZoom,
                            onChanged: _handleZoom,
                            activeColor: AppTheme.primaryColor,
                            inactiveColor: Colors.white30,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Zoom: ${_zoomLevel.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botón Flash
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: _isFlashOn
                                  ? AppTheme.accentColor
                                  : Colors.white,
                            ),
                            onPressed: _toggleFlash,
                          ),
                        ),
                        // Botón Capturar (Principal)
                        GestureDetector(
                          onTap: _captureAndPredict,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        // Botón Galería (placeholder)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.image,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Galería: próximamente'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}

/// Custom painter para marco de cámara
class CameraFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 300.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: frameSize,
      height: frameSize,
    );

    // Dibujar rectángulo con esquinas redondeadas
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Pintar área oscura fuera del marco
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );

    // Dibujar borde del marco
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Dibujar esquinas
    const cornerSize = 30.0;
    const cornerWidth = 4.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke;

    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + cornerSize)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + cornerSize, rect.top),
      paint,
    );

    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + cornerSize),
      paint,
    );

    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - cornerSize)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left + cornerSize, rect.bottom),
      paint,
    );

    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.bottom - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(CameraFramePainter oldDelegate) => false;
}
