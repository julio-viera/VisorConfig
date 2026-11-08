import 'dart:io';

import 'package:flutter/services.dart';

/// Discovers installed fonts and loads only the selected family into Flutter.
class SystemFontService {
  SystemFontService({this.environment});
  final Map<String, String>? environment;
  static final instance = SystemFontService();
  Future<Map<String, Set<String>>>? _catalog;
  final Map<String, Future<bool>> _loaded = {};

  Future<List<String>> families() async {
    final names = (await (_catalog ??= _discover())).keys.toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<bool> load(String family) async {
    if (family.isEmpty) return true;
    return _loaded.putIfAbsent(family, () async {
      try {
        final paths = (await (_catalog ??= _discover()))[family];
        if (paths == null || paths.isEmpty) return false;
        final loader = FontLoader('VisorSystem:$family');
        for (final path in paths) {
          loader.addFont(
            File(path)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  Future<Map<String, Set<String>>> _discover() async {
    final result = <String, Set<String>>{};
    if (Platform.isLinux) {
      try {
        final fonts = await Process.run('fc-list', [
          '--format',
          '%{family}\t%{file}\n',
        ], environment: environment);
        if (fonts.exitCode == 0) {
          for (final line in (fonts.stdout as String).split('\n')) {
            final fields = line.split('\t');
            if (fields.length != 2) continue;
            final family = fields[0].split(',').first.trim();
            final path = fields[1];
            if (family.isNotEmpty && _supported(path)) {
              result.putIfAbsent(family, () => {}).add(path);
            }
          }
          if (result.isNotEmpty) return result;
        }
      } on ProcessException {
        /* Directory discovery also works without fontconfig. */
      }
    }
    final env = Platform.environment;
    final home = env['HOME'] ?? '';
    final directories = Platform.isWindows
        ? [
            '${env['WINDIR'] ?? 'C:\\Windows'}/Fonts',
            '${env['LOCALAPPDATA'] ?? ''}/Microsoft/Windows/Fonts',
          ]
        : Platform.isMacOS
        ? ['/System/Library/Fonts', '/Library/Fonts', '$home/Library/Fonts']
        : Platform.isAndroid
        ? ['/system/fonts', '/product/fonts']
        : [
            '/usr/share/fonts',
            '/usr/local/share/fonts',
            '$home/.local/share/fonts',
            '$home/.fonts',
          ];
    for (final path in directories) {
      try {
        final directory = Directory(path);
        if (!await directory.exists()) continue;
        await for (final entry in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entry is! File || !_supported(entry.path)) continue;
          final name = entry.uri.pathSegments.last.replaceFirst(
            RegExp(r'\.(ttf|otf)$', caseSensitive: false),
            '',
          );
          final family = name.replaceFirst(
            RegExp(
              r'[-_](Regular|BoldItalic|BoldOblique|Bold|Italic|Oblique|Light|Medium|Thin|Black)$',
              caseSensitive: false,
            ),
            '',
          );
          result.putIfAbsent(family, () => {}).add(entry.path);
        }
      } on FileSystemException {
        /* Other accessible font directories remain usable. */
      }
    }
    return result;
  }

  bool _supported(String path) =>
      RegExp(r'\.(ttf|otf)$', caseSensitive: false).hasMatch(path);
}
