import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/llm_config.dart';
import '../../../../core/res/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/services/llm/llm_service.dart';

class LlmSelectionPage extends StatefulWidget {
  const LlmSelectionPage({super.key});

  @override
  State<LlmSelectionPage> createState() => _LlmSelectionPageState();
}

class _LlmSelectionPageState extends State<LlmSelectionPage> {
  final LlmService _llmService = LlmService();
  List<LlmConfig> _configs = <LlmConfig>[];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // Ensure service is ready (though ideally it's init at app start)
    await _llmService.init();

    setState(() {
      _configs = _llmService.getAllConfigs();
      _selectedId = _llmService.getCurrentConfig()?.id;
    });
  }

  void _onAdd() {
    context.push(RouteConstants.llmConfig);
    // Note: refresh will be called when returning via router
  }

  void _onEdit(LlmConfig config) {
    context.push(RouteConstants.llmConfig);
    // Note: refresh will be called when returning via router
  }

  void _onDelete(LlmConfig config) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Config'),
        content: Text('Are you sure you want to delete "${config.label}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _llmService.deleteConfig(config.id);
      _refresh();
    }
  }

  void _onSelect(String? id) async {
    if (id != null) {
      await _llmService.setCurrentConfig(id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLM Provider Selection')),
      body: _configs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'No LLM configurations found.',
                    style: TextStyle(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _onAdd,
                    child: const Text('Add Provider'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _configs.length,
              itemBuilder: (BuildContext context, int index) {
                final LlmConfig config = _configs[index];

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
                      groupValue: _selectedId,
                      // ignore: deprecated_member_use
                      onChanged: _onSelect,
                    ),
                    title: Text(
                      config.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${config.model} @ ${config.baseUrl}',
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: AppColors.onSurface.withValues(alpha: 0.7),
                          onPressed: () => _onEdit(config),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: AppColors.error.withValues(alpha: 0.8),
                          onPressed: () => _onDelete(config),
                        ),
                      ],
                    ),
                    onTap: () => _onSelect(config.id),
                  ),
                );
              },
            ),
      floatingActionButton: _configs.isNotEmpty
          ? FloatingActionButton(
              onPressed: _onAdd,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
