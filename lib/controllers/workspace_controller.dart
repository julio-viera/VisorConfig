import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'editor_document_controller.dart';

/// Owns the document collection, selection and document lifetimes.
class WorkspaceController extends ChangeNotifier {
  final _documents = <EditorDocumentController>[];
  List<EditorDocumentController> get documents =>
      UnmodifiableListView(_documents);
  int _active = 0;
  int _sequence = 0;
  int get active => _active;
  EditorDocumentController get current => _documents[_active];

  EditorDocumentController add({
    required String untitledLabel,
    String? name,
    String text = '',
    String? path,
    bool unsaved = false,
  }) {
    final document = EditorDocumentController(
      name ?? '$untitledLabel ${++_sequence}',
      text: text,
      path: path,
    )..addListener(notifyListeners);
    if (unsaved) document.savedText = '';
    _documents.add(document);
    _active = _documents.length - 1;
    notifyListeners();
    return document;
  }

  int indexOfPath(String? path) {
    if (path == null || path.isEmpty) return -1;
    final exact = _documents.indexWhere((document) => document.path == path);
    if (exact >= 0 || !_documents.any((document) => document.path != null)) {
      return exact;
    }
    final identity = _fileIdentity(path);
    return _documents.indexWhere((document) {
      final openPath = document.path;
      return openPath == path ||
          openPath != null && _fileIdentity(openPath) == identity;
    });
  }

  Future<EditorDocumentController?> findPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    final exact = _documents
        .where((document) => document.path == path)
        .firstOrNull;
    if (exact != null) return exact;
    final candidates = [
      for (final document in _documents)
        if (document.path case final openPath?) (document, openPath),
    ];
    if (candidates.isEmpty) return null;
    final identity = await _fileIdentityAsync(path);
    for (final (document, openPath) in candidates) {
      if (await _fileIdentityAsync(openPath) == identity &&
          document.path == openPath) {
        if (_documents.contains(document)) return document;
      }
    }
    return _documents.where((document) => document.path == path).firstOrNull;
  }

  Future<String> _fileIdentityAsync(String path) async {
    final file = File(path);
    try {
      return await file.resolveSymbolicLinks();
    } on FileSystemException {
      return file.absolute.uri.normalizePath().toFilePath();
    } on ArgumentError {
      return path;
    }
  }

  String _fileIdentity(String path) {
    final file = File(path);
    try {
      return file.resolveSymbolicLinksSync();
    } on FileSystemException {
      return file.absolute.uri.normalizePath().toFilePath();
    } on ArgumentError {
      return path;
    }
  }

  void select(int index) {
    RangeError.checkValidIndex(index, _documents);
    _active = index;
    notifyListeners();
  }

  /// Caller disposes the detached document after its fields leave the widget tree.
  void replace(
    EditorDocumentController previous,
    EditorDocumentController replacement,
  ) {
    final index = _documents.indexOf(previous);
    if (index < 0) throw StateError('Document is no longer open');
    previous.removeListener(notifyListeners);
    previous.watcher?.cancel();
    replacement.addListener(notifyListeners);
    _documents[index] = replacement;
    _active = index;
    notifyListeners();
  }

  void remove(EditorDocumentController document) {
    final index = _documents.indexOf(document);
    if (index < 0) return;
    _documents.removeAt(index);
    if (_active > index) _active--;
    if (_active >= _documents.length) _active = _documents.length - 1;
    document.removeListener(notifyListeners);
    document.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final document in _documents) {
      document.removeListener(notifyListeners);
      document.dispose();
    }
    super.dispose();
  }
}
