import 'dart:convert';
import 'dart:io';

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  void update(String path, String Function(String) change) {
    final file = File('${root.path}/$path');
    final original = file.readAsStringSync();
    final next = change(original);
    if (next != original) file.writeAsStringSync(next);
  }

  final metadata = jsonDecode(
    File('${root.path}/assets/app_info.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final descriptions = Map<String, String>.from(
    metadata['descriptions'] as Map,
  );
  final appName = metadata['name'] as String;
  final appVersion = metadata['version'] as String;
  final buildNumber = metadata['buildNumber'] as int;
  final appId = metadata['id'] as String;
  final appAuthor = metadata['author'] as String;

  const fields = {
    'appName': 'name',
    'appVersion': 'version',
    'appAuthor': 'author',
    'appLicenseName': 'licenseName',
    'appLicenseSpdx': 'licenseSpdx',
    'appLicenseUrl': 'licenseUrl',
    'appRepositoryUrl': 'repositoryUrl',
    'appIssuesUrl': 'issuesUrl',
    'appId': 'id',
    'appPackageName': 'packageName',
    'appBinaryName': 'binaryName',
  };
  String dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

  final source = StringBuffer(
    '// Generated from assets/app_info.json by tools/sync_app_info.dart.\n',
  );
  for (final field in fields.entries) {
    source.writeln(
      'const ${field.key} = ${dartString(metadata[field.value] as String)};',
    );
  }
  source.writeln('\nconst appDescriptions = <String, String>{');
  for (final entry in descriptions.entries) {
    source.writeln('  ${dartString(entry.key)}: ${dartString(entry.value)},');
  }
  source.writeln('};');
  source.writeln(
    '''
String appDescriptionFor(String languageCode) =>
    appDescriptions[languageCode] ?? appDescriptions['en']!;
'''
        .trimRight(),
  );
  final generated = File('${root.path}/lib/app_info.dart');
  final generatedText = source.toString();
  if (!generated.existsSync() ||
      generated.readAsStringSync() != generatedText) {
    generated.writeAsStringSync(generatedText);
  }

  update(
    'pubspec.yaml',
    (s) => s
        .replaceFirst(
          RegExp(r'^version:.*$', multiLine: true),
          'version: $appVersion+$buildNumber',
        )
        .replaceFirst(
          RegExp(r'^description:.*$', multiLine: true),
          'description: ${jsonEncode(descriptions['en']!)}',
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
