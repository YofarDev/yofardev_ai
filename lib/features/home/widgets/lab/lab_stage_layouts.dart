// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_scene.dart';
import 'lab_caption.dart';
import 'lab_composer_mock.dart';
import 'lab_config.dart';

/// The Home chrome of one [LabLayout], drawn over the stage (scene + avatar):
///
/// - stageChips (L1): History and More chips on top, the caption as large
///   display type above a composer with an attach button;
/// - dock (L2): one floating dock (History | composer | More) and a
///   film-subtitle caption above it;
/// - curtain (L3): the composer alone and the caption as a speech bubble near
///   the character's head; a tap on the stage shows or hides the chips.
///
/// Reads the safe-area insets from the ambient `MediaQuery`.
class LabStageLayout extends StatefulWidget {
  const LabStageLayout({
    super.key,
    required this.layout,
    required this.composer,
    required this.scene,
  });

  final LabLayout layout;
  final LabComposerState composer;
  final AvatarScene scene;

  /// Top of the character's head, as a fraction of the stage height (the
  /// avatar artboard is bottom-anchored and fills the stage width).
  static const double headTop = 0.495;

  @override
  State<LabStageLayout> createState() => _LabStageLayoutState();
}

class _LabStageLayoutState extends State<LabStageLayout> {
  bool _curtainChips = false;

  /// The caption is the character's last line: hidden while it listens or
  /// thinks about a new one.
  bool get _showCaption =>
      widget.composer != LabComposerState.listening &&
      widget.composer != LabComposerState.thinking;

  @override
  Widget build(BuildContext context) {
    return switch (widget.layout) {
      LabLayout.stageChips => _buildStageChips(context),
      LabLayout.dock => _buildDock(context),
      LabLayout.curtain => _buildCurtain(context),
    };
  }

  Widget _buildStageChips(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _Scrim.top(),
        const _Scrim.bottom(strength: 1),
        Positioned(
          top: insets.top + AppSpace.sm,
          left: AppSpace.lg,
          right: AppSpace.sm,
          child: const _TopChips(),
        ),
        Positioned(
          left: AppSpace.lg,
          right: AppSpace.lg,
          bottom: insets.bottom + AppSpace.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CaptionSlot(
                visible: _showCaption,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm,
                    0,
                    AppSpace.xxl,
                    AppSpace.lg,
                  ),
                  child: LabCaption(scene: widget.scene),
                ),
              ),
              LabComposerMock(
                state: widget.composer,
                leading: <Widget>[
                  AppIconButton(
                    onPressed: () {},
                    icon: Icons.add_rounded,
                    semanticLabel: 'Add attachment',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDock(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _Scrim.bottom(strength: 0.8),
        Positioned(
          left: AppSpace.md,
          right: AppSpace.md,
          bottom: insets.bottom + AppSpace.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CaptionSlot(
                visible: _showCaption,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl,
                    0,
                    AppSpace.xl,
                    AppSpace.lg,
                  ),
                  child: LabCaption(
                    scene: widget.scene,
                    variant: LabCaptionVariant.subtitle,
                  ),
                ),
              ),
              LabComposerMock(
                state: widget.composer,
                leading: <Widget>[
                  AppIconButton(
                    onPressed: () {},
                    icon: Icons.history_rounded,
                    semanticLabel: 'History',
                  ),
                  const _DockDivider(),
                ],
                trailing: <Widget>[
                  const _DockDivider(),
                  AppIconButton(
                    onPressed: () {},
                    icon: Icons.more_horiz_rounded,
                    semanticLabel: 'More',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurtain(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    final Duration fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.slow;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double headTop = constraints.maxHeight * LabStageLayout.headTop;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Behind the chrome, so taps on it don't toggle; translucent, so
            // the stage underneath still gets the pointer.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _curtainChips = !_curtainChips),
            ),
            const _Scrim.bottom(strength: 0.55),
            AnimatedOpacity(
              opacity: _curtainChips ? 1 : 0,
              duration: fade,
              child: const _Scrim.top(),
            ),
            Positioned(
              top: insets.top + AppSpace.sm,
              left: AppSpace.lg,
              right: AppSpace.sm,
              child: AnimatedSwitcher(
                duration: fade,
                switchInCurve: AppMotion.standard,
                switchOutCurve: AppMotion.standard,
                transitionBuilder:
                    (Widget child, Animation<double> animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                child: _curtainChips
                    ? const _TopChips(key: ValueKey<String>('chips'))
                    : const SizedBox.shrink(key: ValueKey<String>('none')),
              ),
            ),
            Positioned(
              left: AppSpace.xl,
              right: AppSpace.xl,
              bottom: constraints.maxHeight - headTop,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: _CaptionSlot(
                    visible: _showCaption,
                    child: LabCaption(
                      scene: widget.scene,
                      variant: LabCaptionVariant.bubble,
                      tailAt: 0.78,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpace.lg,
              right: AppSpace.lg,
              bottom: insets.bottom + AppSpace.md,
              child: LabComposerMock(state: widget.composer),
            ),
          ],
        );
      },
    );
  }
}

/// History and More, as on top of the stage in L1 (and L3 when shown).
class _TopChips extends StatelessWidget {
  const _TopChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppPill(label: 'History', icon: Icons.history_rounded, onTap: () {}),
        const Spacer(),
        AppIconButton(
          onPressed: () {},
          icon: Icons.more_horiz_rounded,
          semanticLabel: 'More',
        ),
      ],
    );
  }
}

/// Fades and folds the caption away when it has nothing to say.
class _CaptionSlot extends StatelessWidget {
  const _CaptionSlot({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.slow;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
      child: visible
          ? KeyedSubtree(key: const ValueKey<bool>(true), child: child)
          : const SizedBox(key: ValueKey<bool>(false), width: double.infinity),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const _DockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      color: context.colors.onSurface.withValues(alpha: 0.16),
    );
  }
}

/// Ink fading over the stage behind the chrome, so text and controls stay
/// legible on bright scenes.
class _Scrim extends StatelessWidget {
  const _Scrim.top() : top = true, strength = 1;

  const _Scrim.bottom({required this.strength}) : top = false;

  final bool top;

  /// 0..1 multiplier of the scrim's opacity.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    return IgnorePointer(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: top ? 0.16 : 0.42,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.bottomCenter : Alignment.topCenter,
                end: top ? Alignment.topCenter : Alignment.bottomCenter,
                colors: <Color>[
                  ink.withValues(alpha: 0),
                  ink.withValues(alpha: (top ? 0.25 : 0.5) * strength),
                  ink.withValues(alpha: (top ? 0.5 : 0.82) * strength),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
