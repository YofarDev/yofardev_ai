import 'package:shared_preferences/shared_preferences.dart';

import '../models/bg_images.dart';

class AvatarService {
  Future<void> setCurrentBg(BgImages bgImage) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgImage', bgImage.name);
  }

  Future<BgImages> getCurrentBg() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? bgImage = prefs.getString('bgImage');
    if (bgImage != null) {
      return getBgImageFromString(bgImage)!;
    } else {
      return BgImages.mountainsAndLake;
    }
  }
}
