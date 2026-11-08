import 'messages.dart';

const supportedLanguageCodes = ['en', 'es', 'fr', 'pt', 'de', 'it'];
String resolveLanguage(String preference, String system) =>
    supportedLanguageCodes.contains(
      preference == 'system' ? system : preference,
    )
    ? (preference == 'system' ? system : preference)
    : 'en';

class AppStrings {
  const AppStrings(this.language);
  final String language;
  String tr(String es, String en) => language == 'es'
      ? es
      : language == 'en'
      ? en
      : translatedMessages[en]?[language] ?? en;
  String error(String message) {
    const spanish = {
      'Empty document': 'Documento vacío',
      'File not found': 'Archivo no encontrado',
      'Not a regular file': 'No es un archivo regular',
      'Unexpected character': 'Carácter inesperado',
      'Unexpected end of input': 'Fin inesperado del texto',
      'Unterminated string': 'Cadena sin terminar',
      'Number outside supported finite range':
          'Número fuera del intervalo finito admitido',
    };
    return tr(spanish[message] ?? message, message);
  }
}
