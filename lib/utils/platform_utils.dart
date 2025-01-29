import 'dart:io';

import 'package:flutter/foundation.dart';


class PlatformUtils {

  static String checkPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isMacOS) {
      return 'MacOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }

  static bool isMobile() {
    final String platform = checkPlatform();
    return platform == 'Android' || platform == 'iOS';
  }
}
