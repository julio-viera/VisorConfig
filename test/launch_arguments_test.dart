import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/models/launch_request.dart';
import 'package:visor_config/services/launch_arguments.dart';

void main() {
  test('Parses options without splitting JSON or treating literal values as options', () {
    final plan = LaunchPlan.parse([
      '--json',
      '{"a":"some text"}',
      '--file',
      'file with spaces.txt',
      '--',
      '--help',
    ]);
    expect(plan.inputs.map((i) => i.value), [
      '{"a":"some text"}',
      'file with spaces.txt',
      '--help',
    ]);
    expect(plan.inputs[0].kind, LaunchInputKind.text);
    expect(plan.inputs[1].kind, LaunchInputKind.file);
    expect(plan.action, LaunchAction.open);
    expect(LaunchPlan.parse(['--help']).action, LaunchAction.help);
    expect(LaunchPlan.parse(['--version']).action, LaunchAction.version);
    expect(() => LaunchPlan.parse(['--file']), throwsFormatException);
    expect(() => LaunchPlan.parse(['--unknown']), throwsFormatException);
  });
  test(
    'Loads JSON, TXT, relative paths and percent-encoded file URIs in order',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'visor-arguments-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final json = File('${directory.path}/un ejemplo ñ #1.json');
      final txt = File('${directory.path}/documento.txt');
      await json.writeAsString('{"name":"Julio"}');
      await txt.writeAsString('[1,2,3]');
      final loaded = await loadLaunchDocuments(
        LaunchPlan.parse([
          'un ejemplo ñ #1.json',
          txt.path,
          json.uri.toString(),
          '{"raw":true}',
        ]),
        currentDirectory: directory.path,
      );
      expect(loaded.issues, isEmpty);
      expect(loaded.documents.map((d) => d.text), [
        '{"name":"Julio"}',
        '[1,2,3]',
        '{"name":"Julio"}',
        '{"raw":true}',
      ]);
      expect(loaded.documents.first.name, 'un ejemplo ñ #1.json');
      expect(loaded.documents.first.path, json.path);
      expect(loaded.documents.first.unsaved, isFalse);
      expect(loaded.documents.last.unsaved, isTrue);
      final forced = await loadLaunchDocuments(
        LaunchPlan.parse(['--json', txt.path]),
      );
      expect(forced.documents.single.text, txt.path);
      expect(forced.documents.single.path, isNull);
    },
  );
  test('Keeps malformed and long JSON text, reports missing paths, and never evaluates a shell', () async {
    final directory = await Directory.systemTemp.createTemp('visor-cli-text-');
    addTearDown(() => directory.delete(recursive: true));
    final marker = File('${directory.path}/must-not-exist');
    final json = jsonEncode({
      'payload': '\$(touch ${marker.path})',
      'long': 'x' * 20000,
    });
    final loaded = await loadLaunchDocuments(
      LaunchPlan.parse([
        'missing.json',
        directory.path,
        json,
        '{broken/json',
        'texto con algun json',
        '--file',
        'no-extension',
      ]),
      currentDirectory: directory.path,
    );
    expect(loaded.issues, hasLength(3));
    expect(loaded.documents.map((d) => d.text), [
      json,
      '{broken/json',
      'texto con algun json',
    ]);
    expect(await marker.exists(), isFalse);
  });
  testWidgets(
    'External documents initialize tabs and raw input remains unsaved',
    (tester) async {
      await tester.pumpWidget(
        const VisorConfigApp(
          launch: LaunchResult(
            documents: [
              LaunchDocument(
                name: 'file.txt',
                path: '/tmp/visor-external-test.txt',
                text: '{"file":1}',
              ),
              LaunchDocument(text: '{"console":2}'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('json-editor')))
            .controller!
            .text,
        '{"console":2}',
      );
      expect(find.text('● Untitled 1'), findsOneWidget);
      await tester.tap(find.text('file.txt'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('json-editor')))
            .controller!
            .text,
        '{"file":1}',
      );
      expect(find.text('● file.txt'), findsNothing);
    },
  );
  testWidgets(
    'Live file opens append tabs and refocus without replacing edits',
    (tester) async {
      final requests = StreamController<LaunchResult>();
      addTearDown(requests.close);
      const first = LaunchDocument(
        name: 'first.json',
        path: '/tmp/visor-live-first.json',
        text: '{"first":1}',
      );
      const second = LaunchDocument(
        name: 'second.json',
        path: '/tmp/visor-live-second.json',
        text: '{"second":2}',
      );
      await tester.pumpWidget(
        VisorConfigApp(
          launch: const LaunchResult(documents: [first, first]),
          externalLaunches: requests.stream,
        ),
      );
      await tester.pumpAndSettle();

      final editor = find.byKey(const Key('json-editor'));
      String contents() => tester.widget<TextField>(editor).controller!.text;
      int? tabCount() => tester
          .widget<ListView>(find.byKey(const Key('document-tabs')))
          .childrenDelegate
          .estimatedChildCount;
      expect(tabCount(), 1);
      await tester.enterText(editor, '{"edited":true}');
      requests.add(const LaunchResult(documents: [second]));
      for (var i = 0; i < 8 && tabCount() == 1; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
      }
      await tester.pumpAndSettle();
      expect(contents(), second.text);
      expect(tabCount(), 2);

      requests.add(
        const LaunchResult(
          documents: [
            LaunchDocument(
              text: '',
              path: '/tmp/visor-live-first.json',
              deferred: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(contents(), '{"edited":true}');
      expect(tabCount(), 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'A missing launch file shows an error and leaves a usable empty tab',
    (tester) async {
      await tester.pumpWidget(
        const VisorConfigApp(
          launch: LaunchResult(
            issues: [LaunchIssue('missing.txt', 'File not found')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open: missing.txt'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-editor')), findsOneWidget);
    },
  );
}
