import '../themes/code_palette.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/json_document.dart';
import '../models/json_standard.dart';
import '../repositories/document_repository.dart';
import '../services/document_export_service.dart';
import '../services/file_dialog_service.dart';
import 'editor_document_controller.dart';
import 'workspace_controller.dart';

/// Coordinates file workflows; the screen provides user decisions and feedback.
class DocumentFileController {
  DocumentFileController({
    required this.workspace,
    required this.canDiscard,
    required this.confirmReload,
    required this.message,
    required this.changed,
    required this.revealActiveTab,
    required this.disposeDetached,
    DocumentRepository? files,
    FileDialogService? dialogs,
    this.lastOpenDirectory,
    this.onOpenDirectory,
  }) : files = files ?? DocumentRepository(),
       dialogs = dialogs ?? FileDialogService();
  String? lastOpenDirectory;
  final Future<void> Function(String)? onOpenDirectory;
  final WorkspaceController workspace;
  final DocumentRepository files;
  final FileDialogService dialogs;
  final exporter = DocumentExportService();
  final Future<bool> Function(EditorDocumentController) canDiscard;
  final Future<bool?> Function(EditorDocumentController) confirmReload;
  final void Function(Object) message;
  final void Function() changed, revealActiveTab;
  final void Function(EditorDocumentController) disposeDetached;
  bool opening = false;
  bool _disposed = false;
  bool get mounted => !_disposed;
  List<EditorDocumentController> get docs => workspace.documents;
  EditorDocumentController get doc => workspace.current;
  void dispose() {
    _disposed = true;
  }

  bool focusOpenFile(String? path) {
    final index = workspace.indexOfPath(path);
    if (index < 0) return false;
    workspace.select(index);
    revealActiveTab();
    return true;
  }

  Future<bool> focusOpenFileAsync(String? path) async {
    final document = await workspace.findPath(path);
    if (document == null || !mounted) return false;
    final index = docs.indexOf(document);
    if (index < 0 || !mounted) return false;
    workspace.select(index);
    revealActiveTab();
    return true;
  }

  Future<void> open([List<XFile>? files]) async {
    if (opening || files != null && files.isEmpty) return;
    opening = true;
    final target = doc;
    try {
      if (files != null && await focusOpenFileAsync(files.first.path)) {
        await _openAdditionalFiles(files.skip(1));
        return;
      }
      // Resolve unsaved changes before showing the native file chooser.
      if (!await canDiscard(target) || !mounted || target.closed) return;
      final revision = target.revision;
      final selected = files == null
          ? await dialogs.open(initialDirectory: lastOpenDirectory)
          : files.first;
      if (selected == null || !mounted || target.closed) return;
      if (await focusOpenFileAsync(selected.path)) {
        if (files != null) await _openAdditionalFiles(files.skip(1));
        return;
      }
      final text = await this.files.read(selected);
      if (!mounted || target.closed) return;
      // A file watcher can update the document while the chooser is open.
      if (target.revision != revision &&
          target.dirty &&
          !await canDiscard(target)) {
        return;
      }
      if (!mounted || target.closed) return;
      if (await focusOpenFileAsync(selected.path)) {
        if (files != null) await _openAdditionalFiles(files.skip(1));
        return;
      }
      if (!mounted || target.closed) return;
      final index = docs.indexOf(target);
      if (index < 0) return;
      final replacement = EditorDocumentController(
        selected.name,
        text: text,
        path: selected.path,
      );
      workspace.replace(target, replacement);
      // Let text fields detach their controllers before disposing the old tab state.
      disposeDetached(target);
      if (!Platform.isAndroid) watch(replacement);
      revealActiveTab();
      if (files == null && !Platform.isAndroid && selected.path.isNotEmpty) {
        final directory = File(selected.path).absolute.parent.path;
        lastOpenDirectory = directory;
        await onOpenDirectory?.call(directory);
        if (!mounted) return;
      }
      // Dropping several files replaces the focused tab with the first one.
      if (files != null) await _openAdditionalFiles(files.skip(1));
    } catch (e) {
      message(e);
    } finally {
      opening = false;
    }
  }

  Future<void> _openAdditionalFiles(Iterable<XFile> selected) async {
    for (final file in selected) {
      if (!mounted) return;
      if (await focusOpenFileAsync(file.path)) continue;
      final text = await files.read(file);
      if (!mounted) return;
      if (await focusOpenFileAsync(file.path)) continue;
      if (!mounted) return;
      final added = workspace.add(
        untitledLabel: '',
        name: file.name,
        text: text,
        path: file.path,
      );
      if (!Platform.isAndroid) watch(added);
      revealActiveTab();
    }
  }

  void watch(EditorDocumentController d) {
    d.watcher?.cancel();
    if (d.path == null) return;
    try {
      final path = d.path!;
      d.watcher = files
          .watch(path)
          .listen(
            (_) => _queueReload(d, path),
            onError: (Object e) => message(e),
          );
    } catch (e) {
      message(e);
    }
  }

  final _queuedReloads = <EditorDocumentController, String>{};

  Future<void> _queueReload(EditorDocumentController d, String path) async {
    if (!mounted || d.closed || d.path != path || pendingSave(d) != null) {
      return;
    }
    _queuedReloads[d] = path;
    if (d.externalPrompt) return;

    d.externalPrompt = true;
    String? lastPath, lastText;
    try {
      while (_queuedReloads.containsKey(d)) {
        final queuedPath = _queuedReloads.remove(d)!;
        if (!mounted || d.closed) return;
        if (d.path != queuedPath || pendingSave(d) != null) continue;
        try {
          final text = await files.readPath(queuedPath);
          if (!mounted ||
              d.closed ||
              d.path != queuedPath ||
              pendingSave(d) != null ||
              text == d.savedText ||
              (queuedPath == lastPath && text == lastText)) {
            continue;
          }
          lastPath = queuedPath;
          lastText = text;
          final revision = d.revision;
          final reload = await confirmReload(d);
          if (mounted &&
              !d.closed &&
              d.path == queuedPath &&
              d.revision == revision &&
              pendingSave(d) == null &&
              reload == true) {
            d.savedText = text;
            d.editor.text = text;
          }
        } catch (_) {
          // An external replacement may temporarily remove the file.
        }
      }
    } finally {
      _queuedReloads.remove(d);
      d.externalPrompt = false;
    }
  }

  final _pendingSaves = <EditorDocumentController, Future<bool>>{};

  Future<bool>? pendingSave(EditorDocumentController document) =>
      _pendingSaves[document];

  Future<bool> save(
    EditorDocumentController document, {
    bool saveAs = false,
  }) async {
    final previous = _pendingSaves[document];
    final next = () async {
      if (previous != null) await previous;
      if (document.closed) return false;
      return _save(document, saveAs: saveAs);
    }();
    _pendingSaves[document] = next;
    if (previous == null) changed();
    try {
      return await next;
    } finally {
      if (identical(_pendingSaves[document], next)) {
        _pendingSaves.remove(document);
        changed();
      }
    }
  }

  Future<bool> _save(EditorDocumentController d, {bool saveAs = false}) async {
    try {
      if (Platform.isAndroid) {
        final text = d.editor.text;
        final name = _suggestedName(d);
        final uri = await dialogs.saveAndroid(
          fileName: name,
          bytes: Uint8List.fromList(utf8.encode(text)),
          mimeType: _mimeType(d.format.name),
        );
        if (uri == null) return false;
        if (!d.closed) {
          d.savedText = text;
          d.name = name;
          changed();
        }
        return true;
      }
      var path = d.path;
      if (saveAs || path == null) {
        final location = await dialogs.saveLocation(
          suggestedName: _suggestedName(d),
        );
        if (location == null) return false;
        path = location.path;
      }
      path = await dialogs.authorizeSavePath(path);
      if (path == null) return false;
      final text = d.editor.text;
      await files.write(path, utf8.encode(text));
      if (d.closed) return true;
      d.savedText = text;
      d.path = path;
      d.name = path.split(Platform.pathSeparator).last;
      watch(d);
      if (d.editor.format != d.format ||
          d.editor.jsonComments != (d.standard == jsonSchemaWithComments)) {
        d.validate();
      }
      changed();
      return true;
    } catch (e) {
      message(e);
      return false;
    }
  }

  static final _configExtension = RegExp(
    r'\.(jsonc?|jsonld|geojson|yaml|yml|toml|ini|cfg|env(?:\.[\w.-]+)?|properties|txt)$',
    caseSensitive: false,
  );

  String _suggestedName(EditorDocumentController document) =>
      _configExtension.hasMatch(document.name)
      ? document.name
      : '${document.name}.${document.format.extension}';

  String _mimeType(String kind) => switch (kind) {
    'png' => 'image/png',
    'svg' => 'image/svg+xml',
    'json' => 'application/json',
    'csv' => 'text/csv',
    'toml' => 'application/toml',
    'ini' || 'dotenv' || 'properties' => 'text/plain',
    _ => 'application/yaml',
  };

  Future<void> export(
    String kind, {
    CodePalette palette = const CodePalette(false),
    required Future<bool> Function(int) confirmTruncation,
  }) async {
    final d = doc, result = doc.result;
    if (result == null || result.error != null) return;
    if (result.hasDuplicateKeys) {
      message(result.issues.first);
      return;
    }
    try {
      final graphNodes = kind == 'svg' || kind == 'png'
          ? d.graphNodes.toList()
          : const <JsonNode>[];
      if ((kind == 'svg' || kind == 'png') && graphNodes.length > 2000) {
        if (!await confirmTruncation(graphNodes.length) ||
            !mounted ||
            d.closed) {
          return;
        }
      }
      final bytes = await exporter.encode(
        result.value,
        graphNodes,
        kind,
        palette: palette,
        nativeValue: result.nativeValue,
        radial: d.mode == 'radial',
        diagram: d.mode == 'diagram',
      );
      final extension = kind == 'dotenv' ? 'env' : kind;
      final base = d.name.replaceFirst(_configExtension, '');
      final name = base.isEmpty ? '.$extension' : '$base.$extension';
      if (Platform.isAndroid) {
        await dialogs.saveAndroid(
          fileName: name,
          bytes: Uint8List.fromList(bytes),
          mimeType: _mimeType(kind),
        );
        return;
      }
      final location = await dialogs.saveLocation(suggestedName: name);
      if (location != null) {
        final path = await dialogs.authorizeSavePath(location.path);
        if (path != null) await files.write(path, bytes);
      }
    } catch (e) {
      message(e);
    }
  }
}
