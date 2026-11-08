import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../app_info.dart';
import '../models/window_geometry.dart';

import 'dart:math' as math;

abstract class WindowHost {
  Future<WindowGeometry> restore(WindowGeometry geometry);
  Future<WindowGeometry?> read(WindowGeometry previous);
  void addListener(WindowListener listener);
  void removeListener(WindowListener listener);
}

class NativeWindowHost implements WindowHost {
  static bool get supported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  @override
  Future<WindowGeometry> restore(WindowGeometry geometry) async {
    await windowManager.ensureInitialized();
    Size? workArea;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      workArea = display.visibleSize ?? display.size;
      if (workArea.width > 0 && workArea.height > 0) {
        geometry = geometry.fitTo(workArea);
      }
    } on PlatformException {
      /* The window manager can still constrain its size. */
    }
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        title: appName,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        backgroundColor: const Color(0x00000000),
        size: geometry.size,
        center: true,
        minimumSize: Size(
          math.min(360, workArea?.width ?? 360),
          math.min(300, workArea?.height ?? 300),
        ),
      ),
    );
    if (geometry.maximized) await windowManager.maximize();
    // The native runners show the window after Flutter's first frame.
    return geometry;
  }

  @override
  Future<WindowGeometry?> read(WindowGeometry previous) async {
    if (await windowManager.isMinimized() ||
        await windowManager.isFullScreen()) {
      return null;
    }
    if (await windowManager.isMaximized()) {
      return previous.copyWith(maximized: true);
    }
    final size = await windowManager.getSize();
    // Maximizing may race with a resize notification. Never save maximized
    // dimensions as the normal size used when the user restores the window.
    if (await windowManager.isMaximized()) {
      return previous.copyWith(maximized: true);
    }
    if (size.width < 360 ||
        size.height < 300 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return null;
    }
    return previous.copyWith(size: size, maximized: false);
  }

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);
  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}

class WindowSession with WindowListener {
  WindowSession({
    required this.host,
    required this.geometry,
    this.onChanged,
    this.debounce = const Duration(milliseconds: 400),
  });
  final WindowHost host;
  WindowGeometry geometry;
  Future<void> Function(WindowGeometry)? onChanged;
  final Duration debounce;
  Timer? _timer;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  Future<void> restore() async {
    geometry = await host.restore(geometry);
    host.addListener(this);
  }

  Future<void> capture() {
    final operation = _pending.then((_) async {
      if (_disposed) return;
      final next = await host.read(geometry);
      if (_disposed || next == null || next == geometry) return;
      geometry = next;
      await onChanged?.call(next);
    });
    // Native reads can fail while the OS is destroying the window. The most
    // recent usable geometry remains available to preference writes.
    _pending = operation.catchError((Object _) {});
    return _pending;
  }

  Future<void> flush() async {
    _timer?.cancel();
    await capture();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(capture()));
  }

  @override
  void onWindowResize() => _schedule();
  @override
  void onWindowResized() => _schedule();
  @override
  void onWindowMaximize() => _schedule();
  @override
  void onWindowUnmaximize() => _schedule();
  @override
  void onWindowRestore() => _schedule();
  @override
  void onWindowLeaveFullScreen() => _schedule();
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    host.removeListener(this);
    onChanged = null;
  }
}
