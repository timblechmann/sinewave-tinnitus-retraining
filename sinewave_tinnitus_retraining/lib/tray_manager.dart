import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// Manages the system tray icon and menu for desktop platforms.
class AppTrayManager with TrayListener {
  final VoidCallback onShowWindow;
  final VoidCallback onHideWindow;
  final VoidCallback onExitApp;
  final bool Function() isWindowVisible;

  AppTrayManager({
    required this.onShowWindow,
    required this.onHideWindow,
    required this.onExitApp,
    required this.isWindowVisible,
  });

  /// Initializes the tray icon and menu.
  Future<void> init() async {
    try {
      final iconPath = Platform.isWindows
          ? 'assets/images/app_icon.ico'
          : 'assets/images/app_icon.png';

      await trayManager.setIcon(iconPath);
      await _updateTrayMenu();
      trayManager.addListener(this);
    } catch (e) {
      throw Exception('Failed to initialize tray: $e');
    }
  }

  /// Updates the tray menu based on current window visibility.
  Future<void> _updateTrayMenu() async {
    final menu = Menu(
      items: [
        if (isWindowVisible())
          MenuItem(key: 'hide_window', label: 'Hide Window')
        else
          MenuItem(key: 'show_window', label: 'Show Window'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit App'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Disposes the tray manager and removes listeners.
  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    _updateTrayMenu();
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Do nothing - menu is handled on left click
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        onShowWindow();
        break;
      case 'hide_window':
        onHideWindow();
        break;
      case 'exit_app':
        onExitApp();
        break;
    }
  }
}
