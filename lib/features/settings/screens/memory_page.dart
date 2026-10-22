import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/models/global_memory.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';
import '../presentation/bloc/settings_cubit.dart';
import '../presentation/bloc/settings_state.dart';

/// Tile widget for navigating to the global memory page
class MemoryConfigTile extends StatelessWidget {
  const MemoryConfigTile({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => context.push(RouteConstants.memory),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: 0.12),
              AppColors.glassSurface.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.memory,
              color: AppColors.onSurface.withValues(alpha: 0.7),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.memory,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.memoryDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurface.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Page listing the global memory items with enable toggle and clear-all
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  @override
  void initState() {
    super.initState();
    // Memory is updated in the background by the chat feature; refresh the
    // items every time the page is shown so the list is never stale.
    context.read<SettingsCubit>().loadGlobalMemory();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.background, AppColors.surface],
          ),
        ),
        child: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.surface.withValues(alpha: 0.9),
                      AppColors.surface.withValues(alpha: 0.7),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.glassBorder.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: AppLocalizations.of(context).commonBack,
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.memory,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (BuildContext context, SettingsState state) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 16),
                        Text(
                          l10n.memoryPageSubtitle,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _MemoryToggle(value: state.memoryEnabled),
                        const SizedBox(height: 16),
                        if (state.memoryItems.isEmpty)
                          _EmptyMemoryCard(l10n: l10n)
                        else ...<Widget>[
                          for (final GlobalMemoryItem item in state.memoryItems)
                            _MemoryItemCard(item: item),
                          const SizedBox(height: 16),
                          _ClearMemoryButton(items: state.memoryItems),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryToggle extends StatelessWidget {
  const _MemoryToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).enableMemory,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: (bool enabled) =>
                context.read<SettingsCubit>().setMemoryEnabled(enabled),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            inactiveThumbColor: AppColors.onSurface.withValues(alpha: 0.5),
            inactiveTrackColor: AppColors.onSurface.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _EmptyMemoryCard extends StatelessWidget {
  const _EmptyMemoryCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.hourglass_empty_rounded,
            color: AppColors.onSurface.withValues(alpha: 0.4),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.memoryEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryItemCard extends StatelessWidget {
  const _MemoryItemCard({required this.item});

  final GlobalMemoryItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) {
        context.read<SettingsCubit>().deleteMemoryItem(item.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.memoryDeleted)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: 0.12),
              AppColors.glassSurface.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              color: AppColors.warning.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearMemoryButton extends StatelessWidget {
  const _ClearMemoryButton({required this.items});

  final List<GlobalMemoryItem> items;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmClear(context, l10n),
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: AppColors.error.withValues(alpha: 0.8),
        ),
        label: Text(l10n.clearMemory),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(
            color: AppColors.error.withValues(alpha: 0.5),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppLocalizations l10n) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.clearMemory),
          content: Text(l10n.clearMemoryConfirmation),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SettingsCubit>().clearMemory();
              },
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
  }
}
