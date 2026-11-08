import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_settings.dart';
import '../../models/font_preferences.dart';
import '../../themes/code_palette.dart';
import '../font_settings.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.theme,
    required this.language,
    required this.fontSize,
    this.font = const FontPreferences(),
    this.onFont,
    required this.colorTheme,
    required this.onSettings,
    this.onColorTheme,
  });
  final ThemeMode theme;
  final String language, colorTheme;
  final double fontSize;
  final FontPreferences font;
  final Future<bool> Function(FontPreferences)? onFont;
  final void Function(ThemeMode, String, double) onSettings;
  final ValueChanged<String>? onColorTheme;
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late ThemeMode theme = widget.theme;
  late String language = widget.language;
  late double size = widget.fontSize;
  late String colors = widget.colorTheme;
  String tr(String es, String en) => AppStrings(
    resolveLanguage(
      language,
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    ),
  ).tr(es, en);
  String colorThemeName(String id) => switch (id) {
    'ocean' => tr('Océano', 'Ocean'),
    'amethyst' => tr('Amatista', 'Amethyst'),
    'amber' => tr('Ámbar', 'Amber'),
    'rose' => tr('Rosa', 'Rose'),
    'slate' => tr('Pizarra', 'Slate'),
    _ => tr('Jade', 'Jade'),
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Configuración', 'Settings')),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ThemeMode>(
              initialValue: theme,
              decoration: InputDecoration(labelText: tr('Tema', 'Theme')),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(tr('Sistema', 'System')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(tr('Claro', 'Light')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(tr('Oscuro', 'Dark')),
                ),
              ],
              onChanged: (v) {
                setState(() => theme = v!);
                widget.onSettings(theme, language, size);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('color-theme-setting'),
              initialValue: colors,
              decoration: InputDecoration(labelText: tr('Colores', 'Colors')),
              items: colorThemes
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: CodePalette.seed(id),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(colorThemeName(id)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => colors = value!);
                widget.onColorTheme?.call(colors);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: language,
              decoration: InputDecoration(labelText: tr('Idioma', 'Language')),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(tr('Sistema', 'System')),
                ),
                const DropdownMenuItem(value: 'es', child: Text('Español')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'fr', child: Text('Français')),
                const DropdownMenuItem(value: 'pt', child: Text('Português')),
                const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                const DropdownMenuItem(value: 'it', child: Text('Italiano')),
              ],
              onChanged: (v) {
                setState(() => language = v!);
                widget.onSettings(theme, language, size);
              },
            ),
            const SizedBox(height: 20),
            Text('${tr('Tamaño de fuente', 'Font size')}: ${size.round()}'),
            Slider(
              value: size,
              min: 11,
              max: 22,
              divisions: 11,
              onChanged: (v) {
                setState(() => size = v);
                widget.onSettings(theme, language, size);
              },
            ),
            const SizedBox(height: 16),
            FontSettings(
              value: widget.font,
              language: resolveLanguage(
                language,
                WidgetsBinding.instance.platformDispatcher.locale.languageCode,
              ),
              onChanged: widget.onFont ?? (_) async => true,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Cerrar', 'Close')),
      ),
    ],
  );
}
