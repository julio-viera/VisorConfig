import 'dart:convert';
import 'dart:io';

import '../models/config_format.dart';
import '../models/launch_request.dart';
import '../repositories/document_repository.dart';

Future<LaunchResult> loadLaunchDocuments(
  LaunchPlan plan, {
  String? currentDirectory,
  bool deferFileReads = false,
}) async {
  final documents = <LaunchDocument>[], issues = <LaunchIssue>[];
  final base = Directory(currentDirectory ?? Directory.current.path).absolute;
  for (final input in plan.inputs) {
    final value = input.value;
    if (input.kind == LaunchInputKind.text) {
      documents.add(LaunchDocument(text: value));
      continue;
    }
    var fileDetected = false;
    String? path;
    try {
      final uri = Uri.tryParse(value);
      final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(value);
      final absolute = file.isAbsolute
          ? file
          : File('${base.path}${Platform.pathSeparator}${file.path}');
      path = absolute.path;
      final type = await FileSystemEntity.type(path, followLinks: true);
      if (type == FileSystemEntityType.file) {
        fileDetected = true;
        documents.add(
          LaunchDocument(
            text: deferFileReads
                ? ''
                : await DocumentRepository().readPath(path),
            deferred: deferFileReads,
            name: absolute.uri.pathSegments.last,
            path: path,
          ),
        );
      } else if (input.kind == LaunchInputKind.file ||
          type != FileSystemEntityType.notFound ||
          _looksLikePath(value)) {
        throw FileSystemException(
          type == FileSystemEntityType.notFound
              ? 'File not found'
              : 'Not a regular file',
          value,
        );
      } else {
        // Invalid JSON text is still useful: the editor shows its parse error.
        documents.add(LaunchDocument(text: value));
      }
    } on FileSystemException catch (e) {
      if (input.kind == LaunchInputKind.auto &&
          !fileDetected &&
          !_looksLikePath(value)) {
        documents.add(LaunchDocument(text: value));
      } else {
        issues.add(LaunchIssue(value, e.message, path: path));
      }
    } on FormatException catch (e) {
      issues.add(LaunchIssue(value, e.message, path: path));
    } on ArgumentError catch (e) {
      issues.add(LaunchIssue(value, e.message.toString(), path: path));
    }
  }
  return LaunchResult(documents: documents, issues: issues);
}

bool _looksLikePath(String value) {
  final trimmed = value.trimLeft();
  // JSON objects/arrays, even malformed ones, are content rather than paths.
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return false;
  try {
    jsonDecode(value);
    return false;
  } on FormatException {
    /* Check path syntax next. */
  }
  return value.startsWith('file:') ||
      value.startsWith('/') ||
      value.startsWith('./') ||
      value.startsWith('../') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value) ||
      ConfigFormat.fromPath(value) != null ||
      value.toLowerCase().endsWith('.txt') ||
      !value.contains(RegExp(r'\s')) &&
          (value.contains('/') || value.contains('\\'));
}
