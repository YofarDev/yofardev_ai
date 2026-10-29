// ignore-l10n: debug — the UI lab is debug-only (route registered behind
// kDebugMode), so its strings are intentionally hardcoded.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design.dart';
import '../../../core/design/looks/looks.dart';
import '../../../core/services/world/world_state_service.dart';
import '../../../core/utils/logger.dart';
import '../widgets/lab/lab_config.dart';
import '../widgets/lab/lab_controls.dart';
import '../widgets/lab/lab_service_extension.dart';
import '../widgets/lab/lab_stage_preview.dart';
import '../widgets/lab/lab_surfaces_preview.dart';

/// Debug-only screen to iterate on the Storybook night look across the four
/// scenes. Reach it at `/ui-lab`; the route only exists in debug builds.
///
/// Owns a `ValueNotifier<LabConfig>` that the controls and the
/// `ext.yofardev.uiLab.*` service extensions both edit.
class UiLabScreen extends StatefulWidget {
  const UiLabScreen({
    super.key,
    this.textThemeBuilder = googleFontsTextThemeBuilder,
    this.initialConfig = LabConfig.initial,
    this.stageBuilder = buildLabRiveStage,
    this.world,
  });

  /// Builds the look's text theme; tests inject a fake so no font loads.
  final LookTextThemeBuilder textThemeBuilder;

  final LabConfig initialConfig;

  /// Builds the Stage tab's scene and avatar; tests inject a placeholder as
  /// Rive files are not decoded in widget tests.
  final LabStageBuilder stageBuilder;

  /// The app's world state; the lab's `rain` param sets it and the stage
  /// shows it (null: no rain control).
  final WorldStateService? world;

  @override
  State<UiLabScreen> createState() => _UiLabScreenState();
}

class _UiLabScreenState extends State<UiLabScreen> {
  static const String _tag = 'UiLab';
  static const double _previewMaxWidth = 480;

  late final ValueNotifier<LabConfig> _config = ValueNotifier<LabConfig>(
    widget.initialConfig,
  );

  /// Base themes by scene, so dragging a slider does not rebuild (and
  /// re-resolve the fonts of) the base theme every frame.
  final Map<String, ThemeData> _baseThemes = <String, ThemeData>{};

  @override
  void initState() {
    super.initState();
    registerUiLabExtensions(_config, world: widget.world);
  }

  @override
  void dispose() {
    unregisterUiLabExtensions(_config);
    // The lab's `rain` param is the only thing here that sets the world's
    // rain: leave the app dry when the lab closes.
    widget.world?.setRain(0);
    _config.dispose();
    super.dispose();
  }

  ThemeData _previewTheme(LabConfig config) {
    final ThemeData base = _baseThemes.putIfAbsent(
      config.scene.name,
      () => buildLookTheme(
        UiLooks.storybook,
        config.scene,
        textThemeBuilder: widget.textThemeBuilder,
      ),
    );
    return applyLabOverrides(base, config);
  }

  Future<void> _copyConfig() async {
    final String json = jsonEncode(_config.value.toJson());
    AppLogger.info('UI lab config: $json', tag: _tag);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Config copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<LabConfig>(
          valueListenable: _config,
          builder: (BuildContext context, LabConfig config, Widget? _) {
            return Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _previewMaxWidth,
                      ),
                      child: Theme(
                        data: _previewTheme(config),
                        child: _PreviewFrame(
                          config: config,
                          stageBuilder: widget.stageBuilder,
                          world: widget.world,
                        ),
                      ),
                    ),
                  ),
                ),
                LabControls(
                  config: config,
                  onChanged: (LabConfig next) => _config.value = next,
                  expanded: !config.panelCollapsed,
                  onToggleExpanded: () => _config.value = config.copyWith(
                    panelCollapsed: !config.panelCollapsed,
                  ),
                  onCopy: _copyConfig,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The page background under the ambient look theme,
/// with the tab's content on top.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({
    required this.config,
    required this.stageBuilder,
    this.world,
  });

  final LabConfig config;
  final LabStageBuilder stageBuilder;
  final WorldStateService? world;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[tokens.background, context.colors.surface],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: switch (config.tab) {
          // Phone wide, like the stage canvas, so it reads as a phone screen.
          LabTab.surfaces => Center(
            child: SizedBox(
              width: LabStagePreview.canvas.width,
              child: const LabSurfacesPreview(),
            ),
          ),
          LabTab.stage => LabStagePreview(
            config: config,
            stageBuilder: stageBuilder,
            world: world,
          ),
        },
      ),
    );
  }
}
