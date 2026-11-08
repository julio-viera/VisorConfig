import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:file_selector/file_selector.dart';

/// Adapter for platform file dialogs (desktop and Android document providers).
class FileDialogService {
  Future<XFile?> open({String? initialDirectory}) async {
    // Stale paths (deleted folders or disconnected drives) use the system default.
    String? directory;
    if (!Platform.isAndroid && initialDirectory != null) {
      try {
        if (await Directory(initialDirectory).exists()) {
          directory = initialDirectory;
        }
      } on FileSystemException {
        /* Use the system default when inaccessible. */
      }
    }
    return openFile(
      initialDirectory: directory,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Configuration files',
          extensions: [
            'json',
            'jsonc',
            'txt',
            'jsonld',
            'geojson',
            'yaml',
            'yml',
            'toml',
            'ini',
            'cfg',
            'env',
            'env.local',
            'properties',
          ],
          mimeTypes: [
            'application/json',
            'text/plain',
            'application/yaml',
            'application/x-yaml',
            'application/toml',
            'application/ld+json',
            'application/geo+json',
          ],
        ),
      ],
    );
  }

  final _saveFolders = <String, String>{};

  /// A directory grant permits sibling temporaries used by atomic replacement.
  Future<String?> authorizeSavePath(String path) async {
    if (!Platform.isLinux || !Platform.environment.containsKey('FLATPAK_ID')) {
      return path;
    }
    final parent = File(path).parent.path;
    var folder = _saveFolders[parent];
    folder ??= await getDirectoryPath(
      initialDirectory: parent,
      confirmButtonText: 'Save in this folder',
    );
    if (folder == null) return null;
    _saveFolders[parent] = folder;
    final candidate = '$folder/${File(path).uri.pathSegments.last}';
    if (await File(candidate).exists() &&
        await File(path).exists() &&
        await FileSystemEntity.identical(candidate, path)) {
      return candidate;
    }
    final confirmed = await getSaveLocation(
      initialDirectory: folder,
      suggestedName: File(path).uri.pathSegments.last,
    );
    return confirmed?.path;
  }

  Future<FileSaveLocation?> saveLocation({required String suggestedName}) =>
      getSaveLocation(suggestedName: suggestedName);
  Future<Uri?> saveAndroid({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
}
