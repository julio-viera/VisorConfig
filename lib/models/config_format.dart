import 'dart:convert';

enum ConfigFormat {
  json,
  yaml,
  toml,
  ini,
  dotenv,
  properties;

  bool get keyValue => this == ini || this == dotenv || this == properties;
  String get extension => this == dotenv ? 'env' : name;
  String get label => extension.toUpperCase();

  static ConfigFormat? fromPath(String? path) {
    final extension = path == null
        ? null
        : _extension.firstMatch(path)?.group(1)?.toLowerCase();
    return switch (extension) {
      'json' || 'jsonc' || 'jsonld' || 'geojson' => json,
      'yaml' || 'yml' => yaml,
      'toml' => toml,
      'ini' || 'cfg' => ini,
      'env' => dotenv,
      'properties' => properties,
      _ when path != null && _dotenvFile.hasMatch(path) => dotenv,
      _ => null,
    };
  }

  static ConfigFormat detect(String text) {
    // Limit the work done on the UI thread while a document is being edited.
    final sample = text.substring(0, text.length.clamp(0, 8192)).trimLeft();
    final content = sample.replaceFirst(_leadingComments, '');
    if (_dotenvExport.hasMatch(content)) return dotenv;
    if (content.startsWith(';')) return ini;
    if (content.startsWith('!')) return properties;
    final flow = content.startsWith('{') || content.startsWith('[');
    if (flow && text.length <= 8192 && sample == content) {
      try {
        jsonDecode(content);
        return json;
      } on FormatException {
        // Inspect the syntax markers when JSON is incomplete or invalid.
      }
    }
    if (_tomlAssignment.hasMatch(content) ||
        _tomlHeader.hasMatch(content) && !_jsonArrayStart.hasMatch(content)) {
      return toml;
    }
    if (content.startsWith('---') ||
        content.startsWith('%YAML') ||
        _yamlSequence.hasMatch(content) ||
        _yamlFlow.hasMatch(content) ||
        !flow && _yamlMapping.hasMatch(content)) {
      return yaml;
    }
    return json;
  }

  static final _dotenvFile = RegExp(
    r'(?:^|[/\\])\.env\.[\w.-]+$',
    caseSensitive: false,
  );
  static final _dotenvExport = RegExp(
    r'^export[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=',
  );
  static final _extension = RegExp(r'\.([a-zA-Z]+)$');
  static final _leadingComments = RegExp(r'^(?:\s*#[^\n]*(?:\n|$)\s*)+');
  static final _tomlAssignment = RegExp(
    r'''^(?:[\w-]+|"[^"\n]*"|'[^'\n]*')(?:[ \t]*\.[ \t]*(?:[\w-]+|"[^"\n]*"|'[^'\n]*'))*[ \t]*=''',
  );
  static final _tomlHeader = RegExp(
    r'''^\[\[?(?:[\w-]+|"[^"\n]*"|'[^'\n]*')(?:[ \t]*\.[ \t]*(?:[\w-]+|"[^"\n]*"|'[^'\n]*'))*[ \t]*\]\]?(?:[ \t]*#.*)?[ \t]*(?:\r?\n|$)''',
  );
  static final _jsonArrayStart = RegExp(
    r'^\[[ \t]*(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)[ \t]*\]',
  );
  static final _yamlFlow = RegExp(
    r'''^\{[ \t]*(?:[\w-]+|'[^'\n]*')[ \t]*:|^\[[ \t]*[a-zA-Z][\w -]*,''',
  );
  static final _yamlSequence = RegExp(r'^-(?:[ \t]|\r?\n|$)');
  static final _yamlMapping = RegExp(r'^[^\n]+?:[ \t\r\n]|^[^\n]+?:$');
}
