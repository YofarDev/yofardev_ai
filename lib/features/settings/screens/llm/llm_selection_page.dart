import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/llm_config.dart';
import '../../../../core/design/design.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../presentation/bloc/settings_cubit.dart';
import '../../presentation/bloc/settings_state.dart';

class LlmSelectionPage extends StatefulWidget {
  const LlmSelectionPage({super.key});

  @override
  State<LlmSelectionPage> createState() => _LlmSelectionPageState();
}

class _LlmSelectionPageState extends State<LlmSelectionPage> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().refreshLlmConfigs();
  }

  Future<void> _onAdd() async {
    await context.push('/settings/llm/config/new');
  }

  Future<void> _onEdit(LlmConfig config) async {
    await context.push('/settings/llm/config/${config.id}');
  }

  Future<void> _onDelete(LlmConfig config) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteConfig),
        content: Text(
          AppLocalizations.of(context).deleteConfigConfirmation(config.label),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<SettingsCubit>().deleteLlmConfig(config.id);
    }
  }

  Future<void> _onSelect(String? id) async {
    if (id != null) {
      await context.read<SettingsCubit>().setCurrentLlmConfig(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsState state = context.watch<SettingsCubit>().state;
    final List<LlmConfig> configs = state.availableLlmConfigs;
    final String? selectedId = state.selectedLlmConfigId;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).llmProviderSelection),
      ),
      body: configs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context).noLlmConfigurations,
                    style: TextStyle(
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _onAdd,
                    child: Text(AppLocalizations.of(context).addProvider),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: configs.length,
              itemBuilder: (BuildContext context, int index) {
                final LlmConfig config = configs[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    // ignore: deprecated_member_use
                    leading: Radio<String>(
                      value: config.id,
                      // ignore: deprecated_member_use
                      groupValue: selectedId,
                      // ignore: deprecated_member_use
                      onChanged: _onSelect,
                    ),
                    title: Text(
                      config.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${config.model} @ ${config.baseUrl}',
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: context.colors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          onPressed: () => _onEdit(config),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: context.colors.error.withValues(alpha: 0.8),
                          onPressed: () => _onDelete(config),
                        ),
                      ],
                    ),
                    onTap: () => _onSelect(config.id),
                  ),
                );
              },
            ),
      floatingActionButton: configs.isNotEmpty
          ? FloatingActionButton(
              onPressed: _onAdd,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
