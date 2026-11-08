import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/models/app_settings.dart';
import 'package:visor_config/models/window_geometry.dart';
import 'package:visor_config/repositories/settings_repository.dart';
import 'package:visor_config/services/window_session.dart';
import 'package:window_manager/window_manager.dart';

class FakeWindowHost implements WindowHost {
  WindowGeometry? next;
  WindowGeometry? restored;
  WindowListener? listener;
  int reads = 0;
  @override
  Future<WindowGeometry> restore(WindowGeometry geometry) async {
    restored = geometry;
    return geometry;
  }

  @override
  Future<WindowGeometry?> read(WindowGeometry previous) async {
    reads++;
    return next;
  }

  @override
  void addListener(WindowListener value) => listener = value;
  @override
  void removeListener(WindowListener value) => listener = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Restores valid saved window geometry and accepts older settings files',
    () async {
      final directory = await Directory.systemTemp.createTemp('visor-window-');
      addTearDown(() => directory.delete(recursive: true));
      final store = SettingsRepository(directory: directory);
      const geometry = WindowGeometry(
        width: 1100,
        height: 810,
        maximized: true,
      );
      await store.save(const AppSettings(language: 'pt', window: geometry));
      final restored = await SettingsRepository(directory: directory).load();
      expect(restored.window, geometry);
      expect(restored.language, 'pt');
      final host = FakeWindowHost();
      final session = WindowSession(host: host, geometry: restored.window);
      await session.restore();
      expect(host.restored, geometry);
      expect(host.listener, session);
      session.dispose();
      expect(host.listener, isNull);
      expect(
        AppSettings.fromJson({'theme': 'dark'}).window,
        const WindowGeometry(),
      );
    },
  );
  test('Rejects corrupt dimensions and fits smaller screens without changing maximized state', () {
    final invalid = WindowGeometry.fromJson({
      'width': -1,
      'height': 'bad',
      'maximized': 'yes',
    });
    expect(invalid, const WindowGeometry());
    expect(WindowGeometry.fromJson({'width': double.infinity}).width, 1280);
    final fitted = const WindowGeometry(
      width: 3000,
      height: 2000,
      maximized: true,
    ).fitTo(const Size(1024, 768));
    expect(fitted.size, const Size(1024, 768));
    expect(fitted.maximized, isTrue);
  });
  testWidgets(
    'Resize events debounce and flush captures a last resize before closing',
    (tester) async {
      final host = FakeWindowHost()
        ..next = const WindowGeometry(width: 1000, height: 760);
      final saved = <WindowGeometry>[];
      final session = WindowSession(
        host: host,
        geometry: const WindowGeometry(),
        onChanged: (geometry) async {
          saved.add(geometry);
        },
      );
      await session.restore();
      for (var i = 0; i < 5; i++) {
        session.onWindowResize();
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(host.reads, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(host.reads, 1);
      expect(saved.single.size, const Size(1000, 760));
      host.next = const WindowGeometry(width: 1200, height: 900);
      session.onWindowResize();
      await session.flush();
      expect(saved.last.size, const Size(1200, 900));
      final count = host.reads;
      session.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(host.reads, count);
    },
  );
  test(
    'Native snapshots retain normal dimensions when maximized or minimized',
    () async {
      const channel = MethodChannel('window_manager');
      var maximized = true, minimized = false, fullScreen = false;
      var maximizeReads = 0;
      var race = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'isMinimized':
                return minimized;
              case 'isFullScreen':
                return fullScreen;
              case 'isMaximized':
                return race ? ++maximizeReads > 1 : maximized;
              case 'getBounds':
                return {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final host = NativeWindowHost();
      const normal = WindowGeometry(width: 950, height: 740);
      expect(await host.read(normal), normal.copyWith(maximized: true));
      minimized = true;
      expect(await host.read(normal), isNull);
      minimized = false;
      fullScreen = true;
      expect(await host.read(normal), isNull);
      fullScreen = false;
      maximized = false;
      expect((await host.read(normal))!.size, const Size(1920, 1080));
      race = true;
      expect(await host.read(normal), normal.copyWith(maximized: true));
    },
  );
}
