import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:toml/toml.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../models/config_format.dart';
import '../models/json_document.dart';
import '../models/json_standard.dart';
import '../models/source_segment.dart';
import '../services/document_search.dart';
import '../services/json_parser.dart';
import '../services/key_value_config.dart';
import '../services/isolate_job.dart';
import '../utils/document_export.dart';
import '../utils/source_segments.dart';
import 'json_editor_controller.dart';

class EditorDocumentController extends ChangeNotifier {
  EditorDocumentController(this.name, {String text = '', this.path})
    : savedText = text,
      editor = JsonEditorController(text: text) {
    _lastText = text;
    editor.format = format;
    editor.jsonComments = standard == jsonSchemaWithComments;
    editor.addListener(_changed);
    validate();
  }
  String name;
  String? path;
  ConfigFormat? formatOverride;
  ConfigFormat get format =>
      formatOverride ??
      ConfigFormat.fromPath(path) ??
      ConfigFormat.fromPath(name) ??
      ConfigFormat.detect(editor.text);
  String savedText;
  final JsonEditorController editor;
  final search = TextEditingController();
  final scroll = ScrollController();
  final rawScroll = ScrollController();
  final graphTransform = TransformationController();
  String graphRoot = r'$';
  final tableScroll = ScrollController();
  String mode = 'raw', schema = '';
  String? _standard;
  String get standard =>
      _standard ??
      ((path ?? name).toLowerCase().endsWith('.jsonc') ||
              name.toLowerCase().endsWith('.jsonc')
          ? jsonSchemaWithComments
          : jsonSchema);
  set standard(String value) => _standard = value;
  ParseResult? result;
  bool parsing = false, jsonPath = false, externalPrompt = false;
  int revision = 0, currentMatch = 0;
  String? searchError;
  List<JsonNode> matches = [];
  final expanded = <String>{r'$'};
  StreamSubscription<dynamic>? watcher;
  Timer? timer;
  Timer? _searchTimer;
  IsolateJob<ParseResult>? _validation;
  DocumentSearchSession? _searchSession;
  Future<void>? _searchInFlight;
  Timer? _searchIdle;
  int _searchRevision = 0;
  bool searchTruncated = false;
  bool closed = false;
  bool get dirty => editor.text != savedText;
  String _lastText = '';
  List<SourceSegment>? _segments;
  ({int count, int longest})? _lineMetrics;
  ({int count, int longest}) get lineMetrics {
    if (_lineMetrics case final cached?) return cached;
    final text = editor.text;
    var count = 1, longest = 0, start = 0;
    for (
      var end = text.indexOf('\n');
      end >= 0;
      end = text.indexOf('\n', start)
    ) {
      if (end - start > longest) longest = end - start;
      count++;
      start = end + 1;
    }
    if (text.length - start > longest) longest = text.length - start;
    return _lineMetrics = (count: count, longest: longest);
  }

  List<SourceSegment> get sourceSegments =>
      _segments ??= splitSource(editor.text);
  int? get parseErrorLine {
    final parsed = result;
    if (parsing || parsed?.error == null || parsed?.offset == null) return null;
    final offset = parsed!.offset!.clamp(0, editor.text.length);
    return '\n'.allMatches(editor.text.substring(0, offset)).length + 1;
  }

  void _changed() {
    if (_lastText == editor.text) return;
    _lastText = editor.text;
    _segments = null;
    _lineMetrics = null;
    editor.format = format;
    editor.jsonComments = standard == jsonSchemaWithComments;
    revision++;
    _validation?.cancel();
    _closeSearchSession();
    _searchTimer?.cancel();
    _searchRevision++;
    editor.ranges = [];
    editor.query = '';
    result = null;
    matches = [];
    parsing = true;
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 300), validate);
    notifyListeners();
  }

  Future<void> validate() async {
    if (closed) return;
    timer?.cancel();
    editor.format = format;
    editor.jsonComments = standard == jsonSchemaWithComments;
    final version = ++revision;
    _validation?.cancel();
    parsing = true;
    notifyListeners();
    final job = IsolateJob<ParseResult>(parseDocument, {
      'text': editor.text,
      'format': editor.format.name,
      'standard': standard,
      'schema': schema,
    }, const Duration(seconds: 10));
    _validation = job;
    try {
      final parsed = await job.result;
      if (closed || version != revision) return;
      result = parsed;
    } catch (error) {
      if (closed || version != revision) return;
      result = ParseResult(error: error.toString());
    }
    if (closed || version != revision) return;
    parsing = false;
    _closeSearchSession();
    updateSearch();
  }

  void updateSearch() {
    _searchTimer?.cancel();
    _searchIdle?.cancel();
    final version = ++_searchRevision;
    matches = [];
    currentMatch = 0;
    searchError = null;
    searchTruncated = false;
    editor.query = '';
    editor.ranges = [];
    editor.refresh();
    notifyListeners();
    if (closed || search.text.isEmpty) {
      _closeSearchSession();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 200), () async {
      await _searchInFlight;
      if (closed || version != _searchRevision) return;
      final existing = _searchSession;
      final session = existing == null || existing.closed
          ? _searchSession = DocumentSearchSession(editor.text, result)
          : existing;
      final completed = Completer<void>();
      _searchInFlight = completed.future;
      try {
        final found = await session.search(search.text, jsonPath);
        if (closed || version != _searchRevision) return;
        searchTruncated = found.length > 10000;
        matches = found.take(10000).toList();
        editor.ranges = matches
            .map((n) => TextRange(start: n.start, end: n.end))
            .toList();
        editor.refresh();
      } catch (error) {
        if (closed || version != _searchRevision) return;
        searchError = error.toString();
      } finally {
        completed.complete();
        if (identical(_searchSession, session)) {
          _searchIdle?.cancel();
          _searchIdle = Timer(const Duration(seconds: 15), _closeSearchSession);
        }
      }
      notifyListeners();
    });
  }

  void _closeSearchSession() {
    _searchIdle?.cancel();
    _searchSession?.close();
    _searchSession = null;
  }

  List<JsonNode> get visible => _visibleNodes().toList();

  Iterable<JsonNode> _visibleNodes() sync* {
    final nodes = result?.nodes ?? [];
    final shown = <int>{};
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n.parent < 0 ||
          shown.contains(n.parent) && expanded.contains(nodes[n.parent].path)) {
        yield n;
        shown.add(i);
      }
    }
  }

  Iterable<JsonNode> get graphNodes => _visibleNodes().where(
    (n) => n.path == graphRoot || n.path.startsWith('$graphRoot['),
  );

  List<Object> _nodeKeys(JsonNode node) {
    final keys = <Object>[];
    final nodes = result!.nodes;
    while (node.parent >= 0) {
      final parent = nodes[node.parent];
      keys.add(
        parent.value is List
            ? int.parse(node.label.substring(1, node.label.length - 1))
            : node.label,
      );
      node = parent;
    }
    return keys.reversed.toList();
  }

  Object? _nativeKey(dynamic container, Object key) {
    if (container is! Map) return key;
    return container.keys.firstWhere(
      (candidate) => candidate.toString() == key,
    );
  }

  String nodeSource(JsonNode node) {
    final parsed = result!;
    if (parsed.format == ConfigFormat.json || parsed.format.keyValue) {
      return const JsonEncoder.withIndent('  ').convert(node.value);
    }
    dynamic value = parsed.nativeValue;
    for (final key in _nodeKeys(node)) {
      value = value[_nativeKey(value, key)];
    }
    return parsed.format == ConfigFormat.yaml
        ? toYaml(value)
        : node.parent < 0
        ? toToml(value)
        : TomlValue.from(value).toString();
  }

  String editedConfig(JsonNode node, String replacement) {
    final format = result!.format;
    if (format.keyValue) {
      final value = jsonDecode(replacement);
      if (node.parent < 0) return encodeKeyValueConfig(value, format);
      if (node.container) {
        if (value is! Map) {
          throw const FormatException('INI section requires an object');
        }
        final section = encodeKeyValueConfig({node.label: value}, format);
        return editor.text.replaceRange(node.start, node.end, section);
      }
      final entry = encodeKeyValueEntry(node.label, value, format);
      return editor.text.replaceRange(
        node.start,
        node.end,
        format == ConfigFormat.properties
            ? entry
            : entry.substring(entry.indexOf('=') + 1),
      );
    }
    final keys = _nodeKeys(node);
    if (result!.format == ConfigFormat.yaml) {
      final yaml = YamlEditor(editor.text);
      final path = <Object?>[];
      dynamic container = result!.nativeValue;
      for (final key in keys) {
        final nativeKey = _nativeKey(container, key);
        path.add(nativeKey);
        container = container[nativeKey];
      }
      yaml.update(path, loadYaml(replacement));
      return yaml.toString();
    }
    if (keys.isEmpty) return toToml(TomlDocument.parse(replacement).toMap());
    final value = TomlValueBuilder(TomlKey.topLevel)
        .visitValue(TomlValue.parse(replacement.trim()));
    if (node.keyStart != null) {
      return editor.text.replaceRange(
        node.start,
        node.end,
        TomlValue.from(value).toString(),
      );
    }
    final document = TomlDocument.parse(editor.text).toMap();
    dynamic container = document;
    for (final key in keys.take(keys.length - 1)) {
      container = container[key];
    }
    container[keys.last] = value;
    return toToml(document);
  }

  void replaceNode(JsonNode node, String replacement) {
    editor.value = TextEditingValue(
      text: editor.text.replaceRange(node.start, node.end, replacement),
      selection: TextSelection.collapsed(
        offset: node.start + replacement.length,
      ),
    );
  }

  @override
  void dispose() {
    closed = true;
    timer?.cancel();
    _searchTimer?.cancel();
    _validation?.cancel();
    _closeSearchSession();
    watcher?.cancel();
    editor.dispose();
    search.dispose();
    scroll.dispose();
    rawScroll.dispose();
    tableScroll.dispose();
    graphTransform.dispose();
    super.dispose();
  }
}
