import 'package:flutter/material.dart';

import '../../../l10n/localization_manager.dart';

/// Toggle switch for sound effects
class SoundEffectsToggle extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const SoundEffectsToggle({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          localized.enableSoundEffects,
          style: const TextStyle(fontSize: 20),
        ),
        Switch(
          value: isEnabled,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
