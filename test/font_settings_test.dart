import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/controllers/settings_controller.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/models/font_preferences.dart';
import 'package:visor_config/repositories/settings_repository.dart';
import 'package:visor_config/services/system_font_service.dart';
import 'package:visor_config/themes/app_theme.dart';
import 'package:visor_config/themes/app_typography.dart';
import 'package:visor_config/widgets/font_settings.dart';

class FakeFontService extends SystemFontService {
  final loaded = <String>[];
  @override
  Future<List<String>> families() async => ['Example Mono', 'Example Sans'];
  @override
  Future<bool> load(String family) async {
    loaded.add(family);
    return family != 'Missing';
  }
}

void main() {
  test('Old and malformed preferences retain default typography', () {
    for (final data in [
      {},
      {'font': 'invalid'},
      {
        'font': {'family': 4, 'style': 'unknown'},
      },
    ]) {
      final font = AppSettings.fromJson(Map<String, dynamic>.from(data)).font;
      expect(font.family, isEmpty);
      expect(font.style, TypefaceStyle.regular);
    }
  });

  test('Font and style survive other preference changes and restart', () async {
    final directory = await Directory.systemTemp.createTemp('visor-fonts-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = SettingsRepository(directory: directory);
    final service = FakeFontService();
    final controller = SettingsController(
      initial: const AppSettings(),
      store: repository,
      fontService: service,
    );
    addTearDown(controller.dispose);
    expect(
      await controller.updateFont(
        const FontPreferences(
          family: 'Example Mono',
          style: TypefaceStyle.boldItalic,
        ),
      ),
      isTrue,
    );
    controller.update(ThemeMode.dark, 'es', 18);
    await controller.flush();
    final restored = await repository.load();
    expect(restored.font.family, 'Example Mono');
    expect(restored.font.style, TypefaceStyle.boldItalic);
    expect(restored.fontSize, 18);
    expect(
      await controller.updateFont(const FontPreferences(family: 'Missing')),
      isFalse,
    );
    expect(controller.font.family, 'Example Mono');
    expect((await repository.load()).font.family, 'Example Mono');
    expect(service.loaded, ['Example Mono', 'Missing']);
  });

  testWidgets('Searchable system fonts and style selection update preview', (
    tester,
  ) async {
    final changes = <FontPreferences>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FontSettings(
              value: const FontPreferences(),
              language: 'en',
              service: FakeFontService(),
              onChanged: (value) async {
                changes.add(value);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example Mono').last);
    await tester.pumpAndSettle();
    expect(changes.last.family, 'Example Mono');
    await tester.tap(find.byType(DropdownButtonFormField<TypefaceStyle>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bold italic').last);
    await tester.pumpAndSettle();
    final preview = tester.widget<Text>(find.byKey(const Key('font-preview')));
    expect(preview.style!.fontFamily, 'VisorSystem:Example Mono');
    expect(preview.style!.fontWeight, FontWeight.bold);
    expect(preview.style!.fontStyle, FontStyle.italic);
  });

  testWidgets('Theme propagates selected typography to code and interface', (
    tester,
  ) async {
    const font = FontPreferences(
      family: 'Example Mono',
      style: TypefaceStyle.italic,
    );
    TextStyle? code;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light, 'jade', font),
        home: Builder(
          builder: (context) {
            code = AppTypography.codeStyle(context);
            return const Text('sample');
          },
        ),
      ),
    );
    expect(code!.fontFamily, font.loadedFamily);
    expect(code!.fontStyle, FontStyle.italic);
    final theme = Theme.of(tester.element(find.text('sample')));
    expect(theme.textTheme.bodyMedium!.fontFamily, font.loadedFamily);
    expect(theme.textTheme.bodyMedium!.fontStyle, FontStyle.italic);
  });
}
