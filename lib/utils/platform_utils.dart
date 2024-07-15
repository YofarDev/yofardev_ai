// Conditional import
import 'platform_io.dart' if (dart.library.html) 'platform_web.dart'
    as platform;

String checkPlatform() {
  if (platform.isAndroid) {
    return 'Android';
  } else if (platform.isIOS) {
    return 'iOS';
  } else if (platform.isWeb) {
    return 'Web';
  } else {
    return 'Other';
  }
}
