import 'dart:io';

import 'package:flutter/foundation.dart';

/// Utility class for platform-specific checks and operations.
class PlatformUtils {
  /// Checks if the current platform is a desktop platform (macOS, Linux, Windows).
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  /// Checks if the current platform is mobile (Android, iOS).
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
