// ignore-l10n: debug — /rive-lab is a debug-only screen (route registered
// behind kDebugMode), so its strings are intentionally hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/models/talking_phase.dart';

/// The Rive Lab's UI-kit settings, shared by the controls tab and the
/// preview drawn over the stage.
class RiveLabUiKitSettings extends ChangeNotifier {
  ComposerOrbState orbState = ComposerOrbState.idle;
  double orbLevel = 0;
  TalkingPhase glowPhase = TalkingPhase.idle;
  ToolIconKind toolKind = ToolIconKind.search;
  bool toolRunning = true;
  bool toggleValue = false;
  bool reduceMotion = false;

  /// Plays the mark sting of the preview.
  final GlobalKey<MarkStingState> markKey = GlobalKey<MarkStingState>();

  void update(void Function(RiveLabUiKitSettings settings) change) {
    change(this);
    notifyListeners();
  }
}

/// The "UI kit" tab: one control per UI-kit widget property.
class RiveLabUiKitControls extends StatelessWidget {
  const RiveLabUiKitControls({super.key, required this.settings});

  final RiveLabUiKitSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        return ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: <Widget>[
            SwitchListTile(
              title: const Text('Reduce motion'),
              value: settings.reduceMotion,
              onChanged: (bool value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.reduceMotion = value;
                  }),
            ),
            const Divider(),
            _EnumDropdown<ComposerOrbState>(
              label: 'ComposerOrb state',
              value: settings.orbState,
              values: ComposerOrbState.values,
              onChanged: (ComposerOrbState value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.orbState = value;
                  }),
            ),
            Text('ComposerOrb level ${settings.orbLevel.toStringAsFixed(2)}'),
            Slider(
              value: settings.orbLevel,
              onChanged: (double value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.orbLevel = value;
                  }),
            ),
            _EnumDropdown<TalkingPhase>(
              label: 'StatusGlow phase',
              value: settings.glowPhase,
              values: TalkingPhase.values,
              onChanged: (TalkingPhase value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.glowPhase = value;
                  }),
            ),
            _EnumDropdown<ToolIconKind>(
              label: 'ToolIcon kind',
              value: settings.toolKind,
              values: ToolIconKind.values,
              onChanged: (ToolIconKind value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.toolKind = value;
                  }),
            ),
            SwitchListTile(
              title: const Text('ToolIcon running'),
              value: settings.toolRunning,
              onChanged: (bool value) =>
                  settings.update((RiveLabUiKitSettings s) {
                    s.toolRunning = value;
                  }),
            ),
            ListTile(
              title: const Text('Toggle (tap it on the stage)'),
              trailing: Text(settings.toggleValue ? 'on' : 'off'),
            ),
            ElevatedButton(
              onPressed: () => settings.markKey.currentState?.play(),
              child: const Text('Play mark sting'),
            ),
          ],
        );
      },
    );
  }
}

/// The UI-kit widgets laid over the lab stage (the current scene), as they
/// sit on Home: the glow behind a composer-like row, the mark above.
class RiveLabUiKitPreview extends StatelessWidget {
  const RiveLabUiKitPreview({super.key, required this.settings});

  final RiveLabUiKitSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: settings.reduceMotion),
          child: Stack(
            children: <Widget>[
              Align(
                alignment: const Alignment(0, -0.6),
                child: MarkSting(key: settings.markKey, size: 128),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 200,
                child: StatusGlow(phase: settings.glowPhase),
              ),
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: AppSpace.xl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpace.lg,
                  children: <Widget>[
                    ToolIcon(
                      kind: settings.toolKind,
                      running: settings.toolRunning,
                    ),
                    RiveToggle(
                      value: settings.toggleValue,
                      semanticLabel: 'Lab toggle',
                      onChanged: (bool value) =>
                          settings.update((RiveLabUiKitSettings s) {
                            s.toggleValue = value;
                          }),
                    ),
                    ComposerOrb(
                      state: settings.orbState,
                      level: settings.orbLevel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      initialValue: value,
      items: values
          .map(
            (T item) =>
                DropdownMenuItem<T>(value: item, child: Text(item.name)),
          )
          .toList(),
      onChanged: (T? item) {
        if (item != null) {
          onChanged(item);
        }
      },
    );
  }
}
