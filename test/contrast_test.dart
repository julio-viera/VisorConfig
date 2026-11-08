import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/controllers/json_editor_controller.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/screens/workspace_screen.dart';
import 'package:visor_config/themes/code_palette.dart';
import 'package:visor_config/widgets/editor/raw_editor.dart';

import 'dart:math' as math;

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('Every color theme preserves source and active tab text contrast', () {
    for (final name in colorThemes) {
      for (final dark in [false, true]) {
        final palette = CodePalette(dark, variant: name);
        for (final color in [
          palette.text,
          palette.key,
          palette.string,
          palette.number,
          palette.literal,
        ]) {
          expect(
            contrast(color, palette.background),
            greaterThanOrEqualTo(4.5),
            reason: '$name dark=$dark',
          );
        }
        expect(
          contrast(Colors.white, palette.selectedTab),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
  for (final dark in [false, true]) {
    final palette = CodePalette(dark);
    final label = dark ? 'dark' : 'light';
    test(
      '$label source colors meet text contrast on editor and diff backgrounds',
      () {
        for (final color in [
          palette.text,
          palette.muted,
          palette.key,
          palette.string,
          palette.number,
          palette.literal,
        ]) {
          expect(
            contrast(color, palette.background),
            greaterThanOrEqualTo(4.5),
          );
        }
        for (final background
            in dark
                ? [const Color(0xff572a30), const Color(0xff1c4936)]
                : [const Color(0xffffe4e6), const Color(0xffdcfce7)]) {
          expect(contrast(palette.text, background), greaterThanOrEqualTo(4.5));
          expect(
            contrast(palette.muted, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(palette.error, palette.errorBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(Colors.white, palette.selectedTab),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(palette.selectedTab, palette.inactiveTab),
          greaterThan(2),
        );
      },
    );
    testWidgets(
      '$label highlights parse errors in status and gutter, and clears on correction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: WorkspaceScreen(
              language: 'en',
              fontSize: 14,
              theme: ThemeMode.system,
              onSettings: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('json-editor')),
          '{\n "bad":,\n}',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        final status = tester.widget<Text>(
          find.byKey(const Key('parse-status')),
        );
        expect(status.style!.color, palette.error);
        expect(status.data, contains('Line 2'));
        var painter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('json-line-numbers')),
                    )
                    .painter!
                as LineNumbersPainter;
        expect(painter.errorLine, 2);
        expect(painter.errorColor, palette.error);
        await tester.enterText(
          find.byKey(const Key('json-editor')),
          '{\n "good": 1\n}',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        painter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('json-line-numbers')),
                    )
                    .painter!
                as LineNumbersPainter;
        expect(painter.errorLine, isNull);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('parse-status')))
              .style!
              .color,
          palette.text,
        );
        await tester.tap(find.byTooltip('New · Ctrl+N'));
        await tester.pumpAndSettle();
        final inactive = tester.widget<Container>(
          find.byKey(const ValueKey('document-tab-0')),
        );
        final selectedFinder = find.byKey(const ValueKey('document-tab-1'));
        final selected = tester.widget<Container>(selectedFinder);
        final scheme = Theme.of(tester.element(selectedFinder)).colorScheme;
        expect(selected.color, scheme.surfaceContainerLow);
        expect(inactive.color, palette.inactiveTab);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$label syntax uses separate high contrast key, string, number and literal colors',
      (tester) async {
        final controller = JsonEditorController(
          text: '{"name":"Julio","n":2,"ok":true}',
        );
        addTearDown(controller.dispose);
        TextSpan? span;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Builder(
              builder: (context) {
                span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(fontSize: 14),
                  withComposing: false,
                );
                return Text.rich(span!);
              },
            ),
          ),
        );
        final tokens = span!.children!.cast<TextSpan>();
        expect(
          tokens.firstWhere((s) => s.text == '"name"').style!.color,
          palette.key,
        );
        expect(
          tokens.firstWhere((s) => s.text == '"Julio"').style!.color,
          palette.string,
        );
        expect(
          tokens.firstWhere((s) => s.text == '2').style!.color,
          palette.number,
        );
        expect(
          tokens.firstWhere((s) => s.text == 'true').style!.color,
          palette.literal,
        );
        expect(span!.style!.color, palette.text);
      },
    );
  }
}
