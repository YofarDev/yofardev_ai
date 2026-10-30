import 'package:flutter/widgets.dart';

/// Pauses the world's timers while the app is in the background and resumes
/// them when it comes back (no network and no wake-ups while paused).
///
/// `inactive` is ignored: on desktop it is just a lost focus.
class WorldLifecycleObserver with WidgetsBindingObserver {
  WorldLifecycleObserver({required this.onResume, required this.onPause});

  final VoidCallback onResume;
  final VoidCallback onPause;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        onPause();
      case AppLifecycleState.inactive:
        break;
    }
  }
}
