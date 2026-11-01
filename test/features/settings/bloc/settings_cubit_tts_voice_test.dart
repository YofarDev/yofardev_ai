import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

import '../../sound/kokoro/fake_tts_engine_status_service.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockLlmService extends Mock implements LlmServiceInterface {}

void main() {
  SettingsCubit cubit(FakeTtsEngineStatusService engine) => SettingsCubit(
    settingsRepository: _MockSettingsRepository(),
    llmService: _MockLlmService(),
    ttsEngineStatusService: engine,
  );

  test('starts from the engine\'s current status', () async {
    final SettingsCubit subject = cubit(
      FakeTtsEngineStatusService(const TtsEngineStatus.ready()),
    );

    expect(subject.state.ttsEngineStatus, const TtsEngineStatus.ready());
    await subject.close();
  });

  test('mirrors every status change', () async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService();
    final SettingsCubit subject = cubit(engine);

    engine.emit(const TtsEngineStatus.downloading(0.4));
    await Future<void>.delayed(Duration.zero);
    expect(
      subject.state.ttsEngineStatus,
      const TtsEngineStatus.downloading(0.4),
    );

    const TtsEngineStatus failed = TtsEngineStatus.failed(
      NetworkFailure('offline'),
    );
    engine.emit(failed);
    await Future<void>.delayed(Duration.zero);
    expect(subject.state.ttsEngineStatus, failed);
    await subject.close();
  });

  test('installTtsVoice starts the install', () async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService();
    final SettingsCubit subject = cubit(engine);

    await subject.installTtsVoice();

    expect(engine.installs, 1);
    await subject.close();
  });

  test('no engine: stays not installed and install is a no-op', () async {
    final SettingsCubit subject = SettingsCubit(
      settingsRepository: _MockSettingsRepository(),
      llmService: _MockLlmService(),
    );

    await subject.installTtsVoice();

    expect(subject.state.ttsEngineStatus, const TtsEngineStatus.notInstalled());
    await subject.close();
  });
}
