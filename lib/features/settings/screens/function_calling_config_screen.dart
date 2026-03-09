import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/res/app_colors.dart';
import '../presentation/bloc/settings_cubit.dart';
import '../presentation/bloc/settings_state.dart';
import '../widgets/function_calling_section.dart';
import '../widgets/settings_app_bar.dart';

/// Screen for configuring function calling API keys and settings
class FunctionCallingConfigScreen extends StatefulWidget {
  const FunctionCallingConfigScreen({super.key});

  @override
  State<FunctionCallingConfigScreen> createState() =>
      _FunctionCallingConfigScreenState();
}

class _FunctionCallingConfigScreenState
    extends State<FunctionCallingConfigScreen> {
  // Google Search controllers
  final TextEditingController _googleSearchKeyController =
      TextEditingController();
  final TextEditingController _googleSearchEngineIdController =
      TextEditingController();

  // Weather controller
  final TextEditingController _openWeatherKeyController =
      TextEditingController();

  // News controller
  final TextEditingController _newYorkTimesKeyController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final SettingsCubit settingsCubit = context.read<SettingsCubit>();
    final SettingsState state = settingsCubit.state;

    // Load existing values into controllers
    _googleSearchKeyController.text = state.googleSearchKey ?? '';
    _googleSearchEngineIdController.text = state.googleSearchEngineId ?? '';
    _openWeatherKeyController.text = state.openWeatherKey ?? '';
    _newYorkTimesKeyController.text = state.newYorkTimesKey ?? '';
  }

  Future<void> _onSave() async {
    final SettingsCubit settingsCubit = context.read<SettingsCubit>();

    // Save Google Search
    if (_googleSearchKeyController.text.isNotEmpty) {
      await settingsCubit.updateGoogleSearchKey(
        _googleSearchKeyController.text,
      );
    }
    if (_googleSearchEngineIdController.text.isNotEmpty) {
      await settingsCubit.updateGoogleSearchEngineId(
        _googleSearchEngineIdController.text,
      );
    }

    // Save Weather
    if (_openWeatherKeyController.text.isNotEmpty) {
      await settingsCubit.updateOpenWeatherKey(_openWeatherKeyController.text);
    }

    // Save News
    if (_newYorkTimesKeyController.text.isNotEmpty) {
      await settingsCubit.updateNewYorkTimesKey(
        _newYorkTimesKeyController.text,
      );
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).settings_functionCalling_saved,
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _googleSearchKeyController.dispose();
    _googleSearchEngineIdController.dispose();
    _openWeatherKeyController.dispose();
    _newYorkTimesKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.background, AppColors.surface],
          ),
        ),
        child: Column(
          children: <Widget>[
            SafeArea(bottom: false, child: SettingsAppBar(onSave: _onSave)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).settings_functionCalling_description,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    BlocBuilder<SettingsCubit, SettingsState>(
                      builder: (BuildContext context, SettingsState state) {
                        return Column(
                          children: <Widget>[
                            // Google Search Section
                            FunctionCallingSection(
                              title: AppLocalizations.of(
                                context,
                              ).settings_googleSearch,
                              apiName: 'Google Search API',
                              icon: '🔍',
                              isEnabled: state.googleSearchEnabled,
                              onToggle: (bool value) {
                                context
                                    .read<SettingsCubit>()
                                    .toggleGoogleSearch(value);
                              },
                              fields: <Widget>[
                                _buildTextField(
                                  controller: _googleSearchKeyController,
                                  labelText: AppLocalizations.of(
                                    context,
                                  ).settings_apiKey,
                                  hintText: 'Enter your Google Search API key',
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _googleSearchEngineIdController,
                                  labelText: AppLocalizations.of(
                                    context,
                                  ).settings_engineId,
                                  hintText: 'Enter your Search Engine ID',
                                ),
                              ],
                            ),
                            // Weather Section
                            FunctionCallingSection(
                              title: AppLocalizations.of(
                                context,
                              ).settings_weather,
                              apiName: 'OpenWeather API',
                              icon: '🌤️',
                              isEnabled: state.openWeatherEnabled,
                              onToggle: (bool value) {
                                context.read<SettingsCubit>().toggleOpenWeather(
                                  value,
                                );
                              },
                              fields: <Widget>[
                                _buildTextField(
                                  controller: _openWeatherKeyController,
                                  labelText: AppLocalizations.of(
                                    context,
                                  ).settings_apiKey,
                                  hintText: 'Enter your OpenWeather API key',
                                ),
                              ],
                            ),
                            // News Section
                            FunctionCallingSection(
                              title: AppLocalizations.of(context).settings_news,
                              apiName: 'New York Times API',
                              icon: '📰',
                              isEnabled: state.newYorkTimesEnabled,
                              onToggle: (bool value) {
                                context
                                    .read<SettingsCubit>()
                                    .toggleNewYorkTimes(value);
                              },
                              fields: <Widget>[
                                _buildTextField(
                                  controller: _newYorkTimesKeyController,
                                  labelText: AppLocalizations.of(
                                    context,
                                  ).settings_apiKey,
                                  hintText: 'Enter your New York Times API key',
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.5),
      ),
      obscureText: true,
    );
  }
}
