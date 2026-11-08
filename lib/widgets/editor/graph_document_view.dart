import '../../themes/code_palette.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_document_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/json_document.dart';
import '../../services/graph_renderer.dart';
import '../graph/graph_view.dart';

class GraphDocumentView extends StatefulWidget {
  const GraphDocumentView({
    super.key,
    this.viewportKey,
    required this.document,
    required this.language,
    required this.onEdit,
  });
  final GlobalKey? viewportKey;
  final EditorDocumentController document;
  final String language;
  final Future<void> Function(JsonNode) onEdit;
  @override
  State<GraphDocumentView> createState() => _GraphDocumentViewState();
}

class _GraphDocumentViewState extends State<GraphDocumentView> {
  String? _lastMode;
  GraphLayout? _layout;
  Object? _layoutKey;
  Set<String> _layoutExpanded = const {};
  bool _truncated = false;
  String get languageCode => widget.language;
  bool get spanish => languageCode == 'es';
  String tr(String es, String en) => AppStrings(languageCode).tr(es, en);
  Future<void> graphMenu(
    EditorDocumentController d,
    GraphLayout layout,
    Offset local,
    Offset global,
  ) async {
    final node = layout.nodes
        .where((n) => layout.boxes[n.path]!.contains(local))
        .firstOrNull;
    if (node == null) return;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        global.dx,
        global.dy,
        global.dx,
        global.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'focus',
          child: Text(tr('Enfocar subárbol', 'Focus subtree')),
        ),
        PopupMenuItem(value: 'edit', child: Text(tr('Editar', 'Edit'))),
        PopupMenuItem(
          value: 'copy',
          child: Text(tr('Copiar ruta', 'Copy path')),
        ),
      ],
    );
    if (!mounted || d.closed) return;
    if (choice == 'edit') widget.onEdit(node);
    if (choice == 'copy') Clipboard.setData(ClipboardData(text: node.path));
    if (choice == 'focus') {
      setState(() {
        d.graphRoot = node.path;
        d.expanded.add(node.path);
        d.graphTransform.value = Matrix4.identity();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final mode = d.mode;
    final palette = CodePalette.of(context);
    final key = (d.result, d.graphRoot, mode, palette.dark, palette.variant);
    if (key != _layoutKey || !setEquals(_layoutExpanded, d.expanded)) {
      final visible = d.graphNodes.take(2001).toList();
      _truncated = visible.length > 2000;
      if (_truncated) visible.removeLast();
      _layout = GraphLayout(
        visible,
        palette: palette,
        radial: mode == 'radial',
        diagram: mode == 'diagram',
      );
      _layoutKey = key;
      _layoutExpanded = Set.of(d.expanded);
    }
    final layout = _layout!;
    if (mode != _lastMode) {
      final shouldFit = mode != 'graph' || _lastMode != null;
      _lastMode = mode;
      if (shouldFit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || d.closed || d.mode != mode) {
            return;
          }
          final size = widget.viewportKey?.currentContext?.size;
          if (size != null && !size.isEmpty) {
            GraphViewport.fitLayout(d.graphTransform, layout, size);
          }
        });
      }
    }
    return Column(
      children: [
        if (_truncated)
          Text(
            tr(
              'Límite de 2000 nodos. Colapsa ramas para ver otros nodos.',
              '2000 node limit. Collapse branches to see other nodes.',
            ),
          ),
        Expanded(
          child: GraphViewport(
            layout: layout,
            key: ValueKey(mode),
            onExpandAll: () => setState(() {
              for (final node in d.result?.nodes ?? <JsonNode>[]) {
                if (node.hasChildren) d.expanded.add(node.path);
              }
            }),
            onCollapseAll: () => setState(() {
              d.expanded.clear();
              d.graphRoot = r'$';
              d.graphTransform.value = Matrix4.identity();
            }),
            viewportKey: widget.viewportKey,
            activeMatch: d.matches.isEmpty
                ? null
                : d.matches[d.currentMatch].path,
            controller: d.graphTransform,
            matches: d.matches.map((n) => n.path).toSet(),
            spanish: spanish,
            expanded: d.expanded,
            language: languageCode,
            onTap: (position) {
              for (final n in layout.nodes) {
                if (n.hasChildren && layout.boxes[n.path]!.contains(position)) {
                  setState(() {
                    if (!d.expanded.remove(n.path)) d.expanded.add(n.path);
                  });
                  break;
                }
              }
            },
            onEdit: (position) {
              for (final n in layout.nodes) {
                if (layout.boxes[n.path]!.contains(position)) {
                  widget.onEdit(n);
                  break;
                }
              }
            },
            onMenu: (local, global) => graphMenu(d, layout, local, global),
          ),
        ),
      ],
    );
  }
}
