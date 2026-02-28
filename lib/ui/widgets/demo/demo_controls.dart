import 'package:flutter/material.dart';

import '../../../models/demo_script.dart';
import '../../../services/demo_controller.dart';
import '../../../services/demo_service.dart';

class DemoControls extends StatefulWidget {
  const DemoControls({super.key});

  @override
  State<DemoControls> createState() => DemoControlsState();
}

class DemoControlsState extends State<DemoControls> {
  final DemoService _demoService = DemoService();

  @override
  void initState() {
    super.initState();
    _demoService.controller.statusStream.listen((DemoStatus status) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _demoService.deactivateDemo();
    super.dispose();
  }

  Future<void> startDemo() async {
    await _demoService.activateDemo(
      context: context,
      script: DemoScripts.beachDemo,
    );
  }

  DemoStatus get status => _demoService.controller.status;
  int get countdownValue => _demoService.controller.countdownValue;
  bool get isActive => _demoService.isActive;
  int get remainingResponses => _demoService.fakeLlmService.remainingResponses;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (_demoService.controller.status == DemoStatus.countdown)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${_demoService.controller.countdownValue}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_demoService.controller.status != DemoStatus.countdown)
            const SizedBox(height: 8),
          if (_demoService.controller.status != DemoStatus.countdown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(_demoService.controller.status),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText(DemoStatus status) {
    switch (status) {
      case DemoStatus.idle:
        return 'Demo';
      case DemoStatus.countdown:
        return 'Démarrage...';
      case DemoStatus.completed:
        return '${_demoService.fakeLlmService.remainingResponses} réponses restantes';
    }
  }
}
