import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Wrapper for window management operations with workarounds for desktop behavior.
class WindowManagerWrapper with WindowListener {
  final VoidCallback onWindowCloseCallback;
  bool _isWindowVisible = true;

  WindowManagerWrapper({required this.onWindowCloseCallback});

  /// Initializes the window manager for desktop.
  Future<void> init() async {
    await windowManager.ensureInitialized();

    // Prevent the app from closing when the window is closed.
    await windowManager.setPreventClose(true);

    // Show window on startup.
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(this);
  }

  /// Returns whether the window is currently visible.
  bool get isWindowVisible => _isWindowVisible;

  /// Hides the window using a workaround: moves it off-screen instead of hiding.
  /// This prevents crashes associated with window hiding on some platforms.
  Future<void> hideWindow() async {
    await windowManager.setPosition(const Offset(10000, 10000));
    _isWindowVisible = false;
  }

  /// Shows the window by centering it and bringing it to focus.
  Future<void> showWindow() async {
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    _isWindowVisible = true;
  }

  /// Destroys the window and exits the app.
  Future<void> destroy() async {
    await windowManager.destroy();
  }

  /// Disposes the wrapper and removes listeners.
  void dispose() {
    windowManager.removeListener(this);
  }

  @override
  void onWindowClose() {
    // Intercept window close to hide instead of quit.
    onWindowCloseCallback();
  }
}
