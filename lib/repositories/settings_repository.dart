import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../app_info.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository({this.directory});
  final Directory? directory;
  Future<void> _pending = Future.value();
  Future<File> get settingsFile async {
    if (directory != null) return File('${directory!.path}/settings.json');
    final env = Platform.environment;
    if (Platform.isLinux) {
      final config = env['XDG_CONFIG_HOME'];
      final root = config != null && config.startsWith('/')
          ? config
          : '${env['HOME']!}/.config';
      return File('$root/$appBinaryName/settings.json');
    }
    if (Platform.isWindows && env['APPDATA'] != null) {
      return File(
        '${env['APPDATA']}${Platform.pathSeparator}$appName${Platform.pathSeparator}settings.json',
      );
    }
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}settings.json');
  }

  Future<void> flush() => _pending;

  Future<AppSettings> load() async {
    try {
      final data = jsonDecode(await (await settingsFile).readAsString());
      return data is Map<String, dynamic>
          ? AppSettings.fromJson(data)
          : const AppSettings();
    } on FileSystemException {
      return const AppSettings();
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    final write = _pending.then((_) async {
      final file = await settingsFile;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.$pid.tmp');
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n',
        flush: true,
      );
      await temporary.rename(file.path);
    });
    // Preserve write order without letting one failed write block later changes.
    _pending = write.catchError((Object _) {});
    return write;
  }
}
