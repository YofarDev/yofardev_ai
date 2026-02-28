import 'dart:io';
import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/logger.dart';
import '../utils/extensions.dart';

class AlarmService {
  static Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final PermissionStatus status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      final PermissionStatus res = await Permission.scheduleExactAlarm
          .request();
      AppLogger.debug(res.toString(), tag: 'AlarmService');
    }
  }

  static Future<String> setAlarm(int minutesFromNow, String message) async {
    try {
      await checkAndroidScheduleExactAlarmPermission();
      final DateTime dateTime = DateTime.now().add(
        Duration(minutes: minutesFromNow),
      );
      final AlarmSettings alarmSettings = AlarmSettings(
        id: Random().nextInt(100),
        volumeSettings: VolumeSettings.fixed(volume: 100),
        dateTime: dateTime,
        warningNotificationOnKill: Platform.isIOS,
        assetAudioPath: 'assets/chillAlarm.mp3',
        notificationSettings: NotificationSettings(
          title: 'Yofardev AI',
          body: message,
        ),
      );
      await Alarm.set(alarmSettings: alarmSettings);
      return 'Alarm set for ${dateTime.toLongLocalDateString()}';
    } catch (e) {
      return 'Error setting alarm: $e';
    }
  }
}
