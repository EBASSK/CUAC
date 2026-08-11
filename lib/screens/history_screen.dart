import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/scan_history.dart';
import '../providers/providers.dart';

/// Pantalla que consulta y presenta los escaneos almacenados localmente.
///
/// Permite filtrar la colección, marcar favoritos, abrir el detalle, eliminar
/// registros y regresar a la cámara para iniciar una nueva captura.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    this.loadOnStart = true,
  });

  /// Permite omitir la carga automática en pruebas o usos controlados.
  final bool loadOnStart;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Clave del filtro visible: todos, favoritos, hoy o esta semana.
  String _filterType = 'all';

  /// Repite la consulta correspondiente al filtro que permanece seleccionado.
  Future<void> _loadActiveFilter() {
    final notifier = ref.read(historyNotifierProvider.notifier);
    switch (_filterType) {
      case 'favorites':
        return notifier.loadFavorites();
      case 'today':
        return notifier.loadTodayScans();
      case 'week':
        return notifier.loadWeekScans();
      case 'all':
      default:
        return notifier.loadHistory();
    }
  }

  /// Cambia la selección visible y carga inmediatamente su consulta.
  Future<void> _selectFilter(String filterType) async {
    setState(() => _filterType = filterType);
    await _loadActiveFilter();
  }

  /// Recarga el filtro tras modificar un favorito confirmado por SQLite.
  Future<void> _toggleFavorite(String scanId) async {
    final updated =
        await ref.read(historyNotifierProvider.notifier).toggleFavorite(scanId);
    if (!mounted) return;

    if (!updated) {
      _showOperationError('No se pudo actualizar el favorito.');
      return;
    }

    await _loadActiveFilter();
  }

  /// Abre el detalle y actualiza la consulta activa cuando el usuario regresa.
  Future<void> _openDetail(ScanHistory scan) async {
    await context.push('/detail/${scan.id}', extra: scan);
    if (!mounted) return;
    await _loadActiveFilter();
  }

  /// Confirma la eliminación y solo recarga cuando la base reporta éxito.
  Future<void> _confirmDelete(ScanHistory scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar?'),
        content: const Text('Esta acción no se puede deshacer'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleted =
        await ref.read(historyNotifierProvider.notifier).deleteScan(scan.id);
    if (!mounted) return;

    if (!deleted) {
      _showOperationError('No se pudo eliminar el escaneo.');
      return;
    }

    await _loadActiveFilter();
  }

  /// Muestra fallos de escritura sin presentar la operación como completada.
  void _showOperationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Regresa a la instancia de cámara que abrió el historial.
  Future<void> _startNewScan() async {
    // Normalmente CameraScreen abre el historial con `push`. Al retirar esta
    // ruta, la espera de navegación termina y esa misma pantalla puede reabrir
    // la cámara. Usar directamente `go('/camera')` dejaba la espera pendiente
    // en algunos dispositivos y mantenía la cámara en estado de carga.
    if (context.canPop()) {
      context.pop();
      return;
    }

    // Respaldo para el caso excepcional en que el historial se haya abierto
    // como ruta raíz o mediante un enlace profundo.
    await ref.read(cameraServiceProvider).dispose();
    if (mounted) {
      context.go('/camera');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.loadOnStart) {
      // La lectura se aplaza hasta el primer cuadro para no cambiar un provider
      // mientras Flutter todavía está construyendo el árbol inicial.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadActiveFilter());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod vuelve a construir la pantalla cuando cambia la consulta activa.
    final historyState = ref.watch(historyNotifierProvider);
    final palette = _HistoryPalette.from(Theme.of(context));

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(palette),
            Divider(
              height: 1,
              thickness: 1,
              indent: 20,
              endIndent: 20,
              color: palette.border,
            ),
            // Los filtros pertenecen a la estructura fija de la pantalla. No
            // deben desaparecer cuando una consulta carga, falla o queda vacía.
            _buildFilters(palette),
            Expanded(
              child: _buildHistoryContent(historyState, palette),
            ),
          ],
        ),
      ),
      // Este botón vuelve a la cámara sin crear una segunda instancia de ella.
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewScan,
        tooltip: 'Nuevo escaneo',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construye un encabezado compacto con navegación y actualización manual.
  Widget _buildHeader(_HistoryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 18),
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
            icon: Icon(Icons.arrow_back, color: palette.primaryText),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Historial',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_loadActiveFilter()),
            tooltip: 'Actualizar historial',
            icon: Icon(Icons.refresh_rounded, color: palette.secondaryText),
          ),
        ],
      ),
    );
  }

  /// Mantiene visibles las cuatro consultas disponibles en cualquier estado.
  Widget _buildFilters(_HistoryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar resultados',
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryFilterChip(
                key: const Key('historyFilterAll'),
                icon: Icons.grid_view_rounded,
                label: 'Todos',
                selected: _filterType == 'all',
                palette: palette,
                onSelected: () => unawaited(_selectFilter('all')),
              ),
              _HistoryFilterChip(
                key: const Key('historyFilterFavorites'),
                icon: Icons.favorite_outline_rounded,
                label: 'Favoritos',
                selected: _filterType == 'favorites',
                palette: palette,
                onSelected: () => unawaited(_selectFilter('favorites')),
              ),
              _HistoryFilterChip(
                key: const Key('historyFilterToday'),
                icon: Icons.today_outlined,
                label: 'Hoy',
                selected: _filterType == 'today',
                palette: palette,
                onSelected: () => unawaited(_selectFilter('today')),
              ),
              _HistoryFilterChip(
                key: const Key('historyFilterWeek'),
                icon: Icons.date_range_outlined,
                label: 'Esta semana',
                selected: _filterType == 'week',
                palette: palette,
                onSelected: () => unawaited(_selectFilter('week')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cambia únicamente el contenido inferior; la navegación y los filtros se
  /// conservan estables mientras Riverpod resuelve la consulta seleccionada.
  Widget _buildHistoryContent(
    HistoryState historyState,
    _HistoryPalette palette,
  ) {
    return historyState.when(
      idle: () => _HistoryMessage(
        icon: Icons.history_toggle_off_outlined,
        title: 'Historial listo',
        message: 'Actualiza para consultar tus identificaciones guardadas.',
        palette: palette,
        actionLabel: 'Actualizar',
        onAction: () => unawaited(_loadActiveFilter()),
      ),
      loading: () => _HistoryLoading(palette: palette),
      success: (scans) {
        if (scans.isEmpty) {
          return _buildEmptyState(palette);
        }

        return RefreshIndicator(
          onRefresh: _loadActiveFilter,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 104),
            itemCount: scans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scan = scans[index];
              return _HistoryCard(
                scan: scan,
                palette: palette,
                onTap: () => unawaited(_openDetail(scan)),
                onToggleFavorite: () => unawaited(_toggleFavorite(scan.id)),
                onDelete: () => unawaited(_confirmDelete(scan)),
              );
            },
          ),
        );
      },
      error: (message) => _HistoryMessage(
        icon: Icons.sync_problem_outlined,
        title: 'No se pudo cargar el historial',
        message: message,
        palette: palette,
        isError: true,
        actionLabel: 'Reintentar',
        onAction: () => unawaited(_loadActiveFilter()),
      ),
    );
  }

  /// Personaliza el mensaje vacío según el filtro que produjo la lista.
  Widget _buildEmptyState(_HistoryPalette palette) {
    final (title, message) = switch (_filterType) {
      'favorites' => (
          'Aún no tienes favoritos',
          'Marca el corazón de una identificación para encontrarla aquí.',
        ),
      'today' => (
          'No hay escaneos de hoy',
          'Las nuevas identificaciones que realices hoy aparecerán aquí.',
        ),
      'week' => (
          'No hay escaneos esta semana',
          'Prueba otro periodo o inicia una nueva identificación.',
        ),
      _ => (
          'Tu historial está vacío',
          'Los instrumentos identificados aparecerán aquí automáticamente.',
        ),
    };

    return _HistoryMessage(
      icon: Icons.inventory_2_outlined,
      title: title,
      message: message,
      palette: palette,
      actionLabel: _filterType == 'all' ? null : 'Ver todos',
      onAction:
          _filterType == 'all' ? null : () => unawaited(_selectFilter('all')),
    );
  }
}

/// Colores derivados del tema activo para evitar fijar el historial a un modo.
class _HistoryPalette {
  const _HistoryPalette({
    required this.background,
    required this.panel,
    required this.iconBackground,
    required this.border,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.error,
  });

  factory _HistoryPalette.from(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _HistoryPalette(
      background: theme.scaffoldBackgroundColor,
      panel: scheme.surface,
      iconBackground: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.16 : 0.09),
        scheme.surface,
      ),
      border: scheme.outline.withValues(alpha: isDark ? 0.32 : 0.18),
      accent: scheme.primary,
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      error: scheme.error,
    );
  }

  final Color background;
  final Color panel;
  final Color iconBackground;
  final Color border;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color error;
}

/// Filtro Material con icono y selección legible en tema claro u oscuro.
class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final _HistoryPalette palette;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? palette.accent : palette.secondaryText,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? palette.primaryText : palette.secondaryText,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: palette.panel,
      selectedColor: palette.iconBackground,
      side: BorderSide(
        color: selected ? palette.accent : palette.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onSelected: (_) => onSelected(),
    );
  }
}

/// Tarjeta de un escaneo con acciones explícitas de favorito y eliminación.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.scan,
    required this.palette,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final ScanHistory scan;
  final _HistoryPalette palette;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Se conserva el gesto histórico y el menú lo hace más descubrible.
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.science_outlined,
                  color: palette.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.predictedInstrument,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${scan.getFormattedDate()} · '
                      '${scan.getConfidencePercent()}% de confianza',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                tooltip: scan.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                icon: Icon(
                  scan.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color:
                      scan.isFavorite ? palette.error : palette.secondaryText,
                ),
              ),
              PopupMenuButton<_HistoryAction>(
                tooltip: 'Más opciones',
                color: palette.panel,
                icon: Icon(Icons.more_vert, color: palette.secondaryText),
                onSelected: (action) {
                  if (action == _HistoryAction.delete) onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HistoryAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: palette.error),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: palette.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryAction { delete }

/// Estado de carga pequeño que no desplaza los filtros de su posición.
class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading({required this.palette});

  final _HistoryPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: palette.accent),
          const SizedBox(height: 18),
          Text(
            'Cargando historial…',
            style: TextStyle(color: palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// Mensaje reutilizable para estados inicial, vacío y de error.
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.palette,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final _HistoryPalette palette;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final iconColor = isError ? palette.error : palette.accent;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        iconColor.withValues(alpha: 0.12),
                        palette.panel,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 29),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(
                        actionLabel == 'Actualizar' ||
                                actionLabel == 'Reintentar'
                            ? Icons.refresh_rounded
                            : Icons.grid_view_rounded,
                      ),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
