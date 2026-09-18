import 'dart:async';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di/service_locator.dart';
import 'core/utils/platform_utils.dart';
import 'features/chat/data/datasources/chat_local_datasource.dart';
import 'features/sound/data/datasources/tts_datasource.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  // Run chat data migration (previously in datasource constructor)
  await getIt<ChatLocalDatasource>().init();
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
  // Load saved language preference, falling back to device locale
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  final String initialLanguage = savedLanguage ?? deviceLocale.languageCode;
  if (PlatformUtils.isMobile()) {
    await Alarm.init();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
  if (PlatformUtils.checkPlatform() != 'Web' &&
      PlatformUtils.checkPlatform() != 'MacOS') {
    unawaited(
      TtsDatasource.initSupertonic().catchError((Object error, StackTrace st) {
        // Startup should never be blocked by optional TTS warmup.
      }),
    );
  }
  runApp(App(initialLanguage: initialLanguage));
}
