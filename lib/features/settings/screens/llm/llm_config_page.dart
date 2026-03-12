import 'package:flutter/material.dart';

import '../../../../core/models/llm_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/llm/llm_service_interface.dart';

class LlmConfigPage extends StatefulWidget {
  /// Config ID to edit, or 'new' to create a new config
  final String? configId;

  const LlmConfigPage({super.key, this.configId});

  @override
  State<LlmConfigPage> createState() => _LlmConfigPageState();
}

class _LlmConfigPageState extends State<LlmConfigPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final LlmServiceInterface _llmService = getIt<LlmServiceInterface>();
  late TextEditingController _labelController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  double _temperature = 0.7;
  ResponseFormatType _responseFormatType = ResponseFormatType.jsonObject;
  LlmConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _llmService.init();

    // Check if we're creating a new config or editing an existing one
    if (widget.configId == null || widget.configId == 'new') {
      // Creating new config - use defaults
      setState(() {
        _isLoading = false;
      });
    } else {
      // Editing existing config - look it up by ID
      final List<LlmConfig> allConfigs = _llmService.getAllConfigs();
      final LlmConfig? foundConfig = allConfigs.cast<LlmConfig?>().firstWhere(
        (LlmConfig? c) => c?.id == widget.configId,
        orElse: () => null,
      );

      setState(() {
        _config = foundConfig;
        _isLoading = false;
      });
    }

    // Initialize controllers after config is loaded
    _labelController = TextEditingController(text: _config?.label ?? '');
    _baseUrlController = TextEditingController(
      text: _config?.baseUrl ?? 'https://api.openai.com/v1',
    );
    _apiKeyController = TextEditingController(text: _config?.apiKey ?? '');
    _modelController = TextEditingController(
      text: _config?.model ?? 'gpt-3.5-turbo',
    );
    _temperature = _config?.temperature ?? 0.7;
    _responseFormatType =
        _config?.responseFormatType ?? ResponseFormatType.jsonObject;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final LlmConfig newConfig = _config == null
          ? LlmConfig.create(
              label: _labelController.text,
              baseUrl: _baseUrlController.text,
              apiKey: _apiKeyController.text,
              model: _modelController.text,
              temperature: _temperature,
              responseFormatType: _responseFormatType,
            )
          : _config!.copyWith(
              label: _labelController.text,
              baseUrl: _baseUrlController.text,
              apiKey: _apiKeyController.text,
              model: _modelController.text,
              temperature: _temperature,
              responseFormatType: _responseFormatType,
            );

      await _llmService.saveConfig(newConfig);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_config == null ? 'Add LLM Config' : 'Edit LLM Config'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g. My OpenAI)',
                ),
                validator: (String? v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                ),
                validator: (String? v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
                validator: (String? v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model Name (e.g. gpt-4o)',
                ),
                validator: (String? v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  const Text('Temperature: '),
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      divisions: 10,
                      label: _temperature.toString(),
                      onChanged: (double v) => setState(() => _temperature = v),
                    ),
                  ),
                  Text(_temperature.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ResponseFormatType>(
                initialValue: _responseFormatType,
                decoration: const InputDecoration(
                  labelText: 'JSON Response Format',
                  helperText: 'Format for JSON mode responses',
                ),
                items: const <DropdownMenuItem<ResponseFormatType>>[
                  DropdownMenuItem<ResponseFormatType>(
                    value: ResponseFormatType.jsonObject,
                    child: Text('json_object (OpenAI)'),
                  ),
                  DropdownMenuItem<ResponseFormatType>(
                    value: ResponseFormatType.jsonSchema,
                    child: Text('json_schema (Some local APIs)'),
                  ),
                  DropdownMenuItem<ResponseFormatType>(
                    value: ResponseFormatType.text,
                    child: Text('text (Generic)'),
                  ),
                  DropdownMenuItem<ResponseFormatType>(
                    value: ResponseFormatType.none,
                    child: Text('none (No format, use prompt only)'),
                  ),
                ],
                onChanged: (ResponseFormatType? value) {
                  if (value != null) {
                    setState(() => _responseFormatType = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
