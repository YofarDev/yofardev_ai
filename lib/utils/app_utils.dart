import 'package:flutter/foundation.dart';

import 'platform_utils.dart';

class AppUtils {
  double getInvertedY({
    required double itemY,
    required double itemHeight,
    required double scaleFactor,
    required double baseOriginalHeight,
  }) {
    return (baseOriginalHeight - itemY - itemHeight) * scaleFactor;
  }

  static String fixAssetsPath(String path) {
    final bool isWebDeployed = PlatformUtils.checkPlatform() == 'Web' && !kDebugMode;
    if (isWebDeployed) {
      // return "yofardev-ai/$path";
      return path;
    } else {
      return path;
    }
  }
}
