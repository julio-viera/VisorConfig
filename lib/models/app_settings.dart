import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'font_preferences.dart';
import 'window_geometry.dart';

const colorThemes = ['jade', 'ocean', 'amethyst', 'amber', 'rose', 'slate'];

class AppSettings {
  const AppSettings({
    this.theme = ThemeMode.system,
    this.language = 'system',
    this.fontSize = 14,
    this.font = const FontPreferences(),
    this.colorTheme = 'jade',
    this.window = const WindowGeometry(),
    this.lastOpenDirectory,
  });
  final String? lastOpenDirectory;
  final ThemeMode theme;
  final String language, colorTheme;
  final double fontSize;
  final FontPreferences font;
  final WindowGeometry window;
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final font = json['fontSize'];
    return AppSettings(
      lastOpenDirectory:
          json['lastOpenDirectory'] is String &&
              (json['lastOpenDirectory'] as String).trim().isNotEmpty
          ? json['lastOpenDirectory'] as String
          : null,
      font: FontPreferences.fromJson(json['font']),
      window: WindowGeometry.fromJson(json['window']),
      theme: ThemeMode.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => ThemeMode.system,
      ),
      language: ['system', ...supportedLanguageCodes].contains(json['language'])
          ? json['language'] as String
          : 'system',
      colorTheme: colorThemes.contains(json['colorTheme'])
          ? json['colorTheme'] as String
          : 'jade',
      fontSize: font is num && font.isFinite
          ? font.toDouble().clamp(11, 22)
          : 14,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'theme': theme.name,
    'language': language,
    'fontSize': fontSize,
    'font': font.toJson(),
    'colorTheme': colorTheme,
    'window': window.toJson(),
    'lastOpenDirectory': lastOpenDirectory,
  };
}
