import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab_instrument_identifier/config/theme.dart';
import 'package:lab_instrument_identifier/main.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/providers/theme_provider.dart';
import 'package:lab_instrument_identifier/screens/settings_screen.dart';
import 'package:lab_instrument_identifier/services/theme_preferences_service.dart';

void main() {
  group('serialización del tema', () {
    test('conserva los tres modos admitidos', () {
      for (final mode in ThemeMode.values) {
        final encoded = themeModeToStorage(mode);
        expect(themeModeFromStorage(encoded), mode);
      }
    });

    test('un valor desconocido vuelve al modo del sistema', () {
      expect(themeModeFromStorage('sepia'), ThemeMode.system);
      expect(themeModeFromStorage(null), ThemeMode.system);
    });
  });

  group('ThemeModeController', () {
    test('actualiza y persiste la selección', () async {
      final store = _MemoryThemeStore();
      final controller = ThemeModeController(store);
      addTearDown(controller.dispose);

      await controller.setThemeMode(ThemeMode.dark);

      expect(controller.state, ThemeMode.dark);
      expect(store.savedModes, [ThemeMode.dark]);
    });

    test('recupera el tema anterior cuando la escritura falla', () async {
      final store = _MemoryThemeStore(failOnSave: true);
      final controller = ThemeModeController(
        store,
        initialMode: ThemeMode.light,
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.setThemeMode(ThemeMode.dark),
        throwsA(isA<StateError>()),
      );

      expect(controller.state, ThemeMode.light);
    });
  });

  testWidgets('cambiar de tema conserva la misma instancia de GoRouter',
      (tester) async {
    final initialization = Completer<void>();
    final store = _MemoryThemeStore();
    final container = ProviderContainer(
      overrides: [
        themePreferencesStoreProvider.overrideWithValue(store),
        initialThemeModeProvider.overrideWithValue(ThemeMode.light),
        initializationProvider.overrideWith(
          (ref) => initialization.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
    await tester.pump();

    final appBefore = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final routerBefore = appBefore.routerConfig;
    expect(appBefore.themeMode, ThemeMode.light);

    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pump();

    final appAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appAfter.themeMode, ThemeMode.dark);
    expect(identical(appAfter.routerConfig, routerBefore), isTrue);
    expect(find.byKey(const Key('splashLogo')), findsOneWidget);
  });

  testWidgets('Ajustes refleja y permite cambiar la apariencia',
      (tester) async {
    final store = _MemoryThemeStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferencesStoreProvider.overrideWithValue(store),
          initialThemeModeProvider.overrideWithValue(ThemeMode.system),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Tema sistema'), findsOneWidget);
    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(find.text('Tema oscuro'), findsOneWidget);
    expect(store.savedModes, [ThemeMode.dark]);
  });
}

/// Almacenamiento predecible para probar el controlador sin usar plugins.
class _MemoryThemeStore implements ThemePreferencesStore {
  _MemoryThemeStore({
    this.failOnSave = false,
  });

  final bool failOnSave;
  final List<ThemeMode> savedModes = [];

  @override
  Future<ThemeMode> loadThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    if (failOnSave) {
      throw StateError('almacenamiento no disponible');
    }
    savedModes.add(mode);
  }
}
