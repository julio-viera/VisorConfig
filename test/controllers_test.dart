import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/controllers/document_file_controller.dart';
import 'package:visor_config/controllers/editor_document_controller.dart';
import 'package:visor_config/controllers/workspace_controller.dart';
import 'package:visor_config/repositories/document_repository.dart';

class FailingDocumentRepository extends DocumentRepository {
  @override
  Future<void> write(String path, List<int> bytes) async {
    throw StateError('Disk write failed');
  }
}

class WatchingRepository extends DocumentRepository {
  final events = StreamController<FileSystemEvent>.broadcast(sync: true);
  final reads = <Completer<String>>[];

  @override
  Stream<FileSystemEvent> watch(String path) => events.stream;

  @override
  Future<String> readPath(String path) {
    final read = Completer<String>();
    reads.add(read);
    return read.future;
  }
}

void main() {
  test(
    'Removing tabs preserves selection and disposes only removed documents',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      final first = workspace.add(untitledLabel: 'Untitled');
      final second = workspace.add(untitledLabel: 'Untitled');
      final third = workspace.add(untitledLabel: 'Untitled');
      expect(() => workspace.documents.clear(), throwsUnsupportedError);
      workspace.remove(first);
      expect(first.closed, isTrue);
      expect(workspace.current, same(third));
      expect(workspace.active, 1);
      workspace.remove(third);
      expect(workspace.current, same(second));
      expect(workspace.active, 0);
      workspace.remove(second);
      expect(workspace.documents, isEmpty);
      final next = workspace.add(untitledLabel: 'Untitled');
      expect(next.name, 'Untitled 4');
      expect(workspace.current, same(next));
    },
  );

  test('Replacement detaches old listeners and defers their disposal', () {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    final original = workspace.add(untitledLabel: 'Untitled');
    addTearDown(original.dispose);
    final replacement = EditorDocumentController('loaded.json', text: '{}');
    var notifications = 0;
    workspace.addListener(() => notifications++);
    workspace.replace(original, replacement);
    expect(workspace.current, same(replacement));
    expect(original.closed, isFalse);
    final before = notifications;
    original.editor.text = '{"detached":true}';
    expect(notifications, before);
    replacement.editor.text = '{"current":true}';
    expect(notifications, greaterThan(before));
  });

  test(
    'External changes share one read and one confirmation at a time',
    () async {
      const path = '/unused/test.json';
      final workspace = WorkspaceController();
      final repository = WatchingRepository();
      addTearDown(() async {
        workspace.dispose();
        await repository.events.close();
      });
      final document = workspace.add(untitledLabel: '', path: path, text: '{}');
      final prompts = <Completer<bool?>>[];
      final controller = DocumentFileController(
        workspace: workspace,
        files: repository,
        canDiscard: (_) async => true,
        confirmReload: (_) {
          final prompt = Completer<bool?>();
          prompts.add(prompt);
          return prompt.future;
        },
        message: (error) => fail('$error'),
        changed: () {},
        revealActiveTab: () {},
        disposeDetached: (document) => document.dispose(),
      );
      addTearDown(controller.dispose);
      controller.watch(document);
      void event() =>
          repository.events.add(FileSystemModifyEvent(path, false, true));
      event();
      event();
      expect(repository.reads, hasLength(1));
      repository.reads.first.complete('{"version":1}');
      await Future<void>.delayed(Duration.zero);
      expect(prompts, hasLength(1));
      event();
      event();
      expect(repository.reads, hasLength(1));
      prompts.first.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, hasLength(2));
      repository.reads.last.complete('{"version":2}');
      await Future<void>.delayed(Duration.zero);
      expect(prompts, hasLength(2));
      prompts.last.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(document.editor.text, '{"version":2}');
      expect(document.externalPrompt, isFalse);
    },
  );

  test('Failed save preserves dirty state and reports the error', () async {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    final document = workspace.add(
      untitledLabel: '',
      name: 'test.json',
      text: '{"saved":true}',
      path: '/unused/test.json',
    );
    document.editor.text = '{"changed":true}';
    final errors = <Object>[];
    final controller = DocumentFileController(
      workspace: workspace,
      files: FailingDocumentRepository(),
      canDiscard: (_) async => true,
      confirmReload: (_) async => false,
      message: errors.add,
      changed: () {},
      revealActiveTab: () {},
      disposeDetached: (document) => document.dispose(),
    );
    addTearDown(controller.dispose);
    expect(await controller.save(document), isFalse);
    expect(document.savedText, '{"saved":true}');
    expect(document.editor.text, '{"changed":true}');
    expect(document.dirty, isTrue);
    expect(errors, hasLength(1));
  });
}
