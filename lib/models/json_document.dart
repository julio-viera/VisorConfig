import 'dart:convert';

import 'config_format.dart';

class JsonNode {
  JsonNode(
    this.path,
    this.label,
    this.start,
    this.end,
    this.depth,
    this.parent,
    this.value, {
    this.keyStart,
  });
  final String path, label;
  final int start, end, depth, parent;
  final dynamic value;
  final int? keyStart;
  bool get container => value is Map || value is List;
  bool get hasChildren => switch (value) {
    final Map entries => entries.isNotEmpty,
    final List entries => entries.isNotEmpty,
    _ => false,
  };
  String get type => value == null
      ? 'null'
      : value is Map
      ? 'object'
      : value is List
      ? 'array'
      : value is String
      ? 'string'
      : value is bool
      ? 'boolean'
      : 'number';
  String get preview => value is Map
      ? '{${(value as Map).length}}'
      : value is List
      ? '[${(value as List).length}]'
      : jsonEncode(value);
}

class ParseResult {
  ParseResult({
    this.value,
    this.nativeValue,
    this.format = ConfigFormat.json,
    this.nodes = const [],
    this.error,
    this.offset,
    this.issues = const [],
    this.hasDuplicateKeys = false,
  });
  final dynamic value;
  final dynamic nativeValue;
  final ConfigFormat format;
  final List<JsonNode> nodes;
  final String? error;
  final int? offset;
  final List<String> issues;
  final bool hasDuplicateKeys;
  late final Map<String, JsonNode> byPath = {
    for (final node in nodes) node.path: node,
  };
  bool get valid => error == null && issues.isEmpty;
}
