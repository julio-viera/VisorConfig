import 'dart:io';

import 'package:visor_config/app_info.dart';

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  void update(String path, String Function(String) change) {
    final file = File('${root.path}/$path');
    final original = file.readAsStringSync();
    final next = change(original);
    if (next != original) file.writeAsStringSync(next);
  }

  update(
    'pubspec.yaml',
    (s) => s
        .replaceFirst(
          RegExp(r'^version:.*$', multiLine: true),
          'version: $appVersion+1',
        )
        .replaceFirst(
          RegExp(r'^description:.*$', multiLine: true),
          'description: "${appDescriptions['en']}"',
        ),
  );
  update(
    'linux/CMakeLists.txt',
    (s) => s.replaceFirst(
      RegExp(r'set\(APPLICATION_ID "[^"]+"\)'),
      'set(APPLICATION_ID "$appId")',
    ),
  );
  update(
    'linux/runner/my_application.cc',
    (s) => s
        .replaceAllMapped(
          RegExp(r'(gtk_header_bar_set_title\(header_bar, ")[^"]+("\))'),
          (m) => '${m[1]}$appName${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'(gtk_window_set_title\(window, ")[^"]+("\))'),
          (m) => '${m[1]}$appName${m[2]}',
        ),
  );
  update(
    'android/app/src/main/AndroidManifest.xml',
    (s) => s.replaceFirst(
      RegExp(r'android:label="[^"]+"'),
      'android:label="$appName"',
    ),
  );
  update(
    'windows/runner/Runner.rc',
    (s) => s
        .replaceAllMapped(
          RegExp(r'(VALUE "(?:FileDescription|ProductName)", ")[^"]+(" )'),
          (m) => '${m[1]}$appName${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'(VALUE "CompanyName", ")[^"]+(" )'),
          (m) => '${m[1]}$appAuthor${m[2]}',
        ),
  );
}
