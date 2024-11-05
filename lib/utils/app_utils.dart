class AppUtils {
  double getInvertedY({
    required double itemY,
    required double itemHeight,
    required double scaleFactor,
    required double baseOriginalHeight,
  }) {
    return (baseOriginalHeight - itemY - itemHeight) * scaleFactor;
  }
}
