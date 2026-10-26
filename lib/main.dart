import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/utils/platform_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  await bootstrapApp();
  if (PlatformUtils.isDesktop()) {
    await windowManager.ensureInitialized();
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final double displayHeight = primaryDisplay.size.height * 0.8;
    final WindowOptions windowOptions = WindowOptions(
      size: Size(displayHeight * 9 / 16, displayHeight),
      title: "Yofardev AI",
      center: true,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  if (PlatformUtils.isMobile()) {
    await Alarm.init();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const App());
}
