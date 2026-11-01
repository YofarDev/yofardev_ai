import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/world/world_lifecycle_observer.dart';

void main() {
  test('pauses in the background, resumes in the foreground', () {
    final List<String> log = <String>[];
    final WorldLifecycleObserver observer = WorldLifecycleObserver(
      onResume: () => log.add('resume'),
      onPause: () => log.add('pause'),
    );
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(log, <String>['pause', 'resume', 'pause']);
  });
}
