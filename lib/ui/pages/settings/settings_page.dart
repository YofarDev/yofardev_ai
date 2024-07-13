import 'package:flutter/material.dart';

import '../../../l10n/localization_manager.dart';
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
    _apiKeyController.text =await SettingsService().getApiKey();
    _baseSystemPromptController.text = await SettingsService().getBaseSystemPrompt();
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
              await SettingsService().setBaseSystemPrompt(_baseSystemPromptController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _buildApiKeyField(),
            _buildBaseSystemPromptField(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField() => TextFormField(
        controller: _apiKeyController,
        decoration: const InputDecoration(
          hintText: "Google API Key",
        ),
      );

  Widget _buildBaseSystemPromptField() => TextFormField(
        controller: _baseSystemPromptController,
        decoration: const InputDecoration(
          hintText: "Base system prompt",
        ),
        minLines: 8,
        maxLines: 20,
      );
}
