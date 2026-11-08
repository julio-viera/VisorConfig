import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/graph_renderer.dart';
import '../../themes/app_typography.dart';

import 'dart:math' as math;

class GraphViewport extends StatelessWidget {
  const GraphViewport({
    super.key,
    required this.layout,
    required this.controller,
    required this.matches,
    required this.onTap,
    required this.onEdit,
    required this.onMenu,
    required this.spanish,
    this.language,
    this.expanded,
    this.viewportKey,
    this.activeMatch,
    this.onExpandAll,
    this.onCollapseAll,
  });
  final GraphLayout layout;
  final Key? viewportKey;
  final String? activeMatch;
  final VoidCallback? onExpandAll, onCollapseAll;
  final TransformationController controller;
  final Set<String> matches;
  final Set<String>? expanded;
  final void Function(Offset) onTap, onEdit;
  final void Function(Offset, Offset) onMenu;
  final bool spanish;
  final String? language;
  String tr(String es, String en) =>
      AppStrings(language ?? (spanish ? 'es' : 'en')).tr(es, en);

  void zoom(double factor, Size viewport) {
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.05, 8.0);
    final center = viewport.center(Offset.zero);
    final scene = controller.toScene(center);
    controller.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(next, next, next, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  static void fitLayout(
    TransformationController controller,
    GraphLayout layout,
    Size viewport,
  ) {
    final scale = ((viewport.width - 32) / layout.width).clamp(0.05, 8.0);
    final heightScale = ((viewport.height - 32) / layout.height).clamp(
      0.05,
      8.0,
    );
    final fit = math.min(scale, heightScale);
    controller.value = Matrix4.identity()
      ..translateByDouble(
        (viewport.width - layout.width * fit) / 2,
        (viewport.height - layout.height * fit) / 2,
        0,
        1,
      )
      ..scaleByDouble(fit, fit, fit, 1);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = Size(
        constraints.maxWidth,
        (constraints.maxHeight - 48).clamp(1, double.infinity),
      );
      return Column(
        children: [
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (onExpandAll != null)
                    IconButton(
                      tooltip: tr('Expandir todo', 'Expand all'),
                      onPressed: onExpandAll,
                      icon: const Icon(Icons.unfold_more),
                    ),
                  if (onCollapseAll != null)
                    IconButton(
                      tooltip: tr('Colapsar todo', 'Collapse all'),
                      onPressed: onCollapseAll,
                      icon: const Icon(Icons.unfold_less),
                    ),
                  IconButton(
                    key: const Key('graph-zoom-out'),
                    tooltip: tr('Alejar', 'Zoom out'),
                    onPressed: () => zoom(1 / 1.25, viewport),
                    icon: const Icon(Icons.remove),
                  ),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (_, _) => SizedBox(
                      width: 64,
                      child: Text(
                        '${(controller.value.getMaxScaleOnAxis() * 100).round()}%',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('graph-zoom-in'),
                    tooltip: tr('Acercar', 'Zoom in'),
                    onPressed: () => zoom(1.25, viewport),
                    icon: const Icon(Icons.add),
                  ),
                  TextButton(
                    onPressed: () => controller.value = Matrix4.identity(),
                    child: const Text('100%'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      fitLayout(controller, layout, viewport);
                    },
                    icon: const Icon(Icons.fit_screen),
                    label: Text(tr('Ajustar', 'Fit')),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              key: const Key('graph-viewport-clip'),
              child: Stack(
                key: viewportKey,
                children: [
                  Positioned.fill(child: ColoredBox(color: layout.background)),
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 0.05,
                      maxScale: 8,
                      scaleFactor: 150,
                      trackpadScrollCausesScale: true,
                      constrained: false,
                      clipBehavior: Clip.hardEdge,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: GestureDetector(
                        onTapUp: (e) => onTap(e.localPosition),
                        onDoubleTapDown: (e) => onEdit(e.localPosition),
                        onSecondaryTapUp: (e) =>
                            onMenu(e.localPosition, e.globalPosition),
                        onLongPressStart: (e) =>
                            onMenu(e.localPosition, e.globalPosition),
                        child: CustomPaint(
                          size: Size(layout.width, layout.height),
                          painter: GraphPainter(
                            layout,
                            const Color(0xff173f39),
                            matches,
                            activeMatch: activeMatch,
                            expanded: expanded,
                            codeStyle: AppTypography.codeStyle(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      width: 160,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ClipRect(
                        child: GestureDetector(
                          onTapUp: (e) {
                            final scale = controller.value.getMaxScaleOnAxis();
                            final x = e.localPosition.dx / 160 * layout.width;
                            final y = e.localPosition.dy / 100 * layout.height;
                            controller.value = Matrix4.identity()
                              ..translateByDouble(
                                viewport.width / 2 - x * scale,
                                viewport.height / 2 - y * scale,
                                0,
                                1,
                              )
                              ..scaleByDouble(scale, scale, scale, 1);
                          },
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: CustomPaint(
                              size: Size(layout.width, layout.height),
                              painter: GraphPainter(
                                layout,
                                const Color(0xff173f39),
                                matches,
                                activeMatch: activeMatch,
                                codeStyle: AppTypography.codeStyle(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
