import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../providers/providers.dart';

/// Centro de información y configuración de CUAC.
///
/// Organiza en tarjetas la información del modelo, permisos, privacidad,
/// detalles técnicos y licencias. No mantiene estado propio: los datos se leen
/// de servicios de Riverpod únicamente cuando el usuario abre cada opción.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Paleta local de la pantalla. Los colores constantes garantizan contraste
  // uniforme tanto en tarjetas como en diálogos y hojas inferiores.
  static const _background = Color(0xFF060A13);
  static const _panel = Color(0xFF131A29);
  static const _iconBackground = Color(0xFF1D2739);
  static const _border = Color(0xFF263145);
  static const _accent = Color(0xFFA7A5FF);
  static const _primaryText = Color(0xFFF5F7FB);
  static const _secondaryText = Color(0xFF858EA1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene las barras del sistema integradas con el fondo oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: _border,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  children: [
                    _SettingsCard(
                      icon: Icons.psychology_outlined,
                      title: 'Reconocimiento',
                      subtitle: 'Modelo local, versión y clases',
                      onTap: () => _showModelInfo(context, ref),
                    ),
                    _SettingsCard(
                      icon: Icons.photo_camera_outlined,
                      title: 'Cámara y permisos',
                      subtitle: 'Acceso a la cámara del dispositivo',
                      onTap: () => _showCameraPermissions(context, ref),
                    ),
                    _SettingsCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Datos y privacidad',
                      subtitle: 'Escaneos almacenados únicamente en tu equipo',
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    _SettingsCard(
                      icon: Icons.memory_outlined,
                      title: 'Información técnica',
                      subtitle: 'Aplicación, modelo y almacenamiento',
                      onTap: () => _showTechnicalInfo(context),
                    ),
                    _SettingsCard(
                      icon: Icons.gavel_outlined,
                      title: 'Términos y licencias',
                      subtitle: 'Uso responsable y software de terceros',
                      onTap: () => _showLegalOptions(context),
                    ),
                    _SettingsCard(
                      icon: Icons.info_outline,
                      title: 'Acerca de CUAC',
                      subtitle: 'Versión ${AppConfig.appVersion} · SENA',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Encabezado que vuelve a la ruta anterior o usa cámara como respaldo.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/camera');
              }
            },
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: _primaryText),
          ),
          const SizedBox(width: 4),
          const Text(
            'Ajustes',
            style: TextStyle(
              color: _primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Combina la configuración declarada con las etiquetas disponibles del modelo.
  Future<void> _showModelInfo(BuildContext context, WidgetRef ref) {
    final labelCount = ref.read(tfliteServiceProvider).labels.length;

    return _showInfoDialog(
      context,
      title: 'Modelo de reconocimiento',
      icon: Icons.psychology_outlined,
      children: [
        _InfoRow(label: 'Versión', value: AppConfig.modelVersion),
        _InfoRow(
          label: 'Entrada',
          value: '${AppConfig.modelInputSize} × ${AppConfig.modelInputSize} px',
        ),
        _InfoRow(
          label: 'Clases disponibles',
          value:
              labelCount == 0 ? '10 instrumentos' : '$labelCount instrumentos',
        ),
        const _InfoRow(label: 'Procesamiento', value: 'Local, sin conexión'),
      ],
    );
  }

  /// Explica el uso de cámara y ofrece abrir la configuración del dispositivo.
  Future<void> _showCameraPermissions(
    BuildContext context,
    WidgetRef ref,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        icon: const Icon(
          Icons.photo_camera_outlined,
          color: _accent,
          size: 32,
        ),
        title: const Text(
          'Cámara y permisos',
          style: TextStyle(color: _primaryText),
        ),
        content: const Text(
          'CUAC utiliza la cámara únicamente para capturar el instrumento que '
          'quieres identificar. Puedes revisar o cambiar el permiso desde los '
          'ajustes del dispositivo.',
          style: TextStyle(color: _secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              // Se cierra primero el diálogo para no mantener un contexto modal
              // activo mientras Android o iOS abre su aplicación de ajustes.
              Navigator.pop(dialogContext);
              final opened =
                  await ref.read(cameraServiceProvider).openSettings();
              if (!context.mounted || opened) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudieron abrir los ajustes.'),
                ),
              );
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  /// Informa qué datos se guardan y confirma que el proceso es local.
  Future<void> _showPrivacyDialog(BuildContext context) {
    return _showInfoDialog(
      context,
      title: 'Datos y privacidad',
      icon: Icons.shield_outlined,
      children: const [
        Text(
          'Las imágenes, resultados, favoritos y notas se almacenan '
          'únicamente en este dispositivo. El reconocimiento se ejecuta de '
          'forma local y CUAC no envía tus capturas a servidores externos.',
          style: TextStyle(color: _secondaryText, height: 1.55),
        ),
      ],
    );
  }

  /// Resume las tecnologías y versiones útiles para diagnóstico.
  Future<void> _showTechnicalInfo(BuildContext context) {
    return _showInfoDialog(
      context,
      title: 'Información técnica',
      icon: Icons.memory_outlined,
      children: const [
        _InfoRow(label: 'Aplicación', value: AppConfig.appVersion),
        _InfoRow(label: 'Modelo', value: AppConfig.modelVersion),
        _InfoRow(label: 'Motor', value: 'TensorFlow Lite'),
        _InfoRow(label: 'Base de datos', value: 'SQLite local'),
      ],
    );
  }

  /// Agrupa términos propios y licencias de terceros en una hoja inferior.
  Future<void> _showLegalOptions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Términos y licencias',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _LegalOption(
              icon: Icons.fact_check_outlined,
              title: 'Términos de uso',
              onTap: () {
                Navigator.pop(sheetContext);
                // No se espera el diálogo porque el toque ya completó su acción
                // y la hoja debe cerrar antes de presentarlo.
                unawaited(_showTermsDialog(context));
              },
            ),
            _LegalOption(
              icon: Icons.code_outlined,
              title: 'Licencias de código abierto',
              onTap: () {
                Navigator.pop(sheetContext);
                _openLicenses(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Advierte que la identificación es una ayuda educativa, no una garantía.
  Future<void> _showTermsDialog(BuildContext context) {
    return _showInfoDialog(
      context,
      title: 'Términos de uso',
      icon: Icons.fact_check_outlined,
      children: const [
        Text(
          'CUAC es una herramienta educativa de apoyo. Las identificaciones '
          'pueden contener errores y deben verificarse visualmente antes de '
          'tomar decisiones de seguridad o manipular material de laboratorio.',
          style: TextStyle(color: _secondaryText, height: 1.55),
        ),
      ],
    );
  }

  /// Abre la página de licencias generada por Flutter con el tema de CUAC.
  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Theme(
          data: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: _background,
            appBarTheme: const AppBarTheme(
              backgroundColor: _background,
              foregroundColor: _primaryText,
              elevation: 0,
            ),
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              surface: _panel,
            ),
          ),
          child: const LicensePage(
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
          ),
        ),
      ),
    );
  }

  /// Presenta descripción, versión y autoría declaradas en AppConfig.
  Future<void> _showAboutDialog(BuildContext context) {
    return _showInfoDialog(
      context,
      title: 'Acerca de CUAC',
      icon: Icons.info_outline,
      children: const [
        Text(
          AppConfig.appDescription,
          style: TextStyle(color: _secondaryText, height: 1.55),
        ),
        SizedBox(height: 18),
        _InfoRow(label: 'Versión', value: AppConfig.appVersion),
        _InfoRow(label: 'Desarrollado por', value: AppConfig.appAuthor),
        _InfoRow(label: 'Proyecto', value: 'SENA'),
      ],
    );
  }

  /// Plantilla común para diálogos informativos de apariencia consistente.
  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        icon: Icon(icon, color: _accent, size: 32),
        title: Text(
          title,
          style: const TextStyle(color: _primaryText),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta táctil reutilizada para cada categoría de ajustes.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: SettingsScreen._panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: SettingsScreen._border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: SettingsScreen._iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: SettingsScreen._accent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: SettingsScreen._primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SettingsScreen._secondaryText,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: SettingsScreen._secondaryText,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de etiqueta y valor usada en fichas técnicas y de versión.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: SettingsScreen._secondaryText),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: SettingsScreen._primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrada navegable dentro de la hoja de términos y licencias.
class _LegalOption extends StatelessWidget {
  const _LegalOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: SettingsScreen._accent),
      title: Text(
        title,
        style: const TextStyle(color: SettingsScreen._primaryText),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: SettingsScreen._secondaryText,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
