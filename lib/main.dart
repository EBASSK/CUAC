import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'config/app_config.dart';
import 'models/scan_history.dart';
import 'screens/splash_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/settings_screen.dart';

// Punto de entrada principal de la aplicación Flutter
// Se ejecuta antes de que se inflen los widgets para inicializar servicios
void main() async {
  // Asegura que Flutter esté inicializado antes de cualquier operación asíncrona
  // Esto es crucial para acceder a plugins nativos y servicios del sistema
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la configuración global de la aplicación
  // Incluye configuración de permisos, rutas de almacenamiento, etc.
  await AppConfig.initialize();

  // Envuelve la aplicación con ProviderScope para habilitar Riverpod
  // Esto permite la inyección de dependencias y gestión de estado global
  runApp(const ProviderScope(child: MyApp()));
}

// Widget raíz de la aplicación
// ConsumerWidget permite acceder a los providers de Riverpod
class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Configuración del router declarativo con GoRouter
    // Define todas las rutas de navegación de la aplicación
    final router = GoRouter(
      // Ruta inicial: pantalla de splash para inicialización
      initialLocation: '/',
      routes: [
        // Pantalla de bienvenida y inicialización de servicios
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        // Pantalla de captura de imágenes con la cámara
        GoRoute(
          path: '/camera',
          builder: (context, state) => const CameraScreen(),
        ),
        // Pantalla de resultados del análisis de IA
        // Recibe la ruta de la imagen capturada como parámetro extra
        GoRoute(
          path: '/results',
          builder: (context, state) {
            // Extrae la ruta de la imagen del estado de navegación
            final imagePath = state.extra as String?;
            // Validación: si no hay imagen, muestra error
            if (imagePath == null || imagePath.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('No se encontró la ruta de resultados.'),
                ),
              );
            }
            // Pasa la imagen a la pantalla de resultados
            return ResultsScreen(imagePath: imagePath);
          },
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/detail/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final scan = state.extra as ScanHistory?;
            return DetailScreen(scanId: id, scan: scan);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${state.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
