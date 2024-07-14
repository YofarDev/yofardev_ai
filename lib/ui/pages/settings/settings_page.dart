// ignore_for_file: avoid_dynamic_calls, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../l10n/localization_manager.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../models/sound_effects.dart';
import '../../../models/voice.dart';
import '../../../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseSystemPromptController =
      TextEditingController();
  final List<Voice> _voices = <Voice>[];
  late Voice _selectedVoice;
  bool _isSoundEffectsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTtsVoices();
  }

  void _loadSettings() async {
    _apiKeyController.text = await SettingsService().getApiKey();
    _baseSystemPromptController.text =
        await SettingsService().getBaseSystemPrompt() ?? '';
    _isSoundEffectsEnabled =
        context.read<ChatsCubit>().state.soundEffectsEnabled;
    setState(() {});
  }

  void _loadTtsVoices() async {
    final FlutterTts flutterTts = FlutterTts();
    final List<dynamic> voices = await flutterTts.getVoices as List<dynamic>;
    for (final dynamic voice in voices) {
      if (Platform.isIOS && (voice['gender'] != 'male')) continue;
      if ((voice['locale'] as String)
          .startsWith(context.read<ChatsCubit>().state.currentLanguage)) {
        _voices.add(
          Voice(
            name: voice['name'] as String,
            locale: voice['locale'] as String,
          ),
        );
      }
    }
    _voices.sort((Voice a, Voice b) => a.locale.compareTo(b.locale));
    final String name = await SettingsService()
        .getTtsVoice(context.read<ChatsCubit>().state.currentLanguage);
    _selectedVoice = _voices.firstWhere((Voice voice) => voice.name == name);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(localized.settings),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await SettingsService().setApiKey(_apiKeyController.text);
              if (_baseSystemPromptController.text.isNotEmpty) {
                await SettingsService()
                    .setBaseSystemPrompt(_baseSystemPromptController.text);
              }
              context
                  .read<ChatsCubit>()
                  .setSoundEffects(_isSoundEffectsEnabled);
              await SettingsService()
                  .setTtsVoice(
                _selectedVoice.name,
                context.read<ChatsCubit>().state.currentLanguage,
              )
                  .then((_) {
                Navigator.of(context).pop();
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                localized.settingsSubstring,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildApiKeyField(),
              const SizedBox(height: 16),
              _buildBaseSystemPromptField(),
              const SizedBox(height: 16),
              _buildSoundEffectsCheckbox(),
              const SizedBox(height: 16),
              _dropdownVoices(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyField() => _textField(
        _apiKeyController,
        hintText: "Google API Key",
        prefixIcon: Icons.vpn_key,
      );

  Widget _buildBaseSystemPromptField() => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _textField(
            _baseSystemPromptController,
            hintText: localized.baseSystemPrompt,
            minLines: 8,
            maxLines: 20,
          ),
          MaterialButton(
            onPressed: () {
              _baseSystemPromptController.text = localized.baseSystemPrompt;
            },
            child: Text(localized.loadDefaultSystemPrompt),
          ),
        ],
      );

  Widget _textField(
    TextEditingController controller, {
    String? hintText,
    int? maxLines,
    int? minLines,
    IconData? prefixIcon,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        minLines: minLines,
        maxLines: maxLines,
      );

  Widget _buildSoundEffectsCheckbox() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            localized.enableSoundEffects,
            style: const TextStyle(fontSize: 20),
          ),
          Switch(
            value: _isSoundEffectsEnabled,
            onChanged: (bool value) {
              setState(() {
                _isSoundEffectsEnabled = value;
              });
            },
          ),
        ],
      );

  Widget _dropdownVoices() => Container(
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
            if (_selectedVoice.locale.isEmpty)
              Container()
            else
              Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<Voice>(
                  value: _selectedVoice,
                  items: _voices.map<DropdownMenuItem<Voice>>((Voice value) {
                    return DropdownMenuItem<Voice>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: (Voice? value) async {
                    if (value != null) {
                      setState(() {
                        _selectedVoice = value;
                      });
                    }
                  },
                ),
              ),
            if (Platform.isAndroid) Text(localized.moreVoicesAndroid),
            if (Platform.isIOS) Text(localized.moreVoicesIOS),
          ],
        ),
      );
}
