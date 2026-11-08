import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/font_preferences.dart';
import '../services/system_font_service.dart';

class FontSettings extends StatefulWidget {
  const FontSettings({
    super.key,
    required this.value,
    required this.language,
    required this.onChanged,
    this.service,
  });
  final FontPreferences value;
  final String language;
  final Future<bool> Function(FontPreferences) onChanged;
  final SystemFontService? service;
  @override
  State<FontSettings> createState() => _FontSettingsState();
}

class _FontSettingsState extends State<FontSettings> {
  late FontPreferences value = widget.value;
  List<String>? families;
  bool applying = false;
  bool failed = false;
  String tr(String es, String en) => AppStrings(widget.language).tr(es, en);
  @override
  void initState() {
    super.initState();
    discover();
  }

  Future<void> discover() async {
    try {
      final found = await (widget.service ?? SystemFontService.instance)
          .families();
      if (mounted) setState(() => families = found);
    } catch (_) {
      if (mounted) {
        setState(() {
          families = [];
          failed = true;
        });
      }
    }
  }

  Future<void> apply(FontPreferences next) async {
    setState(() {
      applying = true;
      failed = false;
    });
    var accepted = false;
    try {
      accepted = await widget.onChanged(next);
    } catch (_) {
      /* Keep current font. */
    }
    if (!mounted) return;
    setState(() {
      if (accepted) value = next;
      failed = !accepted;
      applying = false;
    });
  }

  String label(TypefaceStyle style) => switch (style) {
    TypefaceStyle.regular => tr('Normal', 'Regular'),
    TypefaceStyle.bold => tr('Negrita', 'Bold'),
    TypefaceStyle.italic => tr('Cursiva', 'Italic'),
    TypefaceStyle.boldItalic => tr('Negrita cursiva', 'Bold italic'),
  };
  @override
  Widget build(BuildContext context) {
    final available = {'', value.family, ...?families}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (families == null) Text(tr('Cargando fuentes…', 'Loading fonts…')),
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<String>(
            key: ValueKey('font-family-${value.family}'),
            width: constraints.maxWidth,
            menuHeight: 280,
            initialSelection: value.family,
            enabled: families != null && !applying,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            label: Text(tr('Fuente del sistema', 'System font')),
            dropdownMenuEntries: available
                .map(
                  (family) => DropdownMenuEntry(
                    value: family,
                    label: family.isEmpty
                        ? tr('Predeterminada', 'Default font')
                        : family,
                  ),
                )
                .toList(),
            onSelected: (family) {
              if (family != null) {
                apply(FontPreferences(family: family, style: value.style));
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TypefaceStyle>(
          key: ValueKey('font-style-${value.style.name}'),
          initialValue: value.style,
          decoration: InputDecoration(
            labelText: tr('Estilo de fuente', 'Font style'),
          ),
          items: TypefaceStyle.values
              .map(
                (style) =>
                    DropdownMenuItem(value: style, child: Text(label(style))),
              )
              .toList(),
          onChanged: applying
              ? null
              : (style) {
                  if (style != null) {
                    apply(FontPreferences(family: value.family, style: style));
                  }
                },
        ),
        const SizedBox(height: 12),
        Text(
          'Aa Bb 0123  { "json": true }',
          key: const Key('font-preview'),
          style: TextStyle(
            fontFamily: value.loadedFamily,
            fontWeight: value.weight,
            fontStyle: value.slant,
            fontSize: 16,
          ),
        ),
        if (applying) const LinearProgressIndicator(),
        if (failed)
          Text(
            tr('No se pudo cargar la fuente.', 'Could not load font.'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
