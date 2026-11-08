import 'dart:async';
import 'dart:isolate';

import 'package:json_path/json_path.dart';

import '../models/json_document.dart';

List<JsonNode> searchNodes(
  ParseResult result,
  String query,
  bool jsonPath, {
  int limit = 10001,
}) {
  if (query.isEmpty) return [];
  if (jsonPath) {
    final paths = JsonPath(query)
        .read(result.value)
        .take(limit)
        .map((m) => m.pointer.toString())
        .toSet();
    // Match by JSON Pointer rather than values, which may be duplicated.
    final pointers = <int, String>{};
    final found = <JsonNode>[];
    for (var i = 0; i < result.nodes.length; i++) {
      final node = result.nodes[i];
      final parent = node.parent;
      final part = parent < 0
          ? ''
          : result.nodes[parent].value is List
          ? node.label.substring(1, node.label.length - 1)
          : node.label.replaceAll('~', '~0').replaceAll('/', '~1');
      pointers[i] = parent < 0 ? '' : '${pointers[parent]}/$part';
      if (paths.contains(pointers[i])) found.add(node);
      if (found.length >= limit) break;
    }
    return found;
  }
  return result.nodes
      .where(
        (n) =>
            n.label.toLowerCase().contains(query.toLowerCase()) ||
            n.preview.toLowerCase().contains(query.toLowerCase()),
      )
      .take(limit)
      .toList();
}

List<JsonNode> searchText(
  String text,
  List<JsonNode> nodes,
  String query, {
  int limit = 10001,
}) {
  if (query.isEmpty) return [];
  var next = 0;
  final stack = <JsonNode>[];
  final matches = <JsonNode>[];
  for (final match in RegExp(
    RegExp.escape(query),
    caseSensitive: false,
  ).allMatches(text).take(limit)) {
    while (next < nodes.length &&
        (nodes[next].keyStart ?? nodes[next].start) <= match.start) {
      final node = nodes[next++];
      while (stack.isNotEmpty &&
          stack.last.end <= (node.keyStart ?? node.start)) {
        stack.removeLast();
      }
      stack.add(node);
    }
    while (stack.isNotEmpty && stack.last.end < match.end) {
      stack.removeLast();
    }
    final owner = stack.lastOrNull;
    matches.add(
      JsonNode(
        owner?.path ?? r'$',
        owner?.label ?? '',
        match.start,
        match.end,
        owner?.depth ?? 0,
        owner?.parent ?? -1,
        owner?.value,
      ),
    );
  }
  return matches;
}

List<JsonNode> runDocumentSearch(Map<String, Object?> request) {
  final result = request['result'] as ParseResult?;
  final query = request['query'] as String;
  if (request['jsonPath'] == true) {
    return result == null || result.error != null
        ? []
        : searchNodes(result, query, true);
  }
  return searchText(request['text'] as String, result?.nodes ?? [], query);
}

/// Keeps one document revision in the worker across successive queries.
class DocumentSearchSession {
  DocumentSearchSession(String text, ParseResult? result) {
    _worker = _start(text, result);
  }

  final _ready = ReceivePort();
  late final Future<SendPort> _worker;
  Isolate? _isolate;
  ReceivePort? _reply;
  bool closed = false;

  Future<SendPort> _start(String text, ParseResult? result) async {
    try {
      final isolate = await Isolate.spawn(_searchWorker, (
        _ready.sendPort,
        text,
        result,
      ), onExit: _ready.sendPort);
      if (closed) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError('Search cancelled');
      }
      _isolate = isolate;
      return await _ready.first as SendPort;
    } finally {
      _ready.close();
    }
  }

  Future<List<JsonNode>> search(String query, bool jsonPath) async {
    final reply = ReceivePort();
    _reply = reply;
    try {
      final response = await (() async {
        final worker = await _worker;
        if (closed) throw StateError('Search cancelled');
        worker.send((reply.sendPort, query, jsonPath));
        return await reply.first;
      })().timeout(const Duration(seconds: 3));
      if (response is String) throw StateError(response);
      return response as List<JsonNode>;
    } on TimeoutException {
      close();
      rethrow;
    } finally {
      reply.close();
      _reply = null;
    }
  }

  void close() {
    if (closed) return;
    closed = true;
    _reply?.close();
    _ready.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}

void _searchWorker((SendPort, String, ParseResult?) initial) {
  final (host, text, result) = initial;
  final requests = ReceivePort();
  host.send(requests.sendPort);
  requests.listen((message) {
    final (reply, query, jsonPath) = message as (SendPort, String, bool);
    try {
      final matches = runDocumentSearch({
        'text': text,
        'result': result,
        'query': query,
        'jsonPath': jsonPath,
      });
      reply.send([
        for (final node in matches)
          JsonNode(
            node.path,
            node.label,
            node.start,
            node.end,
            node.depth,
            node.parent,
            null,
            keyStart: node.keyStart,
          ),
      ]);
    } catch (error) {
      reply.send(error.toString());
    }
  });
}
