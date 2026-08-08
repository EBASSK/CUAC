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

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => unawaited(_loadActiveFilter()),
          ),
        ],
      ),
      // Cada rama representa el estado asíncrono de acceso a la base de datos.
      body: historyState.when(
        idle: () => Center(child: Text('Presiona refresh')),
        loading: () => Center(child: CircularProgressIndicator()),
        success: (scans) {
          if (scans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay escaneos',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Los filtros solicitan al notifier una consulta especializada.
              Padding(
                padding: EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Todos'),
                      selected: _filterType == 'all',
                      onSelected: (_) => unawaited(_selectFilter('all')),
                    ),
                    FilterChip(
                      label: Text('Favoritos'),
                      selected: _filterType == 'favorites',
                      onSelected: (_) => unawaited(
                        _selectFilter('favorites'),
                      ),
                    ),
                    FilterChip(
                      label: Text('Hoy'),
                      selected: _filterType == 'today',
                      onSelected: (_) => unawaited(_selectFilter('today')),
                    ),
                    FilterChip(
                      label: Text('Esta semana'),
                      selected: _filterType == 'week',
                      onSelected: (_) => unawaited(_selectFilter('week')),
                    ),
                  ],
                ),
              ),

              // Lista desplazable de escaneos obtenidos por el filtro activo.
              Expanded(
                child: ListView.builder(
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    return ListTile(
                      title: Text(scan.predictedInstrument),
                      subtitle: Text(scan.getFormattedDate()),
                      trailing: IconButton(
                        icon: Icon(
                          scan.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        onPressed: () => unawaited(
                          _toggleFavorite(scan.id),
                        ),
                      ),
                      onTap: () => unawaited(_openDetail(scan)),
                      onLongPress: () => unawaited(_confirmDelete(scan)),
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 16),
              Text(message),
            ],
          ),
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
}
