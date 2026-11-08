import 'package:flutter/material.dart';

import '../models/config_format.dart';
import '../themes/code_palette.dart';

class JsonEditorController extends TextEditingController {
  JsonEditorController({super.text});
  String query = '';
  ConfigFormat format = ConfigFormat.json;
  bool jsonComments = false;
  static const _jsonPattern =
      r'"(?:[^"\x5c]|\x5c.)*"|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?';
  static final _jsonTokens = RegExp(_jsonPattern);
  static final _jsonCommentTokens = RegExp(
    r'//[^\n]*|/\*[\s\S]*?(?:\*/|$)|' + _jsonPattern,
  );
  static final _iniTokens = RegExp(
    r'^([ \t]*[;#][^\r\n]*|[ \t]*\[[^\]\r\n]*\])|^([^=:\r\n]+[=:])([^\r\n]*)',
    multiLine: true,
  );
  static final _envTokens = RegExp(
    r'^([ \t]*#[^\r\n]*)|^([ \t]*(?:export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=)([^\r\n]*)',
    multiLine: true,
  );
  static final _propertiesTokens = RegExp(
    r'^([ \t\f]*[#!][^\r\n]*)|^([ \t\f]*(?:\x5c[^\r\n]|[^\x5c=: \t\f\r\n])+(?:[=: \t\f]|$))([^\r\n]*)',
    multiLine: true,
  );
  static final _yamlTokens = RegExp(
    r'''("(?:[^"\x5c]|\x5c.)*"|'(?:[^']|'')*')|(^[ \t]*(?:- +)?[^\s:#{}\[\],][^:#{}\[\],\n]*?(?=:[ \t\r\n]|:$))|(#[^\n]*)|([&*!][\w.-]+)|(\b(?:true|false|null|True|False|Null|TRUE|FALSE|NULL)\b|~)|([+-]?(?:0[xo][0-9a-fA-F_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?[\d_]+)?))|((?<=: )[^\s\[\]{},#][^\n#\[\]{},]*)''',
    multiLine: true,
  );
  static final _tomlTokens = RegExp(
    r"""("{3}[\s\S]*?"{3}|'{3}[\s\S]*?'{3}|"(?:[^"\x5c]|\x5c.)*"|'[^'\n]*')|(^[ \t]*\[\[?[^\]\n]+\]\]?)|([\w-]+(?=[ \t]*[.=]))|(#[^\n]*)|(\b(?:true|false)\b)|([+-]?(?:inf|nan|0[xob][0-9a-fA-F_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?[\d_]+)?))|([\w-]+)""",
    multiLine: true,
  );
  List<TextRange> _ranges = [];
  List<TextRange> get ranges => _ranges;
  set ranges(List<TextRange> value) {
    final sorted = [...value]..sort((a, b) => a.start.compareTo(b.start));
    _ranges = [];
    for (final range in sorted) {
      if (_ranges.isNotEmpty && range.start <= _ranges.last.end) {
        final previous = _ranges.removeLast();
        _ranges.add(
          TextRange(
            start: previous.start,
            end: range.end > previous.end ? range.end : previous.end,
          ),
        );
      } else {
        _ranges.add(range);
      }
    }
  }

  void refresh() => notifyListeners();
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Keep editing responsive for large inputs; syntax coloring is bounded.

    final palette = CodePalette.of(context);
    final pattern = switch (format) {
      ConfigFormat.json => jsonComments ? _jsonCommentTokens : _jsonTokens,
      ConfigFormat.yaml => _yamlTokens,
      ConfigFormat.toml => _tomlTokens,
      ConfigFormat.ini => _iniTokens,
      ConfigFormat.dotenv => _envTokens,
      ConfigFormat.properties => _propertiesTokens,
    };
    final spans = <TextSpan>[];
    var absolute = 0;
    var rangeIndex = 0;
    void append(String part, TextStyle? tokenStyle) {
      final begin = absolute;
      absolute += part.length;
      if (ranges.isNotEmpty) {
        var cursor = 0;
        while (rangeIndex < ranges.length && ranges[rangeIndex].end <= begin) {
          rangeIndex++;
        }
        for (
          var i = rangeIndex;
          i < ranges.length && ranges[i].start < absolute;
          i++
        ) {
          final range = ranges[i];
          final start = (range.start - begin).clamp(0, part.length);
          final end = (range.end - begin).clamp(0, part.length);
          if (end <= start || end <= cursor) continue;
          if (start > cursor) {
            spans.add(
              TextSpan(text: part.substring(cursor, start), style: tokenStyle),
            );
          }
          spans.add(
            TextSpan(
              text: part.substring(start < cursor ? cursor : start, end),
              style: (tokenStyle ?? const TextStyle()).copyWith(
                backgroundColor: Colors.amber,
                color: Colors.black,
              ),
            ),
          );
          cursor = end;
        }
        spans.add(TextSpan(text: part.substring(cursor), style: tokenStyle));
        return;
      }
      if (query.isEmpty) {
        spans.add(TextSpan(text: part, style: tokenStyle));
        return;
      }
      var start = 0;
      for (final match in RegExp(
        RegExp.escape(query),
        caseSensitive: false,
      ).allMatches(part)) {
        if (match.start > start) {
          spans.add(
            TextSpan(
              text: part.substring(start, match.start),
              style: tokenStyle,
            ),
          );
        }
        spans.add(
          TextSpan(
            text: match.group(0),
            style: (tokenStyle ?? const TextStyle()).copyWith(
              backgroundColor: Colors.amber,
              color: Colors.black,
            ),
          ),
        );
        start = match.end;
      }
      spans.add(TextSpan(text: part.substring(start), style: tokenStyle));
    }

    var cursor = 0;
    for (final m
        in text.length > 500000 ? <RegExpMatch>[] : pattern.allMatches(text)) {
      append(text.substring(cursor, m.start), null);
      final token = m.group(0)!;
      if (format.keyValue) {
        if (m.group(1) case final header?) {
          append(
            header,
            TextStyle(
              color: header.trimLeft().startsWith('[')
                  ? palette.key
                  : palette.muted,
            ),
          );
        } else {
          append(m.group(2)!, TextStyle(color: palette.key));
          append(m.group(3)!, TextStyle(color: palette.string));
        }
        cursor = m.end;
        continue;
      }
      // Consume unrecognized words instead of retrying the key lookahead
      // from every character in the word.
      if (format == ConfigFormat.toml && m.group(7) != null) {
        append(token, null);
        cursor = m.end;
        continue;
      }
      var following = m.end;
      while (following < text.length && ' \r\n\t'.contains(text[following])) {
        following++;
      }
      final separator = format == ConfigFormat.toml ? '=' : ':';
      final quoted = token.startsWith('"') || token.startsWith("'");
      final quotedKey =
          quoted && following < text.length && text[following] == separator;
      final color = switch (format) {
        ConfigFormat.ini ||
        ConfigFormat.dotenv ||
        ConfigFormat.properties => palette.text,
        ConfigFormat.json =>
          token.startsWith('/')
              ? palette.muted
              : quotedKey
              ? palette.key
              : quoted
              ? palette.string
              : token == 'true' || token == 'false' || token == 'null'
              ? palette.literal
              : palette.number,
        ConfigFormat.yaml =>
          quotedKey || m.group(2) != null
              ? palette.key
              : (m.group(1) != null || m.group(7) != null)
              ? palette.string
              : m.group(3) != null
              ? palette.muted
              : m.group(6) != null
              ? palette.number
              : palette.literal,
        ConfigFormat.toml =>
          quotedKey || m.group(2) != null || m.group(3) != null
              ? palette.key
              : m.group(1) != null
              ? palette.string
              : m.group(4) != null
              ? palette.muted
              : m.group(5) != null
              ? palette.literal
              : palette.number,
      };
      append(token, TextStyle(color: color));
      cursor = m.end;
    }
    append(text.substring(cursor), null);
    return TextSpan(
      style: (style ?? const TextStyle()).copyWith(color: palette.text),
      children: spans,
    );
  }
}
