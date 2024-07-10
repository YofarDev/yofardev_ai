import 'dart:math';

enum BgImages {
  mountainsAndLake,
  beach,
  forest,
  street,
  sakuraTrees,
  library,
  classroom,
  mall,
  park,
  restaurant,
  bedroom,
  livingRoom,
  campfire,
  parisianCafe,
  office,
  japaneseGarden,
}

extension BgImagesStrExtension on String {
  BgImages? getBgImageFromString() {
    final String enumString =
        split('.').last.replaceAll('[', '').replaceAll(']', '');
    try {
      return BgImages.values.firstWhere(
        (BgImages e) => e.toString().split('.').last == enumString,
      );
    } catch (e) {
      return null;
    }
  }
}

extension BgImagesExtension on BgImages? {
  BgImages getRandomBgImage() {
    final List<BgImages> bgImagesList = BgImages.values.toList();
    final Random random = Random();
    return bgImagesList[random.nextInt(bgImagesList.length)];
  }
}
