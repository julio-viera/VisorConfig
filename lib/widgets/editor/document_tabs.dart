import 'dart:ui' show AppExitType, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../controllers/editor_document_controller.dart';
import '../../l10n/app_strings.dart';
import '../../themes/code_palette.dart';

class DocumentTabs extends StatelessWidget {
  const DocumentTabs({
    super.key,
    required this.documents,
    required this.active,
    required this.controller,
    required this.language,
    required this.onScroll,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
    required this.onSettings,
    required this.comparisonButton,
    this.desktopTitleBar = false,
  });
  final List<EditorDocumentController> documents;
  final int active;
  final ScrollController controller;
  final String language;
  final ValueChanged<int> onScroll, onSelect;
  final ValueChanged<EditorDocumentController> onClose;
  final VoidCallback onNew, onSettings;
  final Widget comparisonButton;
  final bool desktopTitleBar;

  static String _label(EditorDocumentController document) =>
      '${document.dirty ? '● ' : ''}${document.name}';

  static List<double> measureWidths(
    BuildContext context,
    List<EditorDocumentController> documents,
  ) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    try {
      return [
        for (final document in documents)
          _measure(painter, _label(document), style),
      ];
    } finally {
      painter.dispose();
    }
  }

  static double _measure(TextPainter painter, String label, TextStyle? style) {
    painter.text = TextSpan(text: label, style: style);
    painter.layout();
    return (painter.width.ceilToDouble() + 76).clamp(104.0, 320.0);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  List<EditorDocumentController> get docs => documents;
  ScrollController get tabsScroll => controller;
  String tr(String es, String en) => AppStrings(language).tr(es, en);
  Widget action(
    IconData icon,
    String title,
    VoidCallback callback, {
    Color? color,
  }) => SizedBox(
    width: 32,
    child: IconButton(
      tooltip: title,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
      padding: const EdgeInsets.all(5),
      onPressed: callback,
      icon: Icon(icon, size: 18, color: color),
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widths = measureWidths(context, docs);
      final total = widths.fold(0.0, (sum, width) => sum + width);
      final controlsWidth = desktopTitleBar ? 240.0 : 144.0;
      const edgeInset = 4.0;
      final availableWidth =
          constraints.maxWidth - controlsWidth - 2 * edgeInset;
      final overflow = total > availableWidth;
      final showArrows = overflow && constraints.maxWidth >= 480;
      final visibleWidth = (availableWidth - (showArrows ? 96 : 0)).clamp(
        0.0,
        total,
      );
      final palette = CodePalette.of(context);
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: edgeInset),
        color: Color.alphaBlend(
          CodePalette.seed(palette.variant).withValues(alpha: .23),
          Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Row(
          children: [
            if (showArrows)
              IconButton(
                visualDensity: VisualDensity.compact,
                key: const Key('tabs-previous'),
                tooltip: tr('Pestañas anteriores', 'Previous tabs'),
                onPressed: () => onScroll(-1),
                icon: const Icon(Icons.chevron_left),
              ),
            SizedBox(
              width: visibleWidth,
              child: Scrollbar(
                controller: tabsScroll,
                scrollbarOrientation: ScrollbarOrientation.top,
                thickness: 1.5,
                radius: const Radius.circular(1),
                trackVisibility: false,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      ...ScrollConfiguration.of(context).dragDevices,
                      PointerDeviceKind.mouse,
                    },
                    scrollbars: false,
                  ),
                  child: ListView.builder(
                    key: const Key('document-tabs'),
                    controller: tabsScroll,
                    scrollDirection: Axis.horizontal,
                    itemExtentBuilder: (index, _) => widths[index],
                    itemCount: docs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(left: 1, top: 5),
                      child: ClipPath(
                        clipper: _TabShape(active: i == active),
                        child: Container(
                          key: ValueKey('document-tab-$i'),
                          color: i == active
                              ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow
                              : palette.inactiveTab,
                          padding: const EdgeInsets.only(left: 5, right: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => onSelect(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _label(docs[i]),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: i == active
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                : palette.inactiveTabText,
                                            fontWeight: i == active
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              action(
                                Icons.close,
                                tr('Cerrar', 'Close'),
                                () => onClose(docs[i]),
                                color: i == active
                                    ? Theme.of(context).colorScheme.onSurface
                                    : palette.inactiveTabText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showArrows)
              IconButton(
                visualDensity: VisualDensity.compact,
                key: const Key('tabs-next'),
                tooltip: tr('Pestañas siguientes', 'Next tabs'),
                onPressed: () => onScroll(1),
                icon: const Icon(Icons.chevron_right),
              ),
            Expanded(
              child: desktopTitleBar
                  ? GestureDetector(
                      key: const Key('window-drag-region'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => windowManager.startDragging(),
                      onDoubleTap: _toggleMaximize,
                      child: const SizedBox.expand(),
                    )
                  : const SizedBox.shrink(),
            ),
            action(Icons.add, tr('Nuevo · Ctrl+N', 'New · Ctrl+N'), onNew),
            comparisonButton,
            action(
              Icons.settings_outlined,
              tr('Configuración', 'Settings'),
              onSettings,
            ),
            if (desktopTitleBar) ...[
              const SizedBox(width: 8),
              action(
                Icons.remove,
                tr('Minimizar ventana', 'Minimize window'),
                windowManager.minimize,
              ),
              action(
                Icons.crop_square,
                tr('Maximizar / Restaurar', 'Maximize / Restore'),
                _toggleMaximize,
              ),
              action(
                Icons.close,
                tr('Cerrar ventana', 'Close window'),
                () => ServicesBinding.instance.exitApplication(
                  AppExitType.cancelable,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// The lower shoulders flare into the toolbar, with a wider right shoulder.
class _TabShape extends CustomClipper<Path> {
  const _TabShape({required this.active});

  final bool active;

  @override
  Path getClip(Size size) {
    final right = size.width - (active ? 14 : 5);
    final bottom = size.height;
    return Path()
      ..moveTo(0, bottom)
      ..quadraticBezierTo(6, bottom, 6, bottom - 7)
      ..lineTo(6, 9)
      ..quadraticBezierTo(6, 0, 15, 0)
      ..lineTo(right - 9, 0)
      ..quadraticBezierTo(right, 0, right, 9)
      ..lineTo(right, bottom - (active ? 12 : 6))
      ..quadraticBezierTo(right, bottom, size.width, bottom)
      ..close();
  }

  @override
  bool shouldReclip(_TabShape oldClipper) => active != oldClipper.active;
}
