import 'dart:async';

import 'package:flutter/material.dart';

enum DemoStatus { idle, countdown, completed }

class DemoController extends ChangeNotifier {
  static final DemoController _instance = DemoController._internal();
  factory DemoController() => _instance;
  DemoController._internal();

  DemoStatus _status = DemoStatus.idle;
  DemoStatus get status => _status;
  bool get isIdle => _status == DemoStatus.idle;

  int _countdownValue = 0;
  int get countdownValue => _countdownValue;

  final StreamController<DemoStatus> _statusController =
      StreamController<DemoStatus>.broadcast();
  Stream<DemoStatus> get statusStream => _statusController.stream;

  void _setStatus(DemoStatus status) {
    _status = status;
    notifyListeners();
    _statusController.add(status);
  }

  Future<void> startCountdown() async {
    _setStatus(DemoStatus.countdown);
    for (int i = 3; i > 0; i--) {
      _countdownValue = i;
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    _countdownValue = 0;
    notifyListeners();
  }

  void complete() {
    _setStatus(DemoStatus.completed);
  }

  void reset() {
    _setStatus(DemoStatus.idle);
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
