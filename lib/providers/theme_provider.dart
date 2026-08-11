import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_preferences_service.dart';

/// Expone el almacenamiento de preferencias para permitir su reemplazo en test.
final themePreferencesStoreProvider = Provider<ThemePreferencesStore>((ref) {
  return ThemePreferencesService();
});

/// Valor que se aplica desde el primer frame de la aplicación.
///
/// `main` lo reemplaza con la preferencia leída antes de construir la interfaz,
/// evitando que el usuario vea un destello del tema equivocado al iniciar.
final initialThemeModeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.system;
});

/// Coordina el tema visible y su persistencia local.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(
    this._store, {
    ThemeMode initialMode = ThemeMode.system,
  }) : super(initialMode);

  final ThemePreferencesStore _store;
  int _changeRevision = 0;

  /// Cambia la apariencia inmediatamente y la guarda para el siguiente inicio.
  ///
  /// Si la escritura falla, recupera el modo anterior siempre que no exista una
  /// selección más reciente. El error se propaga para que la UI pueda avisarlo.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;

    final previousMode = state;
    final revision = ++_changeRevision;
    state = mode;

    try {
      await _store.saveThemeMode(mode);
    } on Object {
      if (mounted && revision == _changeRevision) {
        state = previousMode;
      }
      rethrow;
    }
  }
}

/// Preferencia observable que reconstruye [MaterialApp] al cambiar de modo.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(
    ref.watch(themePreferencesStoreProvider),
    initialMode: ref.watch(initialThemeModeProvider),
  );
});
