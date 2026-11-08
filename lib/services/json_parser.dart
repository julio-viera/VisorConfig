import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../models/config_format.dart';
import '../models/json_document.dart';
import 'config_parser.dart';
import 'key_value_config.dart';
import '../models/json_standard.dart';

ParseResult parseDocument(Map<String, String> request) {
  var text = request['text']!;
  final format = ConfigFormat.values.byName(request['format'] ?? 'json');
  if (text.length > 32 * 1024 * 1024) {
    return ParseResult(
      format: format,
      error: 'Document exceeds the size limit',
    );
  }
  if (format == ConfigFormat.json && text.trim().isEmpty) {
    return ParseResult(format: format, error: 'Empty document', offset: 0);
  }
  if (format.keyValue) return parseKeyValueConfig(text, format);
  if (format != ConfigFormat.json) return parseConfig(text, format);
  try {
    if (request['standard'] == jsonSchemaWithComments) {
      text = _maskComments(text);
    }
    final scanner = _Scanner(text);
    final dynamic value;
    try {
      value = scanner.scan(null, r'$', r'$', 0, -1);
      scanner.ws();
      if (scanner.pos != text.length) scanner.invalid();
    } on _JsonSyntax {
      // Retain Dart's existing syntax diagnostics and document offsets.
      _checkStructure(text);
      jsonDecode(text);
      rethrow;
    }
    final issues = [...scanner.issues];
    if (usesJsonSchema(request['standard']) &&
        request['schema']!.trim().isNotEmpty) {
      try {
        var source = request['schema']!;
        if (source.length > 1024 * 1024) {
          throw const FormatException('Schema exceeds 1 MiB');
        }
        if (request['standard'] == jsonSchemaWithComments) {
          source = _maskComments(source);
        }
        _checkStructure(source, maxDepth: 128, maxNodes: 20000);
        final schema = JsonSchema.create(jsonDecode(source));
        final validation = schema.validate(value);
        issues.addAll(validation.errors.map((e) => e.toString()));
      } catch (e) {
        issues.add('Schema: $e');
      }
    }
    return ParseResult(
      value: value,
      nodes: scanner.nodes,
      issues: issues,
      hasDuplicateKeys: scanner.issues.isNotEmpty,
    );
  } on FormatException catch (e) {
    return ParseResult(error: e.message, offset: e.offset);
  } catch (e) {
    return ParseResult(error: e.toString());
  }
}

// Bound allocations before jsonDecode constructs any containers.
void _checkStructure(
  String source, {
  int maxDepth = 256,
  int maxNodes = 100000,
}) {
  var depth = 0, nodes = 1;
  var quoted = false;
  for (var i = 0; i < source.length; i++) {
    final char = source.codeUnitAt(i);
    if (quoted && char == 92) {
      i++;
    } else if (char == 34) {
      quoted = !quoted;
    } else if (!quoted) {
      if (char == 91 || char == 123) {
        depth++;
        nodes++;
      } else if (char == 93 || char == 125) {
        depth--;
      } else if (char == 44) {
        nodes++;
      }
      if (depth > maxDepth || nodes > maxNodes) {
        throw FormatException(
          'Document exceeds the depth or node limit',
          source,
          i,
        );
      }
    }
  }
}

// Preserve UTF-16 offsets and line breaks for selection and node editing.
String _maskComments(String source) {
  final output = StringBuffer();
  var copied = 0;
  var inString = false;
  for (var i = 0; i < source.length; i++) {
    final char = source.codeUnitAt(i);
    if (inString && char == 92) {
      i++;
    } else if (char == 34) {
      inString = !inString;
    } else if (!inString && char == 47 && i + 1 < source.length) {
      final next = source.codeUnitAt(i + 1);
      if (next != 47 && next != 42) continue;
      var end = i + 2;
      if (next == 42) {
        final close = source.indexOf('*/', end);
        if (close < 0) {
          throw FormatException('Unterminated block comment', source, i);
        }
        end = close + 2;
      } else {
        while (end < source.length &&
            source.codeUnitAt(end) != 10 &&
            source.codeUnitAt(end) != 13) {
          end++;
        }
      }
      output.write(source.substring(copied, i));
      for (var j = i; j < end; j++) {
        final unit = source.codeUnitAt(j);
        output.writeCharCode(unit == 10 || unit == 13 ? unit : 32);
      }
      copied = end;
      i = end - 1;
    }
  }
  if (copied == 0) return source;
  output.write(source.substring(copied));
  return output.toString();
}

class _JsonSyntax extends FormatException {
  _JsonSyntax(String text, int offset) : super('Invalid JSON', text, offset);
}

class _Scanner {
  _Scanner(this.text);
  final String text;
  int pos = 0;
  int _structuralNodes = 1;
  final nodes = <JsonNode>[];
  final issues = <String>[];
  void ws() {
    while (pos < text.length && ' \n\r\t'.contains(text[pos])) {
      pos++;
    }
  }

  Never invalid() => throw _JsonSyntax(text, pos);

  String? get current => pos < text.length ? text[pos] : null;

  void expect(String character) {
    if (current != character) invalid();
    pos++;
  }

  void string() {
    expect('"');
    while (pos < text.length) {
      if (text[pos] == '\\') {
        pos += 2;
      } else if (text[pos++] == '"') {
        return;
      }
    }
    invalid();
  }

  dynamic scalar(int start) {
    try {
      return jsonDecode(text.substring(start, pos));
    } on FormatException {
      invalid();
    }
  }

  void _countStructure(int depth) {
    if (++_structuralNodes > 100000 || depth > 256) {
      throw FormatException(
        'Document exceeds the depth or node limit',
        text,
        pos,
      );
    }
  }

  dynamic scan(
    int? keyStart,
    String path,
    String label,
    int depth,
    int parent,
  ) {
    ws();
    if (depth > 256 || nodes.length >= 100000) {
      throw FormatException(
        'Document exceeds the depth or node limit',
        text,
        pos,
      );
    }
    final start = pos, index = nodes.length;
    nodes.add(JsonNode(path, label, start, start, depth, parent, null));
    dynamic value;
    if (current == '{') {
      _countStructure(depth + 1);
      value = <String, dynamic>{};
      pos++;
      ws();
      if (current != '}') {
        while (true) {
          final keyStart = pos;
          string();
          final key = scalar(keyStart) as String;
          if (value.containsKey(key)) issues.add('Duplicate key: $path → $key');
          ws();
          expect(':');
          value[key] = scan(
            keyStart,
            '$path[${jsonEncode(key)}]',
            key,
            depth + 1,
            index,
          );
          ws();
          if (current != ',') break;
          _countStructure(depth);
          pos++;
          ws();
        }
      }
      expect('}');
    } else if (current == '[') {
      _countStructure(depth + 1);
      value = <dynamic>[];
      pos++;
      ws();
      if (current != ']') {
        while (true) {
          final i = (value as List).length;
          value.add(scan(null, '$path[$i]', '[$i]', depth + 1, index));
          ws();
          if (current != ',') break;
          _countStructure(depth);
          pos++;
          ws();
        }
      }
      expect(']');
    } else {
      if (current == '"') {
        string();
      } else {
        while (pos < text.length && !',]} \r\n\t'.contains(text[pos])) {
          pos++;
        }
      }
      value = scalar(start);
      if (value is double && !value.isFinite) {
        throw FormatException(
          'Number outside supported finite range',
          text,
          start,
        );
      }
    }
    nodes[index] = JsonNode(
      path,
      label,
      start,
      pos,
      depth,
      parent,
      value,
      keyStart: keyStart,
    );
    return value;
  }
}
