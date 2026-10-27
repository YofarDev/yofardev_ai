import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/core/design/rive/rive_vm_binding.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// Drives [RiveVmBinding] against the real `avatar.riv` the way the view
/// does while the avatar talks: the same properties pushed on every rebuild.
///
/// Runs on macOS (`flutter test integration_test/rive_vm_binding_test.dart
/// -d macos`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File file;
  late RiveWidgetController controller;
  late RiveVmBinding binding;

  setUp(() async {
    file = (await File.asset(
      AvatarRiveContract.avatarAssetPath,
      riveFactory: Factory.rive,
    ))!;
    controller = RiveWidgetController(
      file,
      artboardSelector: ArtboardSelector.byName(
        AvatarRiveContract.avatarArtboard,
      ),
      stateMachineSelector: StateMachineSelector.byName(
        AvatarRiveContract.avatarStateMachine,
      ),
    );
    binding = RiveVmBinding(controller);
  });

  tearDown(() {
    binding.dispose();
    controller.dispose();
    file.dispose();
  });

  test('binds to AvatarVM', () {
    expect(binding.hasViewModel, isTrue);
  });

  test('repeated pushes across many rebuilds keep writing values', () {
    for (int frame = 0; frame < 500; frame++) {
      binding.setNumber(AvatarRiveContract.propMouth, (frame % 5).toDouble());
      binding.setEnum(
        AvatarRiveContract.propMood,
        AvatarRiveContract.moodValues,
        AvatarRiveContract.moodValues[frame % 2],
      );
      binding.setEnum(
        AvatarRiveContract.propHat,
        AvatarRiveContract.hatValues,
        'beanie',
      );
    }
    final ViewModelInstance vmi = binding.viewModelInstance!;
    expect(vmi.number(AvatarRiveContract.propMouth)!.value, 4.0);
    expect(
      vmi.enumerator(AvatarRiveContract.propMood)!.value,
      AvatarRiveContract.moodValues[1],
    );
    expect(vmi.enumerator(AvatarRiveContract.propHat)!.value, 'beanie');
  });

  test('a value changed after an identical push is still written', () {
    binding.setEnum(
      AvatarRiveContract.propPresence,
      AvatarRiveContract.presenceValues,
      'outOfScreen',
    );
    binding.setEnum(
      AvatarRiveContract.propPresence,
      AvatarRiveContract.presenceValues,
      'outOfScreen',
    );
    binding.setEnum(
      AvatarRiveContract.propPresence,
      AvatarRiveContract.presenceValues,
      'onScreen',
    );
    expect(
      binding.viewModelInstance!
          .enumerator(AvatarRiveContract.propPresence)!
          .value,
      'onScreen',
    );
  });

  test('triggers fire repeatedly and missing names are ignored', () {
    for (int i = 0; i < 20; i++) {
      binding.fireTrigger(AvatarRiveContract.propGestureTrigger);
    }
    binding.fireTrigger('doesNotExist');
    binding.setNumber('doesNotExist', 1.0);
    binding.setBool('doesNotExist', true);
    binding.setColor('doesNotExist', const Color(0xFF000000));
  });
}
