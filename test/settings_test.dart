import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/repositories/settings_repository.dart';
import 'package:visor_config/screens/workspace_screen.dart';
import 'package:visor_config/themes/code_palette.dart';

void main() {
  test(
    'Settings survive restart, including the latest queued change',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'visor-settings-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = SettingsRepository(directory: directory);
      expect((await store.load()).theme, ThemeMode.system);
      final writes = [
        store.save(
          const AppSettings(theme: ThemeMode.light, colorTheme: 'ocean'),
        ),
        store.save(
          const AppSettings(
            theme: ThemeMode.dark,
            language: 'es',
            fontSize: 18,
            colorTheme: 'amethyst',
          ),
        ),
      ];
      await Future.wait(writes);
      final restored = await SettingsRepository(directory: directory).load();
      expect(restored.theme, ThemeMode.dark);
      expect(restored.language, 'es');
      expect(restored.fontSize, 18);
      expect(restored.colorTheme, 'amethyst');
      expect(
        directory.listSync().whereType<File>().map(
          (f) => f.path.split('/').last,
        ),
        ['settings.json'],
      );
    },
  );
  test(
    'Invalid or incomplete configuration falls back to safe defaults',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'visor-invalid-settings-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = SettingsRepository(directory: directory);
      final file = await store.settingsFile;
      await file.writeAsString('broken json');
      expect((await store.load()).colorTheme, 'jade');
      await file.writeAsString(
        '{"theme":"unknown","language":3,"fontSize":99,"colorTheme":"missing"}',
      );
      final settings = await store.load();
      expect(settings.theme, ThemeMode.system);
      expect(settings.language, 'system');
      expect(settings.fontSize, 22);
      expect(settings.colorTheme, 'jade');
    },
  );
  testWidgets(
    'Color choice is saved and restored, app identity is below editor',
    (tester) async {
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('visor-settings-ui-'),
      );
      final store = SettingsRepository(directory: directory);
      await tester.pumpWidget(VisorConfigApp(settingsStore: store));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('json-editor')))
            .style!
            .fontSize,
        16,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('app-identity'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('json-editor'))).dy),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('color-theme-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocean').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final workspace = tester.widget<WorkspaceScreen>(
        find.byType(WorkspaceScreen),
      );
      workspace.onSettings(ThemeMode.dark, 'en', 18);
      await tester.pumpAndSettle();
      var flushed = false;
      store.flush().then((_) => flushed = true);
      for (var i = 0; i < 30 && !flushed; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
      }
      expect(flushed, isTrue);
      final saved = await tester.runAsync(
        () => SettingsRepository(directory: directory).load(),
      );
      expect(saved!.colorTheme, 'ocean');
      expect(saved.theme, ThemeMode.dark);
      expect(saved.fontSize, 18);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        VisorConfigApp(initialSettings: saved, settingsStore: store),
      );
      await tester.pumpAndSettle();
      final editorContext = tester.element(
        find.byKey(const Key('json-editor')),
      );
      expect(Theme.of(editorContext).brightness, Brightness.dark);
      expect(CodePalette.of(editorContext).variant, 'ocean');
      expect(
        tester.widget<WorkspaceScreen>(find.byType(WorkspaceScreen)).fontSize,
        18,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => directory!.delete(recursive: true));
    },
  );
}
