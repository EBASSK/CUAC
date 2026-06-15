import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filterType = 'all'; // all, favorites, today, week

  @override
  void initState() {
    super.initState();
    // Cargar historial al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyNotifierProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.read(historyNotifierProvider.notifier).loadHistory();
            },
          ),
        ],
      ),
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
              // FilterChips
              Padding(
                padding: EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Todos'),
                      selected: _filterType == 'all',
                      onSelected: (selected) {
                        setState(() => _filterType = 'all');
                        ref.read(historyNotifierProvider.notifier).loadHistory();
                      },
                    ),
                    FilterChip(
                      label: Text('Favoritos'),
                      selected: _filterType == 'favorites',
                      onSelected: (selected) {
                        setState(() => _filterType = 'favorites');
                        ref.read(historyNotifierProvider.notifier).loadFavorites();
                      },
                    ),
                    FilterChip(
                      label: Text('Hoy'),
                      selected: _filterType == 'today',
                      onSelected: (selected) {
                        setState(() => _filterType = 'today');
                        ref.read(historyNotifierProvider.notifier).loadTodayScans();
                      },
                    ),
                    FilterChip(
                      label: Text('Esta semana'),
                      selected: _filterType == 'week',
                      onSelected: (selected) {
                        setState(() => _filterType = 'week');
                        ref.read(historyNotifierProvider.notifier).loadWeekScans();
                      },
                    ),
                  ],
                ),
              ),
              
              // Lista de escaneos
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
                        onPressed: () {
                          ref.read(historyNotifierProvider.notifier)
                              .toggleFavorite(scan.id);
                        },
                      ),
                      onTap: () {
                        context.push('/detail/${scan.id}', extra: scan);
                      },
                      onLongPress: () {
                        // Eliminar con confirmación
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('¿Eliminar?'),
                            content: Text('Esta acción no se puede deshacer'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref.read(historyNotifierProvider.notifier)
                                      .deleteScan(scan.id);
                                  Navigator.pop(context);
                                },
                                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/camera'),
        child: Icon(Icons.add),
      ),
    );
  }
}