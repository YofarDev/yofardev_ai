import 'dart:math';

enum AvatarBackgrounds {
  lake,
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
  snowyMountain,
}

extension BgImagesStrExtension on String {
  AvatarBackgrounds? getBgImageFromString() {
    final String enumString =
        split('.').last.replaceAll('[', '').replaceAll(']', '');
    try {
      return AvatarBackgrounds.values.firstWhere(
        (AvatarBackgrounds e) => e.toString().split('.').last == enumString,
      );
    } catch (e) {
      return null;
    }
  }
}

extension BgImagesExtension on AvatarBackgrounds? {
  AvatarBackgrounds getRandomBgImage() {
    final List<AvatarBackgrounds> bgImagesList =
        AvatarBackgrounds.values.toList();
    final Random random = Random();
    return bgImagesList[random.nextInt(bgImagesList.length)];
  }

  String getPath() => 'assets/avatar/backgrounds/${this!.name}.jpeg';
}
