import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/widgets/graph/graph_view.dart';

void main() {
  testWidgets('Edits JSON, switches views and preserves independent tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const VisorConfigApp());
    await tester.pumpAndSettle();
    expect(find.text('Visor Config'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('json-editor')),
      '{"name":"Julio","items":[1,2]}',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tree'));
    await tester.pumpAndSettle();
    expect(find.text('name   "Julio"'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('json-editor')))
          .controller!
          .text,
      '{\n  \n}',
    );
    final editor = tester.widget<TextField>(
      find.byKey(const Key('json-editor')),
    );
    expect(editor.controller!.selection.baseOffset, 4);
    expect(editor.focusNode!.hasFocus, isTrue);
    expect(find.text('Untitled 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(editor.controller!.text, '{\n    \n}');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(editor.controller!.text, '{\n    \n    \n}');

    await tester.enterText(find.byKey(const Key('json-editor')), '  ');
    editor.controller!.selection = const TextSelection.collapsed(offset: 2);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  {',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(editor.controller!.text, '  {}');
    expect(editor.controller!.selection.baseOffset, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(editor.controller!.text, '  {\n    \n  }');
    expect(editor.controller!.selection.baseOffset, 8);

    await tester.tap(find.text('● Untitled 1'));
    await tester.pumpAndSettle();
    expect(find.text('name   "Julio"'), findsOneWidget);
    await tester.tap(find.byTooltip('Raw'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('json-editor')))
          .controller!
          .text,
      contains('Julio'),
    );
  });
  testWidgets('Enter uses tabs even after a line indented with spaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VisorConfigApp(initialSettings: AppSettings(indentWithTabs: true)),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('json-editor'));
    await tester.enterText(field, '{\n  "key": {}\n}');
    final editor = tester.widget<TextField>(field).controller!;
    editor.selection = TextSelection.collapsed(
      offset: editor.text.indexOf('{}') + 1,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(editor.text, '{\n  "key": {\n\t\t\n  }\n}');
  });

  testWidgets('YAML uses spaces for Tab and Enter in tab mode', (tester) async {
    await tester.pumpWidget(
      const VisorConfigApp(initialSettings: AppSettings(indentWithTabs: true)),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('json-editor'));
    await tester.enterText(field, 'parent:\n  child:');
    final editor = tester.widget<TextField>(field).controller!;
    editor.selection = TextSelection.collapsed(offset: editor.text.length);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(editor.text, 'parent:\n  child:\n    ');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(editor.text, 'parent:\n  child:\n      ');
  });

  testWidgets('A tab at the end of a line has only one marker region', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VisorConfigApp(
        initialSettings: AppSettings(
          indentWithTabs: true,
          showWhitespace: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('json-editor'));
    await tester.enterText(field, '{\n\t"key": 9,\n}');
    final controller = tester.widget<TextField>(field).controller!;
    final offset = controller.text.indexOf(',') + 1;
    controller.selection = TextSelection.collapsed(offset: offset);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, '{\n\t"key": 9,\n\t\n}');
    final editable = tester
        .state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        )
        .renderEditable;
    expect(
      editable.getBoxesForSelection(
        TextSelection(baseOffset: offset + 1, extentOffset: offset + 2),
      ),
      hasLength(1),
    );
  });

  testWidgets('Compact workspace has drawer and no overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VisorConfigApp());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Edits a table cell and renders the graph with search', (
    tester,
  ) async {
    await tester.pumpWidget(const VisorConfigApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('json-editor')),
      '[{"name":"Julio","age":30}]',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('"Julio"'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '"Ana"',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('"Ana"'), findsOneWidget);
    await tester.tap(find.byTooltip('Graph'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
    await tester.tap(find.byTooltip('Diagram'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();
    final diagram = tester
        .widget<GraphViewport>(find.byType(GraphViewport))
        .layout;
    expect(diagram.diagram, isTrue);
    expect(diagram.svg(), contains('name: string'));
    await tester.tap(find.byTooltip('Radial graph'));
    await tester.pumpAndSettle();
    final radial = tester.widget<GraphViewport>(find.byType(GraphViewport));
    expect(radial.layout.radial, isTrue);
    expect(radial.layout.svg(), contains('<circle'));
    expect(radial.layout.svg(), contains('marker-end'));
    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GraphViewport>(find.byType(GraphViewport)).layout.nodes,
      hasLength(1),
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('New tabs stay visible and horizontal arrows reach older tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VisorConfigApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byTooltip('New · Ctrl+N'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Untitled 9').hitTestable(), findsOneWidget);
    final tabs = tester.widget<ListView>(
      find.byKey(const Key('document-tabs')),
    );
    final fixed = tester.getTopLeft(find.byKey(const Key('fixed-compare-tab')));
    final offset = tabs.controller!.offset;
    await tester.tap(find.byKey(const Key('tabs-previous')));
    await tester.pumpAndSettle();
    expect(tabs.controller!.offset, lessThan(offset));
    expect(
      tester.getTopLeft(find.byKey(const Key('fixed-compare-tab'))),
      fixed,
    );
    await tester.tap(find.byKey(const Key('tabs-next')));
    await tester.pumpAndSettle();
    expect(find.text('Untitled 9').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Wide document toolbar fits one row and Copy uses active document',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(const VisorConfigApp());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('json-editor')),
        '{"copy":true}',
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pump();
      expect(copied, '{"copy":true}');
      final toolbar = find.byKey(const Key('document-toolbar'));
      for (final tooltip in [
        'Open · Ctrl+O',
        'Save · Ctrl+S',
        'Save as · Ctrl+Shift+S',
      ]) {
        expect(
          find.descendant(of: toolbar, matching: find.byTooltip(tooltip)),
          findsOneWidget,
        );
      }
      expect(
        tester.getCenter(find.byTooltip('Raw')).dy,
        closeTo(tester.getCenter(find.byTooltip('Copy')).dy, 4),
      );
      expect(
        tester.getCenter(find.byKey(const Key('document-search'))).dy,
        closeTo(tester.getCenter(find.byTooltip('Copy')).dy, 4),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
