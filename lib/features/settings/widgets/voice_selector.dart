import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../l10n/localization_manager.dart';
import '../../../models/voice.dart';
import '../../../utils/platform_utils.dart';

/// Voice selector dropdown with preview functionality
class VoiceSelector extends StatelessWidget {
  final Voice? selectedVoice;
  final List<Voice> availableVoices;
  final ValueChanged<Voice> onVoiceChanged;
  final String currentLanguage;

  const VoiceSelector({
    super.key,
    required this.selectedVoice,
    required this.availableVoices,
    required this.onVoiceChanged,
    required this.currentLanguage,
  });

  Future<void> _previewVoice(Voice voice) async {
    final String text = currentLanguage == 'fr'
        ? "Bonjour, c'est un test"
        : 'Hello, this is a test';

    final FlutterTts tts = FlutterTts();
    await tts.setLanguage(voice.locale);
    await tts.setVoice(<String, String>{
      "name": voice.name,
      "locale": voice.locale,
    });
    await tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localized.ttsVoices,
            style: const TextStyle(fontSize: 20),
          ),
          if (selectedVoice?.locale.isEmpty ?? true)
            const SizedBox.shrink()
          else
            Align(
              alignment: Alignment.centerRight,
              child: DropdownButton<Voice>(
                value: selectedVoice,
                items: availableVoices
                    .map<DropdownMenuItem<Voice>>((Voice value) {
                  return DropdownMenuItem<Voice>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (Voice? value) async {
                  if (value != null) {
                    onVoiceChanged(value);
                    await _previewVoice(value);
                  }
                },
              ),
            ),
          if (PlatformUtils.checkPlatform() == 'Android')
            Text(localized.moreVoicesAndroid),
          if (PlatformUtils.checkPlatform() == 'iOS')
            Text(localized.moreVoicesIOS),
        ],
      ),
    );
  }
}
