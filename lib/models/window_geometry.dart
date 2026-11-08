import 'dart:ui';

import 'dart:math' as math;

class WindowGeometry {
  const WindowGeometry({
    this.width = 1280,
    this.height = 720,
    this.maximized = false,
  });
  final double width, height;
  final bool maximized;
  Size get size => Size(width, height);
  factory WindowGeometry.fromJson(Object? value) {
    if (value is! Map) return const WindowGeometry();
    double dimension(String key, double fallback, double minimum) {
      final number = value[key];
      return number is num &&
              number.isFinite &&
              number >= minimum &&
              number <= 16384
          ? number.toDouble()
          : fallback;
    }

    return WindowGeometry(
      width: dimension('width', 1280, 360),
      height: dimension('height', 720, 300),
      maximized: value['maximized'] == true,
    );
  }
  WindowGeometry copyWith({Size? size, bool? maximized}) => WindowGeometry(
    width: size?.width ?? width,
    height: size?.height ?? height,
    maximized: maximized ?? this.maximized,
  );
  WindowGeometry fitTo(Size workArea) => copyWith(
    size: Size(
      width.clamp(math.min(360, workArea.width), workArea.width),
      height.clamp(math.min(300, workArea.height), workArea.height),
    ),
  );
  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'maximized': maximized,
  };
  @override
  bool operator ==(Object other) =>
      other is WindowGeometry &&
      width == other.width &&
      height == other.height &&
      maximized == other.maximized;
  @override
  int get hashCode => Object.hash(width, height, maximized);
}
