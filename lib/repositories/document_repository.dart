import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Disk access only; choosing paths and confirming changes belong to the UI.
class DocumentRepository {
  static const maxFileBytes = 32 * 1024 * 1024;

  Future<String> read(XFile file) async {
    if (await file.length() > maxFileBytes) {
      throw FileSystemException('File exceeds 32 MiB', file.path);
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.openRead()) {
      length += chunk.length;
      if (length > maxFileBytes) {
        throw FileSystemException('File exceeds 32 MiB', file.path);
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<String> readPath(String path) => read(XFile(path));

  Future<void> write(String path, List<int> bytes) async {
    var target = File(path).absolute;
    if (await FileSystemEntity.isLink(target.path)) {
      target = File(await target.resolveSymbolicLinks());
    }
    final staging = await target.parent.createTemp('.visor-config-');
    try {
      final temporary = File(
        '${staging.path}${Platform.pathSeparator}document',
      );
      final exists = await target.exists();
      if (exists && Platform.isLinux) {
        await _command('/bin/cp', [
          '--attributes-only',
          '--preserve=all',
          '--',
          target.path,
          temporary.path,
        ], path);
      } else if (exists && Platform.isMacOS) {
        await _command('/bin/cp', ['-p', target.path, temporary.path], path);
      }
      await temporary.writeAsBytes(bytes, flush: true);
      if (exists && Platform.isWindows) {
        // Literal paths travel as environment values, never executable script text.
        final result = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r'Get-Acl -LiteralPath $env:VISOR_ACL_SOURCE | Set-Acl -LiteralPath $env:VISOR_ACL_TARGET -ErrorAction Stop',
          ],
          environment: {
            'VISOR_ACL_SOURCE': target.path,
            'VISOR_ACL_TARGET': temporary.path,
          },
        );
        if (result.exitCode != 0) {
          throw FileSystemException('Could not preserve file ACL', path);
        }
      } else if (!exists && !Platform.isWindows) {
        await _command('/bin/chmod', ['600', temporary.path], path);
      }
      await temporary.rename(target.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // Cleanup failure must not change the outcome of the replacement.
      }
    }
  }

  Future<void> _command(
    String executable,
    List<String> arguments,
    String path,
  ) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not preserve file metadata', path);
    }
  }

  Stream<FileSystemEvent> watch(String path) =>
      File(path).parent.watch().where((event) => event.path == path);
}
