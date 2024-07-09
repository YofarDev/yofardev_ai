enum BgImages {
  mountainsAndLake,
  ocean,
  forest,
  // street,
  // sakuraTrees,
  // library,
  // classroom,
  // mall,
  // park,
}

BgImages? getBgImageFromString(String bgString) {
  final String enumString =
      bgString.split('.').last.replaceAll('[', '').replaceAll(']', '');
  try {
    return BgImages.values.firstWhere(
      (BgImages e) => e.toString().split('.').last == enumString,
    );
  } catch (e) {
    return null;
  }
}
