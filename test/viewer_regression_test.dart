import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/services/graph_renderer.dart';
import 'package:visor_config/services/json_parser.dart';
import 'package:visor_config/widgets/dialogs/comparison_dialog.dart';
import 'package:visor_config/widgets/graph/graph_view.dart';

import 'dart:ui' as ui;

void main() {
  final nodes = parseDocument({
    'text': '{"a":1}',
    'standard': 'RFC 8259',
    'schema': '',
  }).nodes;
  testWidgets('Graph painting cannot erase surrounding interface', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffff0000), BlendMode.src);
    canvas.translate(100, 100);
    GraphPainter(
      GraphLayout(nodes),
      Colors.black,
      {},
    ).paint(canvas, const Size(300, 200));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(600, 400);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      expect(bytes.take(4), [255, 0, 0, 255]);
      final outside = (350 * 600 + 500) * 4;
      expect(bytes.sublist(outside, outside + 4), [255, 0, 0, 255]);
      image.dispose();
    });
    picture.dispose();
  });
  testWidgets('Zoom controls change graph scale and preserve surrounding UI', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Tabs and search')),
          body: GraphViewport(
            layout: GraphLayout(nodes),
            controller: controller,
            matches: {},
            onTap: (_) {},
            onEdit: (_) {},
            onMenu: (_, _) {},
            spanish: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('graph-zoom-in')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.25, .001));
    expect(find.text('125%'), findsOneWidget);
    expect(find.text('Tabs and search').hitTestable(), findsOneWidget);
    await tester.tap(find.text('100%'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Side by side diff colors changed lines and synchronizes scrolling',
    (tester) async {
      final a = List.generate(100, (i) => '"value$i": $i');
      final b = [...a]..[1] = '"value1": 999';
      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonDialog(
            left: ComparisonSource('before.json', a.join('\n')),
            others: [ComparisonSource('after.json', b.join('\n'))],
            spanish: false,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      final navigation = find.byKey(const Key('diff-navigation-bar'));
      final names = find.byKey(const Key('diff-file-names'));
      final legend = find.byKey(const Key('diff-legend-bar'));
      expect(
        tester.getBottomLeft(navigation).dy,
        lessThanOrEqualTo(tester.getTopLeft(names).dy),
      );
      final paneBottom = tester
          .getBottomLeft(find.byKey(const Key('diff-left')))
          .dy;
      expect(tester.getTopLeft(legend).dy, greaterThanOrEqualTo(paneBottom));
      final left = find.byKey(const Key('diff-left'));
      final right = find.byKey(const Key('diff-right'));
      expect(tester.getTopLeft(left).dx, lessThan(tester.getTopLeft(right).dx));
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('left-line-2')))
            .color,
        const Color(0xffffe4e6),
      );
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('right-line-2')))
            .color,
        const Color(0xffdcfce7),
      );
      await tester.drag(left, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(left).controller!.offset,
        tester.widget<ListView>(right).controller!.offset,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Diff navigation jumps between blocks and wraps in both directions',
    (tester) async {
      final a = List.generate(150, (i) => 'line $i');
      final b = [...a]
        ..[10] = 'first change'
        ..[11] = 'same block'
        ..[120] = 'second change';
      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonDialog(
            left: ComparisonSource('a', a.join('\n')),
            others: [ComparisonSource('b', b.join('\n'))],
            spanish: false,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diff-next')));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('diff-next')));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      final left = tester
          .widget<ListView>(find.byKey(const Key('diff-left')))
          .controller!;
      final right = tester
          .widget<ListView>(find.byKey(const Key('diff-right')))
          .controller!;
      expect(left.offset, greaterThan(2000));
      expect(right.offset, left.offset);
      await tester.tap(find.byKey(const Key('diff-next')));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('diff-previous')));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
    },
  );
  testWidgets('Equal documents have no difference navigation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComparisonDialog(
          left: ComparisonSource('a', '{}'),
          others: [ComparisonSource('b', '{}')],
          spanish: false,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diff-next')), findsNothing);
    expect(find.byKey(const Key('diff-previous')), findsNothing);
  });
}
