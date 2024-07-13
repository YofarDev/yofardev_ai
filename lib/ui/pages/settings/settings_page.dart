import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/localization_manager.dart';
import '../../../logic/chat/chats_cubit.dart';
import '../../../models/sound_effects.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    _apiKeyController.text = await SettingsService().getApiKey();
    _baseSystemPromptController.text =
        await SettingsService().getBaseSystemPrompt() ?? '';
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
              await SettingsService()
                  .setBaseSystemPrompt(_baseSystemPromptController.text)
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
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        minLines: minLines,
        maxLines: maxLines,
      );

  Widget _buildSoundEffectsCheckbox() => BlocBuilder<ChatsCubit, ChatsState>(
        builder: (BuildContext context, ChatsState state) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                localized.enableSoundEffects,
                style: const TextStyle(fontSize: 20),
              ),
              Switch(
                value: state.soundEffectsEnabled,
                onChanged: (bool value) {
                  context.read<ChatsCubit>().setSoundEffects(value);
                },
              ),
            ],
          );
        },
      );
}
