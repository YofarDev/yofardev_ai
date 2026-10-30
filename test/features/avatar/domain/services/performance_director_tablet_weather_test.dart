import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';

/// M8 ruling 14: the looked-up city's weather on the tablet the weather
/// lookup pulls out; reset when the tablet is put away.
void main() {
  late DateTime currentTime;
  late StreamController<TabletWeatherReading> readings;

  PerformanceDirector build() {
    currentTime = DateTime(2026, 10, 31, 12);
    readings = StreamController<TabletWeatherReading>.broadcast(sync: true);
    return PerformanceDirector(
      now: () => currentTime,
      tabletWeather: readings.stream,
    );
  }

  void advance(FakeAsync async, int ms) {
    currentTime = currentTime.add(Duration(milliseconds: ms));
    async.elapse(Duration(milliseconds: ms));
  }

  const TabletWeatherReading tokyo = TabletWeatherReading(
    conditionId: 501,
    temperatureC: 17.6,
  );

  test('a weather lookup shows the reading on the tablet', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      director.setActiveTool('getCurrentWeather');
      expect(director.current.prop, AvatarProp.tablet);
      expect(director.current.tabletWeather, TabletWeather.none);
      readings.add(tokyo);
      expect(director.current.tabletWeather, TabletWeather.rain);
      expect(director.current.tabletTemp, 18);
      director.dispose();
    });
  });

  test('the card stays through the hold-over and resets on put-away', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      final List<PerformanceIntent> intents = <PerformanceIntent>[];
      director.intents.listen(intents.add);
      director.setActiveTool('getCurrentWeather');
      readings.add(tokyo);
      director.setActiveTool(null);
      // execution ruling 32: a card is held longer than a plain hold-over,
      // so the avatar reads it
      advance(async, PerformanceDirector.weatherCardHold.inMilliseconds - 100);
      expect(director.current.prop, AvatarProp.tablet);
      expect(director.current.tabletWeather, TabletWeather.rain);
      advance(async, 200);
      expect(director.current.prop, AvatarProp.none);
      expect(director.current.tabletWeather, TabletWeather.none);
      expect(director.current.tabletTemp, 0);
      // The intent that puts the tablet away already has no card.
      final PerformanceIntent away = intents.firstWhere(
        (PerformanceIntent i) => i.prop == AvatarProp.none,
      );
      expect(away.tabletWeather, TabletWeather.none);
      // The idle ladder's tablet later shows the generic card.
      director.setIdleStage(3);
      expect(director.current.prop, AvatarProp.tablet);
      expect(director.current.tabletWeather, TabletWeather.none);
      director.dispose();
    });
  });

  test('a weather lookup without a reading keeps the short hold-over', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      director.setActiveTool('getCurrentWeather');
      director.setActiveTool(null);
      advance(async, PerformanceDirector.tabletHoldOver.inMilliseconds + 100);
      expect(director.current.prop, AvatarProp.none);
      director.dispose();
    });
  });

  test('speaking puts the tablet away with its card', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      director.setActiveTool('getCurrentWeather');
      readings.add(tokyo);
      director.setSpeaking(true);
      expect(director.current.tabletWeather, TabletWeather.none);
      director.setSpeaking(false);
      director.setActiveTool('searchGoogle');
      expect(director.current.prop, AvatarProp.tablet);
      expect(director.current.tabletWeather, TabletWeather.none);
      director.dispose();
    });
  });

  test('a reading outside a weather lookup is ignored', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      readings.add(tokyo);
      director.setActiveTool('searchGoogle');
      readings.add(tokyo);
      expect(director.current.tabletWeather, TabletWeather.none);
      // a fresh weather lookup does not show the old reading
      director.setActiveTool('getCurrentWeather');
      expect(director.current.tabletWeather, TabletWeather.none);
      director.dispose();
    });
  });

  test('another tool after the weather lookup clears the card', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      director.setActiveTool('getCurrentWeather');
      readings.add(tokyo);
      director.setActiveTool('searchGoogle');
      expect(director.current.prop, AvatarProp.tablet);
      expect(director.current.tabletWeather, TabletWeather.none);
      director.dispose();
    });
  });

  test('count is an auto gesture for list sentences', () {
    fakeAsync((FakeAsync async) {
      final PerformanceDirector director = build();
      director.onSentence('First the eggs, second the flour, third the milk.');
      expect(director.current.pendingGesture, AvatarGesture.count);
      director.dispose();
    });
  });
}
