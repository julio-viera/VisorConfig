import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/controllers/editor_document_controller.dart';
import 'package:visor_config/themes/code_palette.dart';
import 'package:visor_config/widgets/graph/graph_view.dart';
import 'package:visor_config/models/config_format.dart';
import 'package:visor_config/models/launch_request.dart';
import 'package:visor_config/services/document_export_service.dart';
import 'package:visor_config/services/json_parser.dart';

void main() {
  const yaml = 'servers:\n  - name: web\n    enabled: true\n';
  const toml = '[[servers]]\nname = "web"\nenabled = true\n';
  final expected = {
    'servers': [
      {'name': 'web', 'enabled': true},
    ],
  };

  test('Detects extensions and content without overriding valid JSON', () {
    expect(ConfigFormat.fromPath('settings.YML'), ConfigFormat.yaml);
    expect(ConfigFormat.fromPath('settings.toml'), ConfigFormat.toml);
    expect(ConfigFormat.detect(yaml), ConfigFormat.yaml);
    expect(ConfigFormat.detect('{name: web}'), ConfigFormat.yaml);
    expect(ConfigFormat.detect(toml), ConfigFormat.toml);
    expect(ConfigFormat.detect('"database".port = 8080'), ConfigFormat.toml);
    expect(ConfigFormat.detect('[1 ]'), ConfigFormat.json);
    expect(ConfigFormat.detect('{"servers":[]}'), ConfigFormat.json);
    expect(ConfigFormat.detect('script: |\n  mode = 1'), ConfigFormat.yaml);
  });

  for (final (format, text) in [
    (ConfigFormat.yaml, yaml),
    (ConfigFormat.toml, toml),
  ]) {
    test(
      '$format provides shared structured nodes and cross-format exports',
      () async {
        final parsed = parseDocument({'text': text, 'format': format.name});
        expect(parsed.error, isNull);
        expect(parsed.value, expected);
        final name = parsed.byPath[r'$["servers"][0]["name"]']!;
        expect(
          text.substring(name.start, name.end).trim(),
          format == ConfigFormat.toml ? '"web"' : 'web',
        );
        for (final target in [
          ConfigFormat.json,
          ConfigFormat.yaml,
          ConfigFormat.toml,
        ]) {
          final bytes = await DocumentExportService().encode(
            parsed.value,
            parsed.nodes,
            target.name,
            nativeValue: parsed.nativeValue,
          );
          final exported = parseDocument({
            'text': utf8.decode(bytes),
            'format': target.name,
          });
          expect(exported.error, isNull);
          expect(exported.value, expected);
        }
      },
    );

    test('$format supports edits from a structured node', () async {
      final document = EditorDocumentController(
        'settings.${format.name}',
        text: text,
        path: 'settings.${format.name}',
      );
      addTearDown(document.dispose);
      await document.validate();
      final node = document.result!.byPath[r'$["servers"][0]["name"]']!;
      final edited = document.editedConfig(node, '"proxy"');
      final parsed = parseDocument({'text': edited, 'format': format.name});
      expect(parsed.byPath[r'$["servers"][0]["name"]']!.value, 'proxy');
    });
  }

  test('TOML round trip preserves native dates and rejects null', () async {
    final exporter = DocumentExportService();
    final result = parseDocument({
      'text': 'date = 2026-11-07',
      'format': 'toml',
    });
    expect(result.error, isNull);
    final bytes = await exporter.encode(
      result.value,
      result.nodes,
      'toml',
      nativeValue: result.nativeValue,
    );
    expect(utf8.decode(bytes), contains('= 2026-11-07'));
    await expectLater(
      exporter.encode({'key': null}, [], 'toml'),
      throwsFormatException,
    );
  });

  test('Rejects amplified YAML exports before serialization', () async {
    final scalar = 'a' * (256 * 1024);
    final aliases = List.filled(160, '*base').join(', ');
    final parsed = parseDocument({
      'format': 'yaml',
      'text': 'base: &base $scalar\nitems: [$aliases]',
    });
    expect(parsed.error, isNull);
    await expectLater(
      DocumentExportService().encode(parsed.value, [], 'json'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('32 MiB'),
        ),
      ),
    );
  });

  testWidgets(
    'YAML and TOML expose format and structured views in the workspace',
    (tester) async {
      await tester.pumpWidget(
        const VisorConfigApp(
          launch: LaunchResult(
            documents: [
              LaunchDocument(
                name: 'server.yaml',
                path: '/tmp/server.yaml',
                text: yaml,
              ),
              LaunchDocument(
                name: 'server.toml',
                path: '/tmp/server.toml',
                text: toml,
              ),
            ],
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      Future<void> checkViews(String format) async {
        expect(find.byTooltip('Document format: $format'), findsOneWidget);
        expect(find.textContaining('Valid $format'), findsOneWidget);
        final field = find.byKey(const Key('json-editor'));
        final context = tester.element(field);
        final spans = tester
            .widget<TextField>(field)
            .controller!
            .buildTextSpan(context: context, withComposing: false);
        final palette = CodePalette.of(context);
        expect(
          spans.children!.whereType<TextSpan>().any(
            (span) =>
                span.text?.trim() == 'enabled' &&
                span.style?.color == palette.key,
          ),
          isTrue,
        );
        for (final view in ['Tree', 'Diagram', 'Graph', 'Radial graph']) {
          await tester.tap(find.byTooltip(view));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (view != 'Tree') {
            expect(find.byType(GraphViewport), findsOneWidget);
          }
        }
        await tester.tap(find.byTooltip('Table'));
        await tester.pumpAndSettle();
        expect(find.text('"web"'), findsOneWidget);
        expect(find.text('true'), findsOneWidget);
      }

      await checkViews('TOML');
      await tester.tap(find.text('server.yaml'));
      await tester.pumpAndSettle();
      await checkViews('YAML');
    },
  );
}
