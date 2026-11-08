import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/visor_config_app.dart';
import 'app_info.dart';
import 'models/launch_request.dart';
import 'repositories/settings_repository.dart';
import 'services/launch_arguments.dart';
import 'services/system_font_service.dart';
import 'services/window_session.dart';

Future<void> main(List<String> arguments) async {
  LaunchPlan plan;
  try {
    plan = LaunchPlan.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    await stderr.flush();
    exit(64);
  }
  if (plan.action == LaunchAction.help) {
    stdout.writeln(
      '$appName $appVersion\nUsage: $appPackageName [FILE|CONFIG_TEXT]...\n       $appPackageName --file PATH\n       $appPackageName --json JSON_TEXT\nOptions: --help, --version, -- (end options)',
    );
    await stdout.flush();
    exit(0);
  }
  if (plan.action == LaunchAction.version) {
    stdout.writeln('$appName $appVersion');
    await stdout.flush();
    exit(0);
  }
  WidgetsFlutterBinding.ensureInitialized();
  final requests = StreamController<MethodCall>();
  const launchChannel = MethodChannel('visor-config/launch');
  launchChannel.setMethodCallHandler((call) async {
    if (call.method != 'open') throw MissingPluginException();
    requests.add(call);
  });
  final externalLaunches = requests.stream.asyncMap((call) async {
    final arguments = List<String>.from(call.arguments['arguments'] as List);
    try {
      return await loadLaunchDocuments(
        LaunchPlan.parse(arguments),
        currentDirectory: call.arguments['cwd'] as String?,
        deferFileReads: true,
      );
    } on FormatException catch (error) {
      return LaunchResult(
        issues: [LaunchIssue(arguments.join(' '), error.message)],
      );
    }
  });
  final launch = await loadLaunchDocuments(plan);
  final store = SettingsRepository();
  final settings = await store.load();
  await SystemFontService.instance.load(settings.font.family);
  final window = NativeWindowHost.supported
      ? WindowSession(host: NativeWindowHost(), geometry: settings.window)
      : null;
  await window?.restore();
  if (Platform.isMacOS) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await launchChannel.invokeMethod<void>('ready');
    });
  }
  runApp(
    VisorConfigApp(
      initialSettings: settings,
      settingsStore: store,
      windowSession: window,
      launch: launch,
      externalLaunches: externalLaunches,
    ),
  );
}
