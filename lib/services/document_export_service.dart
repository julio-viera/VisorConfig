import '../themes/code_palette.dart';

import 'dart:convert';
import 'dart:isolate';

import '../models/config_format.dart';
import '../models/json_document.dart';
import '../utils/document_export.dart';
import 'graph_renderer.dart';
import 'key_value_config.dart';

/// Produces export bytes without opening file choosers or writing files.
class DocumentExportService {
  Future<List<int>> encode(
    dynamic value,
    List<JsonNode> graphNodes,
    String kind, {
    CodePalette palette = const CodePalette(false),
    dynamic nativeValue,
    bool radial = false,
    bool diagram = false,
  }) async {
    return switch (kind) {
      'svg' => utf8.encode(
        GraphLayout(
          graphNodes.take(2000).toList(),
          palette: palette,
          radial: radial,
          diagram: diagram,
        ).svg(),
      ),
      'png' => GraphLayout(
        graphNodes.take(2000).toList(),
        palette: palette,
        radial: radial,
        diagram: diagram,
      ).png(),
      _ => _encodeText(
        kind,
        kind == 'yaml' || kind == 'toml' ? nativeValue ?? value : value,
      ),
    };
  }
}

const _maxExportBytes = 32 * 1024 * 1024;
const _exportTooLarge = FormatException('Export exceeds the 32 MiB limit');

Future<List<int>> _encodeText(String kind, Object? value) => Isolate.run(() {
  // Charge each occurrence, even when YAML aliases share the same string.
  // Estimate before building output to prevent large temporary allocations.
  var remaining = _maxExportBytes;
  final stringSizes = Map<String, int>.identity();
  int stringSize(String text) => stringSizes.putIfAbsent(text, () {
    var size = 2;
    for (final code in text.codeUnits) {
      size += code < 32 || code == 127 || kind == 'properties' && code > 126
          ? 6
          : code == 34 || code == 92
          ? 4
          : code <= 127
          ? 1
          : code <= 2047
          ? 2
          : 3;
    }
    return size;
  });

  void charge(int bytes) {
    remaining -= bytes;
    if (remaining < 0) throw _exportTooLarge;
  }

  void visit(Object? node, int depth, int tablePathBytes) {
    charge(4 + 2 * depth + tablePathBytes);
    switch (node) {
      case Map<Object?, Object?> map:
        for (final entry in map.entries) {
          final keyBytes = entry.key is String
              ? stringSize(entry.key as String)
              : 32;
          charge(keyBytes);
          visit(
            entry.value,
            depth + 1,
            kind == 'toml' ? tablePathBytes + keyBytes : 0,
          );
        }
      case List<Object?> list:
        for (final item in list) {
          visit(item, depth + 1, tablePathBytes);
        }
      case String text:
        charge(stringSize(text));
      default:
        charge(32);
    }
  }

  visit(value, 0, 0);
  final text = switch (kind) {
    'yaml' => toYaml(value),
    'toml' => toToml(value),
    'csv' => toCsv(value),
    'ini' || 'dotenv' || 'properties' => encodeKeyValueConfig(
      value,
      ConfigFormat.values.byName(kind),
    ),
    _ => const JsonEncoder.withIndent('  ').convert(value),
  };
  final bytes = utf8.encode(text);
  if (bytes.length > _maxExportBytes) throw _exportTooLarge;
  return bytes;
});
