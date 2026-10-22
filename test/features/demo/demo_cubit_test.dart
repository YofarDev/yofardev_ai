import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/demo/domain/services/demo_controller.dart';

class MockDemoService extends Mock implements DemoService {}

void main() {
  setUpAll(() {
    registerFallbackValue(DemoScripts.beachDemo);
  });

  late DemoController controller;
  late MockDemoService demoService;
  late DemoCubit cubit;

  setUp(() {
    controller = DemoController()..reset();
    demoService = MockDemoService();
    cubit = DemoCubit(demoController: controller, demoService: demoService);
  });

  tearDown(() async => cubit.close());

  test('startDemoMode activates the service and reflects the script', () async {
    const DemoScript script = DemoScripts.beachDemo;
    when(
      () => demoService.activateDemo(
        chatId: any(named: 'chatId'),
        script: any(named: 'script'),
      ),
    ).thenAnswer((_) async {});

    await cubit.startDemoMode(chatId: 'chat-1', script: script);

    verify(
      () => demoService.activateDemo(chatId: 'chat-1', script: script),
    ).called(1);
    expect(cubit.state.currentScript, script);
    expect(cubit.state.remainingResponses, script.responses.length);
  });

  test(
    'controller notifications mirror controller state into cubit state',
    () async {
      // startCountdown is Timer-based (three 1-second real delays); await it so
      // the countdown fully drains before asserting the mirrored state.
      await controller.startCountdown();

      expect(cubit.state.status, controller.status);
      expect(cubit.state.countdownValue, controller.countdownValue);
      expect(cubit.state.status, DemoStatus.countdown);
    },
  );

  test('resetDemo returns to the initial state', () {
    cubit.resetDemo();
    expect(cubit.state, const DemoState());
  });
}
