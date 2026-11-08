import 'package:visor_config/themes/code_palette.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/models/json_document.dart';
import 'package:visor_config/services/document_search.dart';
import 'package:visor_config/services/graph_renderer.dart';
import 'package:visor_config/services/json_parser.dart';
import 'package:visor_config/utils/document_export.dart';
import 'package:visor_config/utils/json_diff.dart';
import 'package:visor_config/utils/source_segments.dart';

ParseResult parse(String text, {String schema = ''}) =>
    parseDocument({'text': text, 'schema': schema, 'standard': 'JSON Schema'});
void main() {
  test('Comment mode preserves source offsets and validates JSON Schema', () {
    const source =
        '{/* 😀 */ "url":"https://example.org", // line\n "count":2}';
    final result = parseDocument({
      'text': source,
      'standard': 'JSON Schema - With comments',
      'schema': '{/* schema */ "required":["missing"]}',
    });
    expect(result.error, isNull);
    expect(result.issues, isNotEmpty);
    expect(result.value['url'], 'https://example.org');
    expect(result.nodes.last.start, source.lastIndexOf('2'));
    expect(parse(source).error, isNotNull);
    final unfinished = parseDocument({
      'text': '{} /* unfinished',
      'standard': 'JSON Schema - With comments',
      'schema': '',
    });
    expect(unfinished.offset, 3);
  });

  test(
    'Tracks exact source ranges through escaping, whitespace and nested values',
    () {
      const text = ' { "a\\"b": [null, {"x": "ñ\\n"}], "n": -2.3e4 } ';
      final result = parse(text);
      expect(result.error, isNull);
      for (final node in result.nodes) {
        expect(jsonDecode(text.substring(node.start, node.end)), node.value);
      }
      expect(result.nodes[2].value, isNull);
    },
  );
  test(
    'Retains ranges for duplicate keys and handles finite numeric limits',
    () {
      const text = '{"a": [1,2], "a": {"b":3}}';
      final result = parse(text);
      expect(result.error, isNull);
      for (final node in result.nodes) {
        expect(jsonDecode(text.substring(node.start, node.end)), node.value);
      }
      expect(parse('1e400').error, isNotNull);
    },
  );
  test('Text search counts occurrences, including invalid input', () {
    final result = parse('{"a":"x x","b":"x"}');
    final matches = searchText('{"a":"x x","b":"x"}', result.nodes, 'x');
    expect(matches, hasLength(3));
    expect(matches[0].path, r'$["a"]');
    expect(matches[2].path, r'$["b"]');
    expect(searchText('invalid invalid', [], 'invalid'), hasLength(2));
  });
  test('Single-pass validation retains Dart JSON syntax offsets', () {
    for (final source in [
      '{"a":1,}',
      '[1,]',
      '{"a" 1}',
      '[1 2]',
      '{} true',
      '{"a":"x',
    ]) {
      try {
        jsonDecode(source);
        fail('The fixture must be invalid JSON');
      } on FormatException catch (expected) {
        final result = parse(source);
        expect(result.error, expected.message, reason: source);
        expect(result.offset, expected.offset, reason: source);
      }
    }
  });
  test('Reports syntax location and validates an actual schema', () {
    expect(parse('{"a": }').offset, isNotNull);
    expect(
      parse('{"a":1}', schema: '{"type":"object","required":["name"]}').issues,
      isNotEmpty,
    );
    expect(
      parse(
        '{"name":"Julio"}',
        schema: '{"type":"object","required":["name"]}',
      ).valid,
      isTrue,
    );
    expect(parse('null').valid, isTrue);
    expect(parse('').valid, isFalse);
  });
  test('JSONPath distinguishes equal values in different branches', () {
    final result = parse('{"a":[1,1],"b":1}');
    expect(searchNodes(result, r'$.a[1]', true).single.path, r'$["a"][1]');
    expect(searchNodes(result, r'$.a[*]', true).length, 2);
  });
  test('CSV neutralizes spreadsheet formulas in headers and text values', () {
    expect(
      toCsv([
        {'=1+2': '  @SUM(A1)', 'number': -7},
      ]),
      '"\t=1+2","number"\r\n"\t  @SUM(A1)","-7"\r\n',
    );
  });
  test('Exports CSV only for uniform objects and quotes cells', () {
    expect(
      toCsv([
        {'name': 'a,"b', 'n': 2},
      ]),
      contains('"a,""b"'),
    );
    expect(
      () => toCsv([
        {'a': 1},
        {'b': 2},
      ]),
      throwsFormatException,
    );
    expect(
      toYaml({
        'items': [true, null],
      }),
      contains('  - null'),
    );
  });
  test(
    'Diff ignores object key order and detects missing null and array changes',
    () {
      expect(diffJson({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isEmpty);
      expect(diffJson({'a': null}, {}), hasLength(1));
      expect(diffJson([1, 2], [1, 3, 4]), hasLength(2));
    },
  );
  test('Segments minified files without splitting surrogate pairs', () {
    final text = '${'a' * 4095}😀b\nlast';
    final segments = splitSource(text);
    expect(
      segments.map((s) => text.substring(s.start, s.end)).join(),
      text.replaceAll('\n', ''),
    );
    expect(segments[0].end, 4095);
    expect(segments.last.line, 2);
  });
  test('Graph colors follow depth and the selected theme', () {
    final nodes = parse('{"leaf":1,"branch":{"nested":2}}').nodes;
    final jade = GraphLayout(nodes);
    final ocean = GraphLayout(
      nodes,
      palette: const CodePalette(false, variant: 'ocean'),
    );
    expect(jade.fills[nodes[1].path], jade.fills[nodes[2].path]);
    expect(jade.fills[nodes[2].path], isNot(jade.fills[nodes[3].path]));
    expect(jade.fills[nodes.first.path], isNot(ocean.fills[nodes.first.path]));
  });
  testWidgets('Exports graph to escaped SVG and decodable PNG bytes', (
    tester,
  ) async {
    final result = parse('{"a&b":"<value>"}');
    final layout = GraphLayout(result.nodes);
    expect(layout.svg(), contains('a&amp;b'));
    expect(layout.svg(), contains('&lt;value&gt;'));
    final bytes = await tester.runAsync(layout.png);
    expect(bytes!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
