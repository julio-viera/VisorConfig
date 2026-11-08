import 'dart:convert';

import 'package:toml/toml.dart';

String toToml(dynamic value) {
  if (value is! Map) {
    throw const FormatException(
      'TOML requires an object at the document root.',
    );
  }
  if (_containsNull(value)) {
    throw const FormatException('TOML cannot represent null values.');
  }
  return TomlDocument.fromMap(value).toString();
}

bool _containsNull(dynamic value) => switch (value) {
  null => true,
  Map map => map.values.any(_containsNull),
  List list => list.any(_containsNull),
  _ => false,
};

String _yamlScalar(dynamic value) => switch (value) {
  final double n when n.isNaN => '.nan',
  double.infinity => '.inf',
  double.negativeInfinity => '-.inf',
  TomlDateTime date => jsonEncode(date.toString()),
  _ => jsonEncode(value),
};

String toYaml(dynamic value, [int depth = 0]) {
  final indent = '  ' * depth;
  if (value is Map) {
    if (value.isEmpty) return '$indent{}\n';
    return value.entries
        .map(
          (e) => e.value is Map || e.value is List
              ? '$indent${_yamlScalar(e.key)}:\n${toYaml(e.value, depth + 1)}'
              : '$indent${_yamlScalar(e.key)}: ${_yamlScalar(e.value)}\n',
        )
        .join();
  }
  if (value is List) {
    if (value.isEmpty) return '$indent[]\n';
    return value
        .map(
          (v) => v is Map || v is List
              ? '$indent-\n${toYaml(v, depth + 1)}'
              : '$indent- ${_yamlScalar(v)}\n',
        )
        .join();
  }
  return '$indent${_yamlScalar(value)}\n';
}

List<String>? tableColumns(dynamic value) {
  if (value is! List || value.isEmpty || value.any((v) => v is! Map)) {
    return null;
  }
  final keys = (value.first as Map).keys.cast<String>().toList();
  if (value.any(
    (v) => (v as Map).length != keys.length || !keys.every(v.containsKey),
  )) {
    return null;
  }
  return keys;
}

String toCsv(dynamic value) {
  final keys = tableColumns(value);
  if (keys == null) {
    throw const FormatException('CSV requiere un array de objetos uniformes');
  }
  String cell(dynamic value) {
    var text = value is String ? value : jsonEncode(value);
    if (value is String && _spreadsheetFormula.hasMatch(text)) {
      text = '\t$text';
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return '${keys.map(cell).join(',')}\r\n${(value as List).map((row) => keys.map((key) => cell(row[key])).join(',')).join('\r\n')}\r\n';
}

final _spreadsheetFormula = RegExp(r'^\s*[=+\-@＝＋－＠]');
