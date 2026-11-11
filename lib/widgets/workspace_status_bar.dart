import 'package:flutter/material.dart';

import '../app_info.dart';
import '../l10n/app_strings.dart';
import '../themes/code_palette.dart';
import 'app_logo.dart';

class WorkspaceStatusBar extends StatelessWidget {
  const WorkspaceStatusBar({
    super.key,
    required this.status,
    required this.parsing,
    required this.saving,
    required this.valid,
    required this.hasError,
    required this.characters,
    required this.language,
    required this.onAbout,
  });
  final String status, language;
  final bool parsing, saving, valid, hasError;
  final int characters;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final palette = CodePalette.of(context);
    final strings = AppStrings(language);
    final visibleStatus = saving ? strings.tr('Guardando…', 'Saving…') : status;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        key: const Key('workspace-status-bar'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        color: hasError
            ? palette.errorBackground
            : Theme.of(context).colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .52),
              child: Row(
                key: const Key('app-identity'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 18),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    appVersion,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  IconButton(
                    key: const Key('app-about'),
                    tooltip: strings.tr('Acerca de', 'About'),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onAbout,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$characters ${strings.tr('caracteres', 'characters')}',
                    key: const Key('character-count'),
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  const SizedBox(width: 8),
                  if (saving)
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      parsing
                          ? Icons.hourglass_empty
                          : valid
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 14,
                      color: hasError
                          ? palette.error
                          : valid
                          ? const Color(0xff299777)
                          : palette.text,
                    ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Tooltip(
                      message: visibleStatus,
                      child: Text(
                        visibleStatus,
                        key: const Key('parse-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasError ? palette.error : palette.text,
                          fontWeight: hasError
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
