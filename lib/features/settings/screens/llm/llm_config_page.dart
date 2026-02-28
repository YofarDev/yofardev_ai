import 'package:flutter/material.dart';

import '../../../../models/llm/llm_config.dart';
import '../../../../services/llm_service.dart';

class LlmConfigPage extends StatefulWidget {
  final LlmConfig? config;

  const LlmConfigPage({super.key, this.config});

  @override
  State<LlmConfigPage> createState() => _LlmConfigPageState();
}

class _LlmConfigPageState extends State<LlmConfigPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  double _temperature = 0.7;
  ResponseFormatType _responseFormatType = ResponseFormatType.jsonObject;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.config?.label ?? '');
    _baseUrlController = TextEditingController(
      text: widget.config?.baseUrl ?? 'https://api.openai.com/v1',
    );
    _apiKeyController = TextEditingController(
      text: widget.config?.apiKey ?? '',
    );
    _modelController = TextEditingController(
      text: widget.config?.model ?? 'gpt-3.5-turbo',
    );
    _temperature = widget.config?.temperature ?? 0.7;
    _responseFormatType =
        widget.config?.responseFormatType ?? ResponseFormatType.jsonObject;
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
      final LlmConfig newConfig = widget.config == null
          ? LlmConfig.create(
              label: _labelController.text,
              baseUrl: _baseUrlController.text,
              apiKey: _apiKeyController.text,
              model: _modelController.text,
              temperature: _temperature,
              responseFormatType: _responseFormatType,
            )
          : widget.config!.copyWith(
              label: _labelController.text,
              baseUrl: _baseUrlController.text,
              apiKey: _apiKeyController.text,
              model: _modelController.text,
              temperature: _temperature,
              responseFormatType: _responseFormatType,
            );

      await LlmService().saveConfig(newConfig);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.config == null ? 'Add LLM Config' : 'Edit LLM Config',
        ),
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
