import 'dart:convert';

import 'package:petitparser/petitparser.dart';
import 'package:toml/toml.dart';
import 'package:yaml/yaml.dart';

import '../models/config_format.dart';
import '../models/json_document.dart';

typedef _Range = ({int start, int end, int? keyStart});

ParseResult parseConfig(String text, ConfigFormat format) {
  try {
    final ranges = <String, _Range>{};
    final value = format == ConfigFormat.yaml
        ? loadYamlNode(text)
        : _parseToml(text, ranges);
    final nodes = <JsonNode>[];
    final native = _buildNodes(
      value,
      path: r'$',
      label: r'$',
      depth: 0,
      parent: -1,
      inherited: (start: 0, end: text.length, keyStart: null),
      ranges: ranges,
      nodes: nodes,
    );
    return ParseResult(
      value: nodes.first.value,
      nativeValue: native,
      format: format,
      nodes: nodes,
    );
  } on YamlException catch (error) {
    return ParseResult(
      format: format,
      error: error.message,
      offset: error.span?.start.offset,
    );
  } on FormatException catch (error) {
    return ParseResult(
      format: format,
      error: error.message,
      offset: error.offset,
    );
  } catch (error) {
    return ParseResult(format: format, error: error.toString());
  }
}

dynamic _buildNodes(
  dynamic source, {
  required String path,
  required String label,
  required int depth,
  required int parent,
  required _Range inherited,
  required Map<String, _Range> ranges,
  required List<JsonNode> nodes,
  int? keyStart,
}) {
  final range = source is YamlNode
      ? (
          start: source.span.start.offset,
          end: source.span.end.offset,
          keyStart: keyStart,
        )
      : ranges[path] ?? inherited;
  if (depth > 256 || nodes.length >= 100000) {
    throw FormatException(
      'Document exceeds the depth or node limit',
      null,
      range.start,
    );
  }
  final index = nodes.length;
  nodes.add(JsonNode(path, label, range.start, range.end, depth, parent, null));
  final value = switch (source) {
    YamlMap map => map.nodes,
    YamlList list => list.nodes,
    YamlScalar scalar => scalar.value,
    _ => source,
  };
  dynamic child(dynamic input, String suffix, String name, [int? keyOffset]) =>
      _buildNodes(
        input,
        path: '$path$suffix',
        label: name,
        depth: depth + 1,
        parent: index,
        inherited: (start: range.start, end: range.end, keyStart: null),
        ranges: ranges,
        nodes: nodes,
        keyStart: keyOffset,
      );
  final native = switch (value) {
    Map() => <dynamic, dynamic>{},
    List() => <dynamic>[],
    _ => value,
  };
  dynamic display = value;
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final rawKey = key is YamlNode ? key.value : key;
      final name = rawKey.toString();
      if (rawKey is Map || rawKey is List || normalized.containsKey(name)) {
        throw FormatException(
          'Unsupported or ambiguous YAML mapping key: $name',
          null,
          range.start,
        );
      }
      final childIndex = nodes.length;
      (native as Map)[rawKey] = child(
        entry.value,
        '[${jsonEncode(name)}]',
        name,
        key is YamlNode ? key.span.start.offset : null,
      );
      normalized[name] = nodes[childIndex].value;
    }
    display = normalized;
  } else if (value is List) {
    final normalized = <dynamic>[];
    for (var i = 0; i < value.length; i++) {
      final childIndex = nodes.length;
      (native as List).add(child(value[i], '[$i]', '[$i]'));
      normalized.add(nodes[childIndex].value);
    }
    display = normalized;
  } else if (value is TomlDateTime ||
      value is BigInt ||
      value is double && !value.isFinite) {
    display = value.toString();
  }
  nodes[index] = JsonNode(
    path,
    label,
    range.start,
    range.end,
    depth,
    parent,
    display,
    keyStart: range.keyStart,
  );
  return native;
}

// Reuse the TOML grammar to find statement and value offsets, including
// multiline strings and arrays. Inline descendants inherit the value range.
Map<String, dynamic> _parseToml(String text, Map<String, _Range> ranges) {
  final expressions = TomlExpression.parser
      .token()
      .plusSeparated(tomlNewline)
      .end()
      .parse(text)
      .valueOrTomlException
      .elements;
  final document = TomlDocument(
    expressions.map((token) => token.value).nonNulls,
  ).toMap();
  final arrayIndices = <String, int>{};
  var table = r'$';
  for (final token in expressions) {
    final expression = token.value;
    if (expression is TomlTable) {
      table = r'$';
      for (final (index, part) in expression.name.parts.indexed) {
        table += '[${jsonEncode(part.name)}]';
        if (index == expression.name.parts.length - 1 &&
            expression is TomlArrayTable) {
          arrayIndices.update(table, (i) => i + 1, ifAbsent: () => 0);
          ranges.putIfAbsent(
            table,
            () => (start: token.start, end: token.stop, keyStart: null),
          );
        }
        final arrayIndex = arrayIndices[table];
        if (arrayIndex != null) table += '[$arrayIndex]';
      }
      ranges[table] = (start: token.start, end: token.stop, keyStart: null);
    } else if (expression is TomlKeyValuePair) {
      final key = TomlKey.parser
          .trim(tomlWhitespaceChar)
          .parseOn(Context(text, token.start));
      final start = key.position + 1;
      final parsed = TomlValue.parser
          .trim(tomlWhitespaceChar)
          .token()
          .parseOn(Context(text, start));
      final value = parsed.value;
      final suffix = expression.key.parts
          .map((p) => '[${jsonEncode(p.name)}]')
          .join();
      ranges['$table$suffix'] = (
        start: value.start,
        end: value.stop,
        keyStart: token.start,
      );
    }
  }
  return document;
}
