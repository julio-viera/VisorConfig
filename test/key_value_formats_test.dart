import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/controllers/editor_document_controller.dart';
import 'package:visor_config/models/config_format.dart';
import 'package:visor_config/models/json_standard.dart';
import 'package:visor_config/services/document_export_service.dart';
import 'package:visor_config/services/json_parser.dart';

void main() {
  test('Recognizes requested extensions, including dotenv basenames', () {
    expect(ConfigFormat.fromPath('settings.JSONC'), ConfigFormat.json);
    expect(ConfigFormat.fromPath('settings.INI'), ConfigFormat.ini);
    expect(ConfigFormat.fromPath('settings.cfg'), ConfigFormat.ini);
    expect(ConfigFormat.fromPath('.env'), ConfigFormat.dotenv);
    expect(ConfigFormat.fromPath(r'C:\work\.env.local'), ConfigFormat.dotenv);
    expect(ConfigFormat.fromPath('gradle.properties'), ConfigFormat.properties);
    expect(ConfigFormat.detect('export HOST=localhost'), ConfigFormat.dotenv);
  });

  test('JSONC selects comment validation automatically', () async {
    final document = EditorDocumentController(
      'settings.jsonc',
      path: '/tmp/settings.jsonc',
      text: '{/* comment */ "enabled": true}',
    );
    addTearDown(document.dispose);
    await document.validate();
    expect(document.standard, jsonSchemaWithComments);
    expect(document.editor.jsonComments, isTrue);
    expect(document.result!.value, {'enabled': true});
  });

  test('INI groups sections and reports duplicate keys', () {
    final result = parseDocument({
      'format': 'ini',
      'text':
          '; Comment\nname=example\n[server]\nport: 080\n[client]\nactive=true',
    });
    expect(result.error, isNull);
    expect(result.value, {
      'name': 'example',
      'server': {'port': '080'},
      'client': {'active': 'true'},
    });
    expect(result.byPath[r'$["server"]["port"]']!.parent, 2);
    final duplicate = parseDocument({'format': 'ini', 'text': 'x=1\nx=2'});
    expect(duplicate.hasDuplicateKeys, isTrue);
  });

  test('Dotenv retains literal variables and quoted multiline text', () {
    const text =
        'export URL="https://host/#fragment" # note\n'
        "MESSAGE='one\ntwo'\n"
        r'COMMAND=$(touch example)';
    final result = parseDocument({'format': 'dotenv', 'text': text});
    expect(result.error, isNull);
    expect(result.value, {
      'URL': 'https://host/#fragment',
      'MESSAGE': 'one\ntwo',
      'COMMAND': r'$(touch example)',
    });
    final node = result.byPath[r'$["URL"]']!;
    expect(text.substring(node.start, node.end), '"https://host/#fragment"');
  });

  test(
    'Structured dotenv edits preserve export and trailing comments',
    () async {
      final document = EditorDocumentController(
        '.env.local',
        text: 'export HOST=old # keep me',
      );
      addTearDown(document.dispose);
      await document.validate();
      final node = document.result!.byPath[r'$["HOST"]']!;
      expect(
        document.editedConfig(node, '"new"'),
        "export HOST='new' # keep me",
      );
    },
  );

  test('Java properties decodes escapes and CRLF continuations', () {
    final result = parseDocument({
      'format': 'properties',
      'text':
          '! ignored\r\n'
          r'key\ with\ spaces : caf\u00e9'
          '\r\n'
          'continued = first\\\r\n  second\r\nempty',
    });
    expect(result.error, isNull);
    expect(result.value, {
      'key with spaces': 'café',
      'continued': 'firstsecond',
      'empty': '',
    });
    expect(
      parseDocument({'format': 'properties', 'text': r'a=\u123'}).error,
      contains('Unicode'),
    );
  });

  test('New formats round-trip through native text export', () async {
    final exporter = DocumentExportService();
    for (final (format, value) in [
      (
        'ini',
        {
          'server': {'port': '080'},
        },
      ),
      (
        'dotenv',
        {
          'KEY':
              "don't run "
              r'$(command)',
        },
      ),
      ('properties', {'a b': 'ñ\nvalue'}),
    ]) {
      final bytes = await exporter.encode(value, [], format);
      final result = parseDocument({
        'format': format,
        'text': utf8.decode(bytes),
      });
      expect(result.error, isNull, reason: format);
      expect(result.value, value, reason: format);
    }
  });
}
