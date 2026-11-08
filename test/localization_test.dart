import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/app_info.dart';
import 'package:visor_config/l10n/app_strings.dart';
import 'package:visor_config/l10n/messages.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/widgets/dialogs/about_dialog.dart';

void main() {
  test('Every UI message has translations for all four new languages', () {
    final pattern = RegExp(
      r"""tr\(\s*'(?:\\.|[^'\\])*'\s*,\s*'((?:\\.|[^'\\])*)'\s*,?\s*\)""",
    );
    final keys = <String>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') && !f.path.endsWith('messages.dart'),
            )) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        keys.add(match.group(1)!.replaceAll(r'\$', r'$'));
      }
    }
    expect(keys.length, greaterThan(80));
    for (final language in ['fr', 'pt', 'de', 'it']) {
      for (final key in keys) {
        expect(
          translatedMessages[key]?[language],
          isNotEmpty,
          reason: '$language: $key',
        );
      }
      expect(AppSettings.fromJson({'language': language}).language, language);
      expect(appDescriptionFor(language), isNot(appDescriptionFor('en')));
    }
    expect(resolveLanguage('system', 'pt'), 'pt');
    expect(resolveLanguage('system', 'ja'), 'en');
  });
  for (final language in ['fr', 'pt', 'de', 'it']) {
    testWidgets('$language controls and Material locale are localized', (
      tester,
    ) async {
      await tester.pumpWidget(
        VisorConfigApp(initialSettings: AppSettings(language: language)),
      );
      await tester.pumpAndSettle();
      final strings = AppStrings(language);
      expect(
        find.byTooltip(strings.tr('Configuración', 'Settings')),
        findsOneWidget,
      );
      expect(find.byTooltip(strings.tr('Texto', 'Raw')), findsOneWidget);
      expect(
        Localizations.localeOf(
          tester.element(find.byKey(const Key('json-editor'))),
        ).languageCode,
        language,
      );
      await tester.tap(find.byTooltip(strings.tr('Acerca de', 'About')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-about-dialog')), findsOneWidget);
      expect(find.text(appDescriptionFor(language)), findsOneWidget);
      expect(find.text(appAuthor), findsOneWidget);
      expect(find.text(appLicenseName), findsOneWidget);
    });
  }
  testWidgets('About opens the canonical license, repository and issues URLs', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAboutDialog(
            language: 'es',
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    for (final label in [
      appLicenseName,
      appRepositoryUrl.replaceFirst('https://', ''),
      appIssuesUrl.replaceFirst('https://', ''),
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(opened.map((uri) => uri.toString()), [
      appLicenseUrl,
      appRepositoryUrl,
      appIssuesUrl,
    ]);
  });
}
