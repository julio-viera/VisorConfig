import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_info.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/launch_request.dart';
import '../repositories/settings_repository.dart';
import '../screens/workspace_screen.dart';
import '../services/window_session.dart';
import '../themes/app_theme.dart';

class VisorConfigApp extends StatefulWidget {
  const VisorConfigApp({
    super.key,
    this.initialSettings = const AppSettings(),
    this.settingsStore,
    this.windowSession,
    this.launch = const LaunchResult(),
    this.externalLaunches,
  });
  final AppSettings initialSettings;
  final SettingsRepository? settingsStore;
  final WindowSession? windowSession;
  final LaunchResult launch;
  final Stream<LaunchResult>? externalLaunches;
  @override
  State<VisorConfigApp> createState() => _VisorConfigAppState();
}

class _VisorConfigAppState extends State<VisorConfigApp> {
  late final SettingsController settings;
  final messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    settings = SettingsController(
      initial: widget.initialSettings,
      store: widget.settingsStore ?? SettingsRepository(),
      windowSession: widget.windowSession,
      onSaveError: () {
        if (!mounted) return;
        final language = resolveLanguage(
          settings.language,
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        );
        messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              AppStrings(language).tr(
                'No se pudo guardar la configuración.',
                'Could not save settings.',
              ),
            ),
          ),
        );
      },
    )..addListener(changed);
  }

  void changed() => setState(() {});

  @override
  void dispose() {
    settings.removeListener(changed);
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    supportedLocales: supportedLanguageCodes.map(Locale.new).toList(),
    locale: settings.language == 'system' ? null : Locale(settings.language),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    themeMode: settings.theme,
    scaffoldMessengerKey: messenger,
    theme: buildAppTheme(Brightness.light, settings.colorTheme, settings.font),
    darkTheme: buildAppTheme(
      Brightness.dark,
      settings.colorTheme,
      settings.font,
    ),
    builder: (context, child) {
      final content = MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(settings.fontSize / 14)),
        child: child!,
      );
      if (widget.windowSession?.host is! NativeWindowHost) return content;
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          widget.windowSession!.geometry.maximized ? 0 : 10,
        ),
        child: content,
      );
    },
    home: WorkspaceScreen(
      desktopTitleBar: widget.windowSession?.host is NativeWindowHost,
      launch: widget.launch,
      externalLaunches: widget.externalLaunches,
      lastOpenDirectory: settings.lastOpenDirectory,
      onOpenDirectory: settings.rememberOpenDirectory,
      language: settings.language,
      fontSize: settings.fontSize,
      font: settings.font,
      onFont: settings.updateFont,
      theme: settings.theme,
      colorTheme: settings.colorTheme,
      beforeExit: settings.flush,
      onColorTheme: settings.updateColorTheme,
      onSettings: settings.update,
    ),
  );
}
