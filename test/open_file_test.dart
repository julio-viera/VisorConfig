import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/app/visor_config_app.dart';
import 'package:visor_config/repositories/settings_repository.dart';
import 'package:visor_config/services/file_dialog_service.dart';

class FakeSelector extends FileSelectorPlatform {
  int opens = 0, saves = 0;
  final initialDirectories = <String?>[];
  XFile? selected;
  String? savePath;
  Future<void> Function()? beforeOpen;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opens++;
    initialDirectories.add(initialDirectory);
    await beforeOpen?.call();
    return selected;
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saves++;
    return savePath == null ? null : FileSaveLocation(savePath!);
  }
}

void main() {
  late FakeSelector selector;
  setUp(() {
    final previous = FileSelectorPlatform.instance;
    selector = FakeSelector();
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = previous);
    selector.selected = XFile.fromData(
      utf8.encode('{"opened":true}'),
      path: '/tmp/visor-open-test.json',
      name: 'visor-open-test.json',
    );
  });
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  String contents(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('json-editor')))
      .controller!
      .text;
  testWidgets('Open replaces focused tab and leaves other tabs unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(const VisorConfigApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New · Ctrl+N'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open · Ctrl+O'));
    await settle(tester);
    expect(contents(tester), '{"opened":true}');
    expect(find.text('Untitled 2'), findsNothing);
    expect(find.text('visor-open-test.json'), findsOneWidget);
    expect(
      tester
          .widget<ListView>(find.byKey(const Key('document-tabs')))
          .childrenDelegate
          .estimatedChildCount,
      2,
    );
    await tester.tap(find.text('Untitled 1'));
    await tester.pumpAndSettle();
    expect(contents(tester), isEmpty);
  });
  testWidgets(
    'Cancel unsaved prompt prevents chooser; cancel chooser retains original document',
    (tester) async {
      await tester.pumpWidget(const VisorConfigApp());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('json-editor')),
        '{"unsaved":1}',
      );
      await tester.tap(find.byTooltip('Open · Ctrl+O'));
      await tester.pumpAndSettle();
      expect(selector.opens, 0);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(selector.opens, 0);
      expect(contents(tester), '{"unsaved":1}');
      selector.selected = null;
      await tester.tap(find.byTooltip('Open · Ctrl+O'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(selector.opens, 1);
      expect(contents(tester), '{"unsaved":1}');
      expect(find.text('● Untitled 1'), findsOneWidget);
    },
  );
  testWidgets(
    'Save completes before opening chooser and canceled save prevents opening',
    (tester) async {
      await tester.pumpWidget(const VisorConfigApp());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('json-editor')),
        '{"keep":2}',
      );
      await tester.tap(find.byTooltip('Open · Ctrl+O'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(selector.saves, 1);
      expect(selector.opens, 0);
      expect(contents(tester), '{"keep":2}');
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('visor-save-test-'),
      );
      selector.savePath = '${directory!.path}/saved.json';
      selector.beforeOpen = () async {
        expect(File(selector.savePath!).readAsStringSync(), '{"keep":2}');
      };
      await tester.tap(find.byTooltip('Open · Ctrl+O'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);
      for (var i = 0; i < 30 && contents(tester) != '{"opened":true}'; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }
      expect(selector.opens, 1);
      expect(contents(tester), '{"opened":true}');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => directory.delete(recursive: true));
    },
  );
  testWidgets('Open remembers its folder across restart; cancel keeps it', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('visor-folder-'),
    );
    final folder = Directory('${directory!.path}/JSON documents');
    await tester.runAsync(() => folder.create());
    final repository = SettingsRepository(directory: directory);
    selector.selected = XFile.fromData(
      utf8.encode('{}'),
      path: '${folder.path}/example.json',
      name: 'example.json',
    );
    await tester.pumpWidget(VisorConfigApp(settingsStore: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open · Ctrl+O'));
    await settle(tester);
    expect(selector.initialDirectories, [null]);
    var restored = await tester.runAsync(() => repository.load());
    for (var i = 0; i < 10 && restored!.lastOpenDirectory == null; i++) {
      await settle(tester);
      restored = await tester.runAsync(() => repository.load());
    }
    expect(restored!.lastOpenDirectory, folder.path);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    selector.selected = null;
    await tester.pumpWidget(
      VisorConfigApp(initialSettings: restored, settingsStore: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open · Ctrl+O'));
    await settle(tester);
    expect(selector.initialDirectories.last, folder.path);
    expect(
      (await tester.runAsync(() => repository.load()))!.lastOpenDirectory,
      folder.path,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => directory.delete(recursive: true));
  });

  test(
    'Missing remembered folder falls back to the default selector location',
    () async {
      selector.selected = null;
      await FileDialogService().open(
        initialDirectory: '/missing-visor-directory/nonexistent',
      );
      expect(selector.initialDirectories, [null]);
    },
  );
}
