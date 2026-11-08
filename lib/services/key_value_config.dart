import 'dart:convert';

import '../models/config_format.dart';
import '../models/json_document.dart';

final _lineBreak = RegExp(r'\r\n?|\n');
final _propertyKey = RegExp(r'^(?:\\.|[^\\=: \t\f])*');
final _propertySeparator = RegExp(r'^[ \t\f]*(?:[=:][ \t\f]*)?');
final _dotenvKey = RegExp(
  r'^(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*',
);
final _envName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final _iniKey = RegExp(r'^([^=:\[\]]+)[=:][ \t]*');
final _iniSection = RegExp(r'^\[([^\]]+)\][ \t]*(?:[;#].*)?$');
final _propertySpace = RegExp(r'^[ \t\f]+');
final _unicodeHex = RegExp(r'^[a-fA-F0-9]{4}$');
final _propertyEscape = RegExp(r'\\(u.{0,4}|.)');

ParseResult parseKeyValueConfig(String text, ConfigFormat format) {
  final value = <String, Object>{};
  final nodes = <JsonNode>[JsonNode(r'$', r'$', 0, text.length, 0, -1, value)];
  final issues = <String>[];
  var section = value, parent = 0, start = 0;

  void closeSection(int end) {
    if (parent == 0) return;
    final node = nodes[parent];
    nodes[parent] = JsonNode(
      node.path,
      node.label,
      node.start,
      end,
      1,
      0,
      section,
    );
  }

  try {
    while (start < text.length) {
      final lineStart = start;
      final lineBreak = _lineBreak.matchAsPrefix(text, start);
      if (lineBreak != null) {
        start = lineBreak.end;
        continue;
      }
      var end = text.indexOf(_lineBreak, start);
      if (end < 0) end = text.length;
      var line = text.substring(start, end);
      if (start == 0 && line.startsWith('\uFEFF')) line = line.substring(1);
      line = format == ConfigFormat.properties
          ? line.replaceFirst(_propertySpace, '')
          : line.trimLeft();
      start = end;
      if (line.isEmpty ||
          line.startsWith('#') ||
          format == ConfigFormat.ini && line.startsWith(';') ||
          format == ConfigFormat.properties && line.startsWith('!')) {
        continue;
      }
      if (nodes.length >= 100000) {
        throw FormatException(
          'Document exceeds the node limit',
          text,
          lineStart,
        );
      }
      if (format == ConfigFormat.ini && line.startsWith('[')) {
        final name = _iniSection.firstMatch(line.trimRight())?.group(1)?.trim();
        if (name == null || name.isEmpty) {
          throw FormatException('Invalid INI section', text, lineStart);
        }
        closeSection(lineStart);
        if (value.containsKey(name)) issues.add('Duplicate section: $name');
        section = <String, Object>{};
        value[name] = section;
        parent = nodes.length;
        nodes.add(
          JsonNode(
            '\$[${jsonEncode(name)}]',
            name,
            lineStart,
            end,
            1,
            0,
            section,
          ),
        );
        continue;
      }

      final String key, entry;
      var entryStart = lineStart;
      int? entryEnd;
      if (format == ConfigFormat.properties) {
        final logical = StringBuffer();
        while (_continues(line)) {
          logical.write(line.substring(0, line.length - 1));
          if (end == text.length) {
            line = '';
            break;
          }
          final next = _lineBreak.matchAsPrefix(text, end)!.end;
          end = text.indexOf(_lineBreak, next);
          if (end < 0) end = text.length;
          line = text.substring(next, end).replaceFirst(_propertySpace, '');
        }
        line = (logical..write(line)).toString();
        final keyEnd = _propertyKey.firstMatch(line)!.end;
        final rawValue = line
            .substring(keyEnd)
            .replaceFirst(_propertySeparator, '');
        key = _decodeProperty(line.substring(0, keyEnd), text, lineStart);
        entry = _decodeProperty(rawValue, text, lineStart);
      } else if (format == ConfigFormat.dotenv) {
        final match = _dotenvKey.firstMatch(line);
        if (match == null) {
          throw FormatException('Invalid dotenv assignment', text, lineStart);
        }
        key = match.group(1)!;
        final raw = line.substring(match.end);
        entryStart = end - raw.length;
        if (raw.isNotEmpty && '"\x27\x60'.contains(raw[0])) {
          final quote = raw[0];
          final valueStart = entryStart;
          var close = valueStart + 1;
          final decoded = StringBuffer();
          while (close < text.length && text[close] != quote) {
            final char = text[close++];
            if (quote == '"' && char == '\\' && close < text.length) {
              final next = text[close++];
              decoded.write(switch (next) {
                'n' => '\n',
                'r' => '\r',
                '"' || '\\' || r'$' || '\x60' => next,
                _ => '\\$next',
              });
            } else {
              decoded.write(char);
            }
          }
          if (close == text.length) {
            throw FormatException(
              'Unterminated dotenv value',
              text,
              valueStart,
            );
          }
          end = text.indexOf(_lineBreak, close + 1);
          if (end < 0) end = text.length;
          final suffix = text.substring(close + 1, end).trim();
          if (suffix.isNotEmpty && !suffix.startsWith('#')) {
            throw FormatException(
              'Unexpected text after dotenv value',
              text,
              close + 1,
            );
          }
          entry = decoded.toString();
          entryEnd = close + 1;
        } else {
          final comment = raw.indexOf('#');
          entry = (comment < 0 ? raw : raw.substring(0, comment)).trimRight();
          entryEnd = entryStart + entry.length;
        }
      } else {
        final match = _iniKey.firstMatch(line);
        if (match == null) {
          throw FormatException('Invalid INI assignment', text, lineStart);
        }
        key = match.group(1)!.trim();
        final raw = line.substring(match.end);
        entry = raw.trimRight();
        entryStart = end - raw.length;
        entryEnd = entryStart + entry.length;
      }
      start = end;
      if (section.containsKey(key)) issues.add('Duplicate key: $key');
      section[key] = entry;
      nodes.add(
        JsonNode(
          '${nodes[parent].path}[${jsonEncode(key)}]',
          key,
          entryStart,
          entryEnd ?? end,
          parent == 0 ? 1 : 2,
          parent,
          entry,
          keyStart: lineStart,
        ),
      );
    }
    closeSection(text.length);
    return ParseResult(
      format: format,
      value: value,
      nodes: nodes,
      issues: issues,
      hasDuplicateKeys: issues.isNotEmpty,
    );
  } on FormatException catch (error) {
    return ParseResult(
      format: format,
      error: error.message,
      offset: error.offset,
    );
  }
}

bool _continues(String line) {
  var cursor = line.length;
  while (cursor > 0 && line.codeUnitAt(cursor - 1) == 92) {
    cursor--;
  }
  return (line.length - cursor).isOdd;
}

String _decodeProperty(String value, String source, int offset) =>
    value.replaceAllMapped(_propertyEscape, (match) {
      final escape = match[1]!;
      if (escape.startsWith('u')) {
        final hex = escape.substring(1);
        if (!_unicodeHex.hasMatch(hex)) {
          throw FormatException(
            'Invalid properties Unicode escape',
            source,
            offset,
          );
        }
        return String.fromCharCode(int.parse(hex, radix: 16));
      }
      return switch (escape) {
        't' => '\t',
        'n' => '\n',
        'r' => '\r',
        'f' => '\f',
        _ => escape,
      };
    });

String encodeKeyValueConfig(Object? value, ConfigFormat format) {
  if (value is! Map) {
    throw const FormatException('This format requires an object');
  }
  final output = StringBuffer();
  for (final entry in value.entries) {
    if (format != ConfigFormat.ini || entry.value is! Map) {
      output.writeln(encodeKeyValueEntry(entry.key, entry.value, format));
    }
  }
  if (format == ConfigFormat.ini) {
    for (final entry in value.entries) {
      if (entry.value case final Map section) {
        final name = entry.key;
        if (name is! String ||
            name.isEmpty ||
            name != name.trim() ||
            name.contains(']') ||
            name.contains(_lineBreak)) {
          throw const FormatException('Invalid INI section name');
        }
        output.writeln('[$name]');
        for (final field in section.entries) {
          output.writeln(encodeKeyValueEntry(field.key, field.value, format));
        }
      }
    }
  }
  return output.toString();
}

String encodeKeyValueEntry(Object? key, Object? value, ConfigFormat format) {
  if (key is! String || value is! String && value is! num && value is! bool) {
    throw const FormatException(
      'This format requires scalar values and string keys',
    );
  }
  final text = value.toString();
  switch (format) {
    case ConfigFormat.ini:
      if (key.isEmpty ||
          key != key.trim() ||
          key.startsWith('#') ||
          key.startsWith(';') ||
          key.contains(RegExp(r'[\r\n=:\[\]]')) ||
          text.contains(_lineBreak) ||
          text.trim() != text) {
        throw const FormatException(
          'Key or value cannot be represented in INI',
        );
      }
      return '$key=$text';
    case ConfigFormat.dotenv:
      if (!_envName.hasMatch(key)) {
        throw const FormatException('Invalid dotenv variable name');
      }
      if (!text.contains("'")) return "$key='$text'";
      final escaped = text
          .replaceAll('\\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll(r'$', r'\$')
          .replaceAll('\x60', '\\\x60')
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r');
      return '$key="$escaped"';
    case ConfigFormat.properties:
      return '${_encodeProperty(key)}=${_encodeProperty(text)}';
    default:
      throw ArgumentError.value(format);
  }
}

String _encodeProperty(String text) {
  final output = StringBuffer();
  for (final code in text.codeUnits) {
    final char = String.fromCharCode(code);
    if (' =:#!\\'.contains(char)) {
      output.write('\\$char');
    } else if (code < 32 || code > 126) {
      output.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
    } else {
      output.write(char);
    }
  }
  return output.toString();
}
