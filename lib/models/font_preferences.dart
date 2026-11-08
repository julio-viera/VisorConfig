import 'package:flutter/material.dart';

enum TypefaceStyle { regular, bold, italic, boldItalic }

@immutable
class FontPreferences {
  const FontPreferences({this.family = '', this.style = TypefaceStyle.regular});
  final String family;
  final TypefaceStyle style;
  String? get loadedFamily => family.isEmpty ? null : 'VisorSystem:$family';
  FontWeight get weight =>
      style == TypefaceStyle.bold || style == TypefaceStyle.boldItalic
      ? FontWeight.bold
      : FontWeight.normal;
  FontStyle get slant =>
      style == TypefaceStyle.italic || style == TypefaceStyle.boldItalic
      ? FontStyle.italic
      : FontStyle.normal;
  factory FontPreferences.fromJson(dynamic json) {
    if (json is! Map) return const FontPreferences();
    return FontPreferences(
      family: json['family'] is String ? json['family'] as String : '',
      style: TypefaceStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => TypefaceStyle.regular,
      ),
    );
  }
  Map<String, String> toJson() => {'family': family, 'style': style.name};
}
