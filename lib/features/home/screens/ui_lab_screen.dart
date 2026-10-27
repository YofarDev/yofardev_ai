// ignore-l10n: debug — the UI lab is debug-only (route registered behind
// kDebugMode), so its strings are intentionally hardcoded.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design.dart';
import '../../../core/design/looks/looks.dart';
import '../../../core/utils/logger.dart';
import '../widgets/lab/lab_config.dart';
import '../widgets/lab/lab_controls.dart';
import '../widgets/lab/lab_service_extension.dart';
import '../widgets/lab/lab_surfaces_preview.dart';

/// Debug-only screen to compare the candidate looks across the four scenes.
/// Reach it at `/ui-lab`; the route only exists in debug builds.
///
/// Owns a `ValueNotifier<LabConfig>` that the controls and the
/// `ext.yofardev.uiLab.*` service extensions both edit. While mounted it allows
/// runtime Google Fonts downloads (the candidate fonts are not bundled).
class UiLabScreen extends StatefulWidget {
  const UiLabScreen({
    super.key,
    this.textThemeBuilder = googleFontsTextThemeBuilder,
    this.initialConfig = LabConfig.initial,
  });

  /// Builds each look's text theme; tests inject a fake so no font loads.
  final LookTextThemeBuilder textThemeBuilder;

  final LabConfig initialConfig;

  @override
  State<UiLabScreen> createState() => _UiLabScreenState();
}

class _UiLabScreenState extends State<UiLabScreen> {
  static const String _tag = 'UiLab';
  static const double _previewMaxWidth = 480;

  late final ValueNotifier<LabConfig> _config = ValueNotifier<LabConfig>(
    widget.initialConfig,
  );

  /// Look themes by `look/scene`, so dragging a slider does not rebuild (and
  /// re-resolve the fonts of) the base theme every frame.
  final Map<String, ThemeData> _baseThemes = <String, ThemeData>{};
  bool _controlsExpanded = true;

  @override
  void initState() {
    super.initState();
    LabFontFetching.enable();
    registerUiLabExtensions(_config);
  }

  @override
  void dispose() {
    unregisterUiLabExtensions(_config);
    _config.dispose();
    LabFontFetching.restore();
    super.dispose();
  }

  ThemeData _previewTheme(LabConfig config) {
    final ThemeData base = _baseThemes.putIfAbsent(
      '${config.lookId}/${config.scene.name}',
      () => buildLookTheme(
        config.look,
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
                        child: _PreviewFrame(config: config),
                      ),
                    ),
                  ),
                ),
                LabControls(
                  config: config,
                  onChanged: (LabConfig next) => _config.value = next,
                  expanded: _controlsExpanded,
                  onToggleExpanded: () =>
                      setState(() => _controlsExpanded = !_controlsExpanded),
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

/// The page background of the previewed look under the ambient look theme,
/// with the tab's content on top.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.config});

  final LabConfig config;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool cel = tokens.surfaceStyle == AppSurfaceStyle.cel;
    return DecoratedBox(
      decoration: cel
          ? BoxDecoration(color: tokens.background)
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[tokens.background, context.colors.surface],
              ),
            ),
      child: Material(
        type: MaterialType.transparency,
        child: switch (config.tab) {
          LabTab.surfaces => const LabSurfacesPreview(),
          LabTab.stage => _StagePlaceholder(config: config),
        },
      ),
    );
  }
}

class _StagePlaceholder extends StatelessWidget {
  const _StagePlaceholder({required this.config});

  final LabConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Stage preview coming next', style: context.text.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(
            '${config.layout.name} · ${config.composer.name} · '
            '${config.scene.name}',
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
