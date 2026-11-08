import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/font_preferences.dart';
import '../repositories/settings_repository.dart';
import '../services/system_font_service.dart';
import '../services/window_session.dart';

/// Owns application preferences and coordinates their ordered persistence.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.initial,
    required this.store,
    this.windowSession,
    this.onSaveError,
    SystemFontService? fontService,
  }) : fontService = fontService ?? SystemFontService.instance,
       theme = initial.theme,
       language = initial.language,
       fontSize = initial.fontSize,
       font = initial.font,
       lastOpenDirectory = initial.lastOpenDirectory,
       colorTheme = initial.colorTheme {
    var maximized = windowSession?.geometry.maximized;
    windowSession?.onChanged = (geometry) {
      if (!_disposed && maximized != geometry.maximized) {
        maximized = geometry.maximized;
        notifyListeners();
      }
      return persist();
    };
  }
  final SystemFontService fontService;
  final AppSettings initial;
  final SettingsRepository store;
  final WindowSession? windowSession;
  final VoidCallback? onSaveError;
  String? lastOpenDirectory;
  ThemeMode theme;
  String language, colorTheme;
  double fontSize;
  FontPreferences font;
  int _fontRevision = 0;
  bool _disposed = false;

  void update(ThemeMode theme, String language, double fontSize) {
    this.theme = theme;
    this.language = language;
    this.fontSize = fontSize;
    notifyListeners();
    persist();
  }

  void updateColorTheme(String value) {
    colorTheme = value;
    notifyListeners();
    persist();
  }

  Future<bool> updateFont(FontPreferences value) async {
    final revision = ++_fontRevision;
    if (!await fontService.load(value.family)) return false;
    if (_disposed || revision != _fontRevision) return false;
    font = value;
    notifyListeners();
    await persist();
    return true;
  }

  Future<void> rememberOpenDirectory(String directory) async {
    if (_disposed || directory == lastOpenDirectory) return;
    lastOpenDirectory = directory;
    await persist();
  }

  Future<void> persist() async {
    try {
      await store.save(
        AppSettings(
          theme: theme,
          language: language,
          fontSize: fontSize,
          font: font,
          lastOpenDirectory: lastOpenDirectory,
          colorTheme: colorTheme,
          window: windowSession?.geometry ?? initial.window,
        ),
      );
    } catch (_) {
      if (!_disposed) onSaveError?.call();
    }
  }

  Future<void> flush() async {
    await windowSession?.flush();
    await store.flush();
  }

  @override
  void dispose() {
    _disposed = true;
    windowSession?.dispose();
    super.dispose();
  }
}
