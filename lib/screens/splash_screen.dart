import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/tflite_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _rotationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  late final Future<bool> _logoAssetExists;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _logoAssetExists = _checkLogoAsset();
    _introController.forward();
    _initializeApp();
  }

  Future<bool> _checkLogoAsset() async {
    try {
      await rootBundle.load('assets/imagenes/cuac_logo.png');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeApp() async {
    try {
      final tfliteService = TFLiteService();
      await tfliteService.initialize();
      print('✅ TFLite inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando TFLite: $e');
    }

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      context.go('/camera');
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkBg,
              Color(0xFF020812),
              Color(0xFF051E28),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value,
                                child: child,
                              );
                            },
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF2DD4BF).withOpacity(0.20),
                                      AppTheme.darkBg.withOpacity(0.05),
                                    ],
                                    radius: 0.9,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2DD4BF).withOpacity(0.22),
                                      blurRadius: 32,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF19C0A2),
                                          Color(0xFF0A7C8D),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2DD4BF).withOpacity(0.32),
                                          blurRadius: 18,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: FutureBuilder<bool>(
                                      future: _logoAssetExists,
                                      builder: (context, snapshot) {
                                        final hasLogo = snapshot.data == true;
                                        if (hasLogo) {
                                          return ClipOval(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Image.asset(
                                                'assets/imagenes/cuac_logo.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          );
                                        }
                                        return const Center(
                                          child: Text(
                                            '🔬',
                                            style: TextStyle(fontSize: 52),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'cuac',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withOpacity(0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lab Instrument Identifier',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF2DD4BF).withOpacity(0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 6,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.secondaryColor.withOpacity(0.95),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Inicializando Base de Datos e IA...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cargando el sistema inteligente de reconocimiento de laboratorio',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'SENA',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Servicio Nacional de Aprendizaje',
                        style: TextStyle(
                          color: Colors.white12,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
