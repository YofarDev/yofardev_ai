// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/looks/looks.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../avatar/avatar.dart';
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
                    _FaceSection(config: config, onChanged: onChanged),
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

  /// The highlighted value; null highlights none.
  final T? selected;
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

/// "auBrowInnerUpL" -> "browInnerUp L", "auJawDrop" -> "jawDrop"; other
/// names stay as they are.
String _faceLabel(String key) {
  if (!key.startsWith('au')) {
    return key;
  }
  final String name = '${key[2].toLowerCase()}${key.substring(3)}';
  if (LabFace.sideKeys.contains(key)) {
    return '${name.substring(0, name.length - 1)} ${key[key.length - 1]}';
  }
  return name;
}

/// The Face section: a hand-set face for the stage avatar (contract v6
/// names). Any touch switches the avatar from its live face to
/// [LabConfig.face]; Reset goes back to the live face.
class _FaceSection extends StatelessWidget {
  const _FaceSection({required this.config, required this.onChanged});

  final LabConfig config;
  final ValueChanged<LabConfig> onChanged;

  FaceFrame get _face => config.face ?? LabFace.base;

  void _set(FaceFrame face) => onChanged(config.copyWith(face: face));

  Widget _sliders(List<String> keys) {
    final Map<String, double> values = LabFace.values(_face);
    return Column(
      children: <Widget>[
        for (final String key in keys)
          _FaceSlider(
            name: key,
            value: values[key]!,
            onChanged: (double v) => _set(LabFace.withValue(_face, key, v)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final FaceFrame? face = config.face;
    AvatarMood? mood;
    Viseme? viseme;
    if (face != null) {
      for (final AvatarMood m in AvatarMood.values) {
        if (LabFace.hasMood(face, m)) {
          mood = m;
          break;
        }
      }
      for (final Viseme v in Viseme.values) {
        if (LabFace.hasViseme(face, v)) {
          viseme = v;
          break;
        }
      }
    }
    return _Collapsible(
      title: 'Face',
      summary: face == null ? 'Live' : 'Override',
      children: <Widget>[
        _PillRow<AvatarMood>(
          label: 'Mood',
          values: AvatarMood.values,
          text: _title,
          selected: mood,
          onSelected: (AvatarMood m) => _set(LabFace.withMood(_face, m)),
        ),
        _PillRow<Viseme>(
          label: 'Viseme',
          values: Viseme.values,
          text: (Viseme v) => v.name,
          selected: viseme,
          onSelected: (Viseme v) => _set(LabFace.withViseme(_face, v)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Wrap(
            spacing: AppSpace.sm,
            children: <Widget>[
              AppPill(
                label: 'Blink',
                icon: Icons.visibility_off_rounded,
                onTap: () => _set(LabFace.withBlink(_face)),
              ),
              AppPill(
                label: 'Reset',
                icon: Icons.restart_alt_rounded,
                onTap: face == null
                    ? null
                    : () => onChanged(config.copyWith(face: null)),
              ),
            ],
          ),
        ),
        _Collapsible(
          title: 'Action units',
          children: <Widget>[_sliders(LabFace.actionUnitKeys)],
        ),
        _Collapsible(
          title: "Sides (viewer's L / R)",
          children: <Widget>[_sliders(LabFace.sideKeys)],
        ),
        _Collapsible(
          title: 'Mouth & head',
          children: <Widget>[_sliders(LabFace.extraKeys)],
        ),
      ],
    );
  }
}

/// A titled group that folds away (closed at first).
class _Collapsible extends StatefulWidget {
  const _Collapsible({
    required this.title,
    required this.children,
    this.summary,
  });

  final String title;
  final String? summary;
  final List<Widget> children;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final String? summary = widget.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Text(widget.title, style: context.text.titleSmall),
              ),
            ),
            if (summary != null)
              Text(
                summary,
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            AppIconButton(
              onPressed: _toggle,
              icon: _open
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              semanticLabel: _open
                  ? 'Hide ${widget.title}'
                  : 'Show ${widget.title}',
            ),
          ],
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}

/// One face number: its short name, a slider over its contract range and
/// the value.
class _FaceSlider extends StatelessWidget {
  const _FaceSlider({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  /// The `AvatarVM` name.
  final String name;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final (double min, double max) = LabFace.range(name);
    final TextStyle? style = context.text.labelMedium;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(
            _faceLabel(name),
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            key: ValueKey<String>('lab-face-$name'),
            value: value.clamp(min, max),
            min: min,
            max: max,
            semanticFormatterCallback: (double v) => v.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }
}
