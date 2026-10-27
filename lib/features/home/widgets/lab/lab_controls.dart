// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/looks/looks.dart';
import '../../../../core/models/avatar_scene.dart';
import 'lab_config.dart';

/// "stageChips" -> "Stage chips".
String _title(Enum value) {
  final String spaced = value.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (Match m) => ' ${m[0]!.toLowerCase()}',
  );
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

/// The lab's tab switch and collapsible controls panel. Stateless: the screen
/// owns the config and the collapsed flag.
class LabControls extends StatelessWidget {
  const LabControls({
    super.key,
    required this.config,
    required this.onChanged,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onCopy,
  });

  final LabConfig config;
  final ValueChanged<LabConfig> onChanged;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.45;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.tokens.glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Row(
              children: <Widget>[
                for (final LabTab tab in LabTab.values) ...<Widget>[
                  AppPill(
                    label: _title(tab),
                    selected: config.tab == tab,
                    onTap: () => onChanged(config.copyWith(tab: tab)),
                  ),
                  const SizedBox(width: AppSpace.sm),
                ],
                const Spacer(),
                AppIconButton(
                  onPressed: onToggleExpanded,
                  icon: expanded
                      ? Icons.expand_more_rounded
                      : Icons.tune_rounded,
                  semanticLabel: expanded ? 'Hide controls' : 'Show controls',
                ),
              ],
            ),
          ),
          if (expanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  0,
                  AppSpace.lg,
                  AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _PillRow<AvatarScene>(
                      label: 'Scene',
                      values: AvatarScene.values,
                      text: _title,
                      selected: config.scene,
                      onSelected: (AvatarScene v) =>
                          onChanged(config.copyWith(scene: v)),
                    ),
                    _PillRow<LabLayout>(
                      label: 'Layout',
                      values: LabLayout.values,
                      text: _title,
                      selected: config.layout,
                      onSelected: (LabLayout v) =>
                          onChanged(config.copyWith(layout: v)),
                    ),
                    _PillRow<LabComposerState>(
                      label: 'Composer',
                      values: LabComposerState.values,
                      text: _title,
                      selected: config.composer,
                      onSelected: (LabComposerState v) =>
                          onChanged(config.copyWith(composer: v)),
                    ),
                    _SliderRow(
                      label: 'Accent hue',
                      value: config.accentHueOverride,
                      fallback: HSVColor.fromColor(
                        UiLooks.storybook.palette(config.scene).accent,
                      ).hue,
                      min: 0,
                      max: 360,
                      format: (double v) => '${v.round()}°',
                      onChanged: (double? v) =>
                          onChanged(config.copyWith(accentHueOverride: v)),
                    ),
                    _SliderRow(
                      label: 'Glass',
                      value: config.glassAlphaScale == 1
                          ? null
                          : config.glassAlphaScale,
                      fallback: 1,
                      min: 0,
                      max: 3,
                      format: (double v) => '×${v.toStringAsFixed(2)}',
                      onChanged: (double? v) =>
                          onChanged(config.copyWith(glassAlphaScale: v ?? 1)),
                    ),
                    _SliderRow(
                      label: 'Radius',
                      value: config.radiusScaleOverride,
                      fallback: UiLooks.storybook.radiusScale,
                      min: 0,
                      max: 2,
                      format: (double v) => '×${v.toStringAsFixed(2)}',
                      onChanged: (double? v) =>
                          onChanged(config.copyWith(radiusScaleOverride: v)),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    AppPill(
                      label: 'Copy config',
                      icon: Icons.copy_rounded,
                      onTap: onCopy,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Text(
        label,
        style: context.text.labelLarge?.copyWith(
          color: context.colors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _PillRow<T> extends StatelessWidget {
  const _PillRow({
    required this.label,
    required this.values,
    required this.text,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final String Function(T) text;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: _RowLabel(label),
        ),
        Expanded(
          child: Wrap(
            spacing: AppSpace.sm,
            children: <Widget>[
              for (final T value in values)
                AppPill(
                  label: text(value),
                  selected: value == selected,
                  onTap: () => onSelected(value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A slider whose value may be unset ("Auto"): dragging sets it, the Auto pill
/// clears it. [fallback] is where the thumb rests while unset.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.fallback,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final double fallback;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final double shown = (value ?? fallback).clamp(min, max);
    return Row(
      children: <Widget>[
        _RowLabel(label),
        Expanded(
          child: Slider(
            value: shown,
            min: min,
            max: max,
            semanticFormatterCallback: format,
            onChanged: (double v) => onChanged(v),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            format(shown),
            textAlign: TextAlign.end,
            style: context.text.labelMedium,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        AppPill(
          label: 'Auto',
          selected: value == null,
          onTap: () => onChanged(null),
        ),
      ],
    );
  }
}
