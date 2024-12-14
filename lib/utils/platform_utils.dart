import 'dart:io';

import 'package:flutter/foundation.dart';


class PlatformUtils {

  static String checkPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else {
      return 'Other';
    }
  }
}
