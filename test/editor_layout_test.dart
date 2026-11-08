import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/app_info.dart';
import 'package:visor_config/controllers/editor_document_controller.dart';
import 'package:visor_config/models/font_preferences.dart';
import 'package:visor_config/themes/app_theme.dart';
import 'package:visor_config/themes/editor_text_metrics.dart';
import 'package:visor_config/widgets/editor/raw_editor.dart';

void main() {
  for (final scale in [1.0, 1.3, 1.57]) {
    testWidgets(
      'Gutter baseline follows editor lines and scroll at scale $scale',
      (tester) async {
        final document = EditorDocumentController(
          'test',
          text: List.filled(100, '0').join('\n'),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(
              Brightness.light,
              'jade',
              const FontPreferences(style: TypefaceStyle.italic),
            ),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: RawEditor(document: document, hint: '', largeNotice: ''),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        var gutter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('json-line-numbers')),
                    )
                    .painter!
                as LineNumbersPainter;
        final gutterTop = tester
            .getTopLeft(find.byKey(const Key('json-line-numbers')))
            .dy;
        final editorBaseline = editable
            .localToGlobal(
              Offset(
                0,
                editable.getDryBaseline(
                  editable.constraints,
                  TextBaseline.alphabetic,
                )!,
              ),
            )
            .dy;
        expect(
          gutterTop + editorTopPadding + gutter.firstBaseline,
          closeTo(editorBaseline, .6),
        );
        final firstBox = editable
            .getBoxesForSelection(
              const TextSelection(baseOffset: 2, extentOffset: 3),
            )
            .first;
        final lastBox = editable
            .getBoxesForSelection(
              const TextSelection(baseOffset: 196, extentOffset: 197),
            )
            .first;
        expect(lastBox.top - firstBox.top, closeTo(97 * gutter.lineHeight, .1));
        document.rawScroll.jumpTo(200);
        await tester.pump();
        gutter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('json-line-numbers')),
                    )
                    .painter!
                as LineNumbersPainter;
        final visibleBox = editable
            .getBoxesForSelection(
              const TextSelection(baseOffset: 20, extentOffset: 21),
            )
            .first;
        final firstAfterScroll = editable
            .getBoxesForSelection(
              const TextSelection(baseOffset: 2, extentOffset: 3),
            )
            .first;
        expect(
          visibleBox.top - firstAfterScroll.top,
          closeTo(9 * gutter.lineHeight, .1),
        );
        expect(gutter.offset, document.rawScroll.offset);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        document.dispose();
      },
    );
  }

  testWidgets(
    'Compact rounded tabs and footer align identity left and status right',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const VisorConfigApp());
      await tester.pumpAndSettle();
      final tab = find.byKey(const ValueKey('document-tab-0'));
      final clip = tester.widget<ClipPath>(
        find.ancestor(of: tab, matching: find.byType(ClipPath)).first,
      );
      final size = tester.getSize(tab);
      final path = clip.clipper!.getClip(size);
      expect(path.contains(Offset(size.width - 3, 2)), isFalse);
      expect(path.contains(Offset(size.width - 3, size.height - .1)), isTrue);
      expect(tester.getSize(find.byKey(const Key('document-tabs'))).height, 38);
      final footer = find.byKey(const Key('workspace-status-bar'));
      expect(tester.getSize(footer).height, lessThanOrEqualTo(34));
      final identity = find.byKey(const Key('app-identity'));
      final name = find.descendant(of: identity, matching: find.text(appName));
      final version = find.descendant(
        of: identity,
        matching: find.text(appVersion),
      );
      expect(
        tester.getCenter(name).dy,
        closeTo(tester.getCenter(version).dy, .1),
      );
      expect(
        tester.getTopLeft(identity).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('character-count'))).dx,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('app-about'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('parse-status'))).dx),
      );
      expect(
        tester.getBottomRight(find.byKey(const Key('parse-status'))).dx,
        closeTo(tester.getBottomRight(footer).dx - 8, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
