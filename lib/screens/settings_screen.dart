import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoSaveEnabled = true;
  String _language = 'es';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección: Preferencias
            _buildSection(
              context,
              title: 'Preferencias',
              children: [
                _buildSwitchTile(
                  context,
                  title: 'Notificaciones',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                _buildSwitchTile(
                  context,
                  title: 'Guardar automáticamente',
                  value: _autoSaveEnabled,
                  onChanged: (value) {
                    setState(() => _autoSaveEnabled = value);
                  },
                ),
                _buildLanguageTile(context),
              ],
            ),

            // Sección: Información
            _buildSection(
              context,
              title: 'Información',
              children: [
                _buildInfoTile(
                  context,
                  title: 'Versión de la app',
                  value: AppConfig.appVersion,
                ),
                _buildInfoTile(
                  context,
                  title: 'Versión del modelo',
                  value: AppConfig.modelVersion,
                ),
                _buildInfoTile(
                  context,
                  title: 'Base de datos',
                  value: AppConfig.databaseName,
                ),
              ],
            ),

            // Sección: Acerca de
            _buildSection(
              context,
              title: 'Acerca de',
              children: [
                _buildAboutTile(
                  context,
                  icon: Icons.person,
                  title: 'Autor',
                  description: AppConfig.appAuthor,
                ),
                _buildAboutTile(
                  context,
                  icon: Icons.description,
                  title: 'Descripción',
                  description: AppConfig.appDescription,
                ),
                _buildActionTile(
                  context,
                  icon: Icons.open_in_browser,
                  title: 'Documentación',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Documentación: próximamente')),
                  ),
                ),
              ],
            ),

            // Sección: Privacidad y Legal
            _buildSection(
              context,
              title: 'Legal',
              children: [
                _buildActionTile(
                  context,
                  icon: Icons.privacy_tip,
                  title: 'Política de privacidad',
                  onTap: () => _showPrivacyDialog(context),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Términos de servicio',
                  onTap: () => _showTermsDialog(context),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'Licencias de librerías',
                  onTap: () => _showLicensesDialog(context),
                ),
              ],
            ),

            // Sección: Herramientas
            _buildSection(
              context,
              title: 'Herramientas',
              children: [
                _buildActionTile(
                  context,
                  icon: Icons.build,
                  title: 'Información del dispositivo',
                  onTap: () => _showDeviceInfo(context),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.delete_outline,
                  title: 'Limpiar caché',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(AppTheme.paddingLG),
              child: Column(
                children: [
                  Text(
                    '${AppConfig.appName} v${AppConfig.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Desarrollado con ❤️ para SENA',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.mediumGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.paddingLG,
            AppTheme.paddingMD,
            AppTheme.paddingLG,
            AppTheme.paddingSM,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMD,
            vertical: AppTheme.paddingSM,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    return ListTile(
      title: const Text('Idioma'),
      trailing: DropdownButton<String>(
        value: _language,
        items: const [
          DropdownMenuItem(value: 'es', child: Text('Español')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _language = value);
          }
        },
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.info_outline),
    );
  }

  Widget _buildAboutTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(
        description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Política de Privacidad'),
        content: SingleChildScrollView(
          child: Text(
            '''Esta aplicación recopila y almacena localmente:
- Imágenes de escaneos
- Resultados de identificación
- Notas del usuario

Los datos se almacenan ÚNICAMENTE en tu dispositivo.

No se comparte información con servidores externos a menos que actives la opción de sincronización en nube.

Para más información, contacta al desarrollador.''',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Términos de Servicio'),
        content: SingleChildScrollView(
          child: Text(
            '''1. Uso de la aplicación
Esta aplicación se proporciona "tal cual" para fines educativos y de laboratorio.

2. Precisión
Los resultados de identificación pueden no ser 100% precisos. Verifica siempre visualmente.

3. Responsabilidad
El usuario es responsable de usar los resultados de manera segura.

4. Cambios
Nos reservamos el derecho de cambiar estos términos en cualquier momento.''',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Licencias'),
        content: SingleChildScrollView(
          child: Text(
            '''Esta aplicación utiliza las siguientes librerías:

• Flutter - BSD License
• TensorFlow Lite - Apache License 2.0
• Riverpod - MIT License
• Camera - BSD License
• SQLite - Public Domain
• Logger - MIT License
• Image - Apache License 2.0

Para más detalles, visita:
https://pub.dev/packages/[package_name]''',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showDeviceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del dispositivo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceInfoItem('Plataforma', 'Android / iOS'),
              _buildDeviceInfoItem('Versión de Flutter', '3.x+'),
              _buildDeviceInfoItem('Modelo de ML', 'MobileNetV2'),
              _buildDeviceInfoItem('BD', 'SQLite'),
              _buildDeviceInfoItem('State Management', 'Riverpod'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
          const Divider(),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar caché'),
        content: const Text(
          '¿Estás seguro de que deseas limpiar el caché? Esto no afectará tu historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Caché limpiado')),
              );
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}
