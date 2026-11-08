import '../themes/code_palette.dart';

import 'package:flutter/material.dart';

import '../models/json_document.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

class GraphLayout {
  GraphLayout(
    this.nodes, {
    CodePalette palette = const CodePalette(false),
    this.radial = false,
    this.diagram = false,
  }) : background = palette.gutter,
       connectorColor = palette.muted,
       labelColor = palette.text {
    final seed = HSLColor.fromColor(CodePalette.seed(palette.variant));
    final ancestors = <int, JsonNode>{};
    final children = <String, List<String>>{};
    final baseDepth = nodes.isEmpty ? 0 : nodes.first.depth;
    for (final node in nodes) {
      final parent = ancestors[node.depth - 1]?.path;
      parents[node.path] = parent;
      ancestors[node.depth] = node;
      if (parent != null) (children[parent] ??= []).add(node.path);
    }
    var leafY = 46.0;
    // Process children before their parent, keeping sibling groups together.
    final centers = <String, double>{};
    for (final node in nodes.reversed) {
      final group = children[node.path];
      if (group == null) {
        centers[node.path] = leafY;
        leafY += 56;
      } else {
        centers[node.path] = (centers[group.first]! + centers[group.last]!) / 2;
      }
    }
    final leaves = (leafY - 46) / 56;
    final step = math.max(115.0, leaves * 48 / (2 * math.pi));
    final radius = nodes.isEmpty
        ? 0.0
        : (nodes.map((n) => n.depth).reduce(math.max) - baseDepth) * step;
    final origin = Offset(radius + 110, radius + 80);
    for (final node in nodes) {
      final depth = node.depth - baseDepth;
      final center = leafY + 46 - 56 - centers[node.path]!;
      final nodeHeight = node.container ? 44.0 : 38.0;
      boxes[node.path] = Rect.fromLTWH(
        depth * 224.0 + 24,
        center - nodeHeight / 2,
        184,
        nodeHeight,
      );
      if (diagram) {
        boxes[node.path] = Rect.fromLTWH(
          (center - 46) / 56 * 224 + 24,
          depth * 176.0 + 24,
          196,
          136,
        );
      }
      if (radial) {
        final angle =
            (center - 46) / math.max(1, leaves * 56) * 2 * math.pi -
            math.pi / 2;
        boxes[node.path] = Rect.fromCircle(
          center:
              origin +
              Offset(math.cos(angle), math.sin(angle)) * (depth * step),
          radius: depth == 0 ? 15 : 11,
        );
      }
      fills[node.path] = seed
          .withHue((seed.hue + node.depth * 47) % 360)
          .withLightness(palette.dark ? .65 : .78)
          .toColor();
    }
    width = boxes.values.fold(
      400.0,
      (v, r) => math.max(v, r.right + (radial ? 110 : 24)),
    );
    height = boxes.values.fold(240.0, (v, r) => math.max(v, r.bottom + 24));
  }
  final List<JsonNode> nodes;
  final bool radial, diagram;
  final fills = <String, Color>{};
  final Color background, connectorColor, labelColor;
  String _hex(Color color) =>
      (color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0');
  List<String> details(JsonNode node) {
    final value = node.value;
    if (value is Map) {
      return [
        for (final entry in value.entries.take(5))
          '${entry.key}: ${entry.value == null
              ? 'null'
              : entry.value is Map
              ? 'object'
              : entry.value is List
              ? 'array'
              : entry.value is String
              ? 'string'
              : entry.value is bool
              ? 'boolean'
              : 'number'}',
        if (value.length > 5) '… +${value.length - 5}',
      ];
    }
    return [node.preview];
  }

  List<Offset> connector(Rect parent, Rect child) {
    if (diagram) {
      final y = (parent.bottom + child.top) / 2;
      return [
        parent.bottomCenter,
        Offset(parent.center.dx, y),
        Offset(child.center.dx, y),
        child.topCenter,
      ];
    }
    if (radial) {
      final delta = child.center - parent.center;
      final direction = delta / delta.distance;
      return [
        parent.center + direction * (parent.width / 2),
        child.center - direction * (child.width / 2),
      ];
    }
    final x = (parent.right + child.left) / 2;
    return [
      parent.centerRight,
      Offset(x, parent.center.dy),
      Offset(x, child.center.dy),
      child.centerLeft,
    ];
  }

  final boxes = <String, Rect>{};
  final parents = <String, String?>{};
  late final double width, height;
  String svg() {
    String escape(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height"><rect width="100%" height="100%" fill="#${_hex(background)}"/>',
    );
    if (radial) {
      out.write(
        '<defs><marker id="arrow" viewBox="0 0 8 6" refX="8" refY="3" markerWidth="8" markerHeight="6" orient="auto"><path d="M0 0L8 3L0 6Z" fill="#${_hex(connectorColor)}"/></marker></defs>',
      );
    }
    for (final node in nodes) {
      final parent = parents[node.path];
      if (parent == null) continue;
      if (diagram) {
        final start = boxes[parent]!.bottomCenter;
        out.write(
          '<path d="M${start.dx} ${start.dy}l4 6l-4 6l-4 -6Z" fill="#${_hex(connectorColor)}"/>',
        );
      }
      final points = connector(
        boxes[parent]!,
        boxes[node.path]!,
      ).map((point) => '${point.dx},${point.dy}').join(' ');
      out.write(
        '<polyline points="$points" stroke="#${_hex(connectorColor)}" fill="none"${radial ? ' marker-end="url(#arrow)"' : ''}/>',
      );
    }
    for (final node in nodes) {
      final r = boxes[node.path]!;
      final fill = (fills[node.path]!.toARGB32() & 0xffffff)
          .toRadixString(16)
          .padLeft(6, '0');
      String shorten(String value) =>
          value.length > 22 ? '${value.substring(0, 19)}…' : value;
      if (diagram) {
        out.write(
          '<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" rx="7" fill="#$fill"/>'
          '<path d="M${r.left} ${r.top + 39}H${r.right}" stroke="#172126"/>',
        );
        final rows = ['«${node.type}»', node.label, ...details(node)];
        for (var i = 0; i < rows.length; i++) {
          final y = r.top + (i < 2 ? 15 + i * 16 : 51 + (i - 2) * 14);
          out.write(
            '<text x="${r.left + 10}" y="$y" font-family="monospace" font-size="11" fill="#172126">${escape(shorten(rows[i]))}</text>',
          );
        }
        continue;
      }
      if (radial) {
        out.write(
          '<circle cx="${r.center.dx}" cy="${r.center.dy}" r="${r.width / 2}" fill="#$fill"/>'
          '<text x="${r.right + 5}" y="${r.center.dy + 4}" font-family="monospace" font-size="12" fill="#${_hex(labelColor)}">${escape(shorten(node.label))}</text>',
        );
        continue;
      }
      out.write(
        '<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" rx="7" fill="#$fill"/>'
        '<text x="${r.left + 10}" y="${r.center.dy - 3}" font-family="monospace" font-size="12" fill="#172126">${escape(shorten(node.label))}</text>'
        '<text x="${r.left + 10}" y="${r.center.dy + 12}" font-family="monospace" font-size="12" fill="#172126">${escape(shorten(node.preview))}</text>',
      );
    }
    return '${out.toString()}</svg>';
  }

  Future<List<int>> png() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final scale = math.min(1.0, 8192 / math.max(width, height));
    canvas.scale(scale);
    GraphPainter(
      this,
      const Color(0xff173f39),
      const {},
    ).paint(canvas, Size(width, height));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * scale).ceil(),
      (height * scale).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes!.buffer.asUint8List();
  }
}

class GraphPainter extends CustomPainter {
  GraphPainter(
    this.layout,
    this.foreground,
    this.matches, {
    this.expanded,
    this.activeMatch,
    this.codeStyle = const TextStyle(fontFamily: 'monospace'),
  });
  final TextStyle codeStyle;
  final Set<String>? expanded;
  final String? activeMatch;
  final GraphLayout layout;
  final Color foreground;
  final Set<String> matches;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = layout.background);
    final edgePaint = Paint()
      ..color = layout.connectorColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final node in layout.nodes) {
      final parent = layout.parents[node.path];
      if (parent == null) continue;
      final points = layout.connector(
        layout.boxes[parent]!,
        layout.boxes[node.path]!,
      );
      canvas.drawPath(Path()..addPolygon(points, false), edgePaint);
      if (layout.diagram) {
        final start = points.first;
        canvas.drawPath(
          Path()..addPolygon([
            start,
            start.translate(4, 6),
            start.translate(0, 12),
            start.translate(-4, 6),
          ], true),
          Paint()..color = layout.connectorColor,
        );
      }
      if (layout.radial) {
        final tip = points.last;
        final delta = tip - points.first;
        final direction = delta / delta.distance;
        final base = tip - direction * 8;
        final wing = Offset(-direction.dy, direction.dx) * 3;
        canvas.drawPath(
          Path()..addPolygon([tip, base + wing, base - wing], true),
          Paint()..color = layout.connectorColor,
        );
      }
    }
    for (final n in layout.nodes) {
      final r = layout.boxes[n.path]!;
      final shape = RRect.fromRectAndRadius(
        r,
        Radius.circular(layout.radial ? r.width / 2 : 7),
      );
      final active = n.path == activeMatch;
      final matched = matches.contains(n.path);
      if (active) {
        canvas.drawRRect(
          shape.inflate(4),
          Paint()..color = const Color(0xffff8a35),
        );
      }
      canvas.drawRRect(
        shape,
        Paint()
          ..color = matched ? const Color(0xffffdf70) : layout.fills[n.path]!,
      );
      if (matched) {
        canvas.drawRRect(
          shape,
          Paint()
            ..color = foreground
            ..strokeWidth = active ? 3 : 2
            ..style = PaintingStyle.stroke,
        );
      }
      final showToggle = expanded != null && n.hasChildren;
      if (showToggle) {
        final center = layout.radial
            ? r.center
            : Offset(r.right - 15, layout.diagram ? r.top + 24 : r.center.dy);
        if (!layout.radial) {
          canvas.drawCircle(center, 9, Paint()..color = foreground);
        }
        final mark = Paint()
          ..color = layout.radial ? foreground : Colors.white
          ..strokeWidth = 1.6;
        canvas.drawLine(center.translate(-4, 0), center.translate(4, 0), mark);
        if (!expanded!.contains(n.path)) {
          canvas.drawLine(
            center.translate(0, -4),
            center.translate(0, 4),
            mark,
          );
        }
      }
      if (layout.diagram) {
        canvas.drawLine(
          Offset(r.left, r.top + 39),
          Offset(r.right, r.top + 39),
          Paint()..color = foreground.withValues(alpha: .55),
        );
        final rows = ['«${n.type}»', n.label, ...layout.details(n)];
        for (var i = 0; i < rows.length; i++) {
          final row = TextPainter(
            text: TextSpan(
              text: rows[i],
              style: codeStyle.copyWith(
                color: foreground,
                fontSize: 11,
                fontWeight: i == 1 ? FontWeight.bold : null,
              ),
            ),
            maxLines: 1,
            ellipsis: '…',
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: r.width - (i == 1 && showToggle ? 38 : 20));
          row.paint(
            canvas,
            Offset(
              r.left + 10,
              r.top + (i < 2 ? 4 + i * 16 : 42 + (i - 2) * 14),
            ),
          );
          row.dispose();
        }
        continue;
      }
      final text =
          TextPainter(
            text: TextSpan(
              text: layout.radial ? n.label : '${n.label}\n${n.preview}',
              style: codeStyle.copyWith(
                color: layout.radial ? layout.labelColor : foreground,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            maxLines: layout.radial ? 1 : 2,
            ellipsis: '…',
            textDirection: TextDirection.ltr,
          )..layout(
            maxWidth: layout.radial ? 96 : r.width - (showToggle ? 38 : 20),
          );
      text.paint(
        canvas,
        Offset(
          layout.radial ? r.right + 5 : r.left + 10,
          r.center.dy - text.height / 2,
        ),
      );
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
