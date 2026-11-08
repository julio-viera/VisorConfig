import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../l10n/app_strings.dart';
import '../app_logo.dart';

class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key, required this.language, this.openLink});
  final String language;
  final Future<bool> Function(Uri)? openLink;
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(language);
    String tr(String es, String en) => strings.tr(es, en);
    Future<void> open(String url) async {
      try {
        final uri = Uri.parse(url);
        final success =
            await (openLink?.call(uri) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
        if (!success) throw StateError('URL');
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                tr('No se pudo abrir el enlace.', 'Could not open link.'),
              ),
            ),
          );
        }
      }
    }

    Widget info(String label, String value, {String? url}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: url == null
                ? SelectableText(value)
                : Semantics(
                    link: true,
                    child: InkWell(
                      onTap: () => open(url),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new,
                            size: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
    return AlertDialog(
      key: const Key('app-about-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      title: Column(
        children: [
          const AppLogo(size: 64),
          const SizedBox(height: 20),
          Text(
            '${tr('Acerca de', 'About')} $appName',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(appName, style: TextStyle(fontSize: 16)),
              Text('${tr('Versión', 'Version')} $appVersion'),
              const SizedBox(height: 20),
              Text(appDescriptionFor(language)),
              const SizedBox(height: 20),
              info(tr('Autor', 'Author'), appAuthor),
              info(
                tr('Licencia', 'License'),
                appLicenseName,
                url: appLicenseUrl,
              ),
              info(
                tr('Repositorio', 'Repository'),
                appRepositoryUrl.replaceFirst('https://', ''),
                url: appRepositoryUrl,
              ),
              info(
                tr('Reportar errores', 'Report issues'),
                appIssuesUrl.replaceFirst('https://', ''),
                url: appIssuesUrl,
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
}
