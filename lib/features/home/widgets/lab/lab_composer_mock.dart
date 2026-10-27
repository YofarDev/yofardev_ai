// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import 'lab_config.dart';

/// A non-functional Home composer in one of the [LabComposerState]s, for the
/// UI lab's Stage tab. Plain Flutter animations only (the Rive orb comes in a
/// later milestone); nothing repeats while `MediaQuery.disableAnimations` is
/// set.
///
/// - idle: pill with the "Ask anything" placeholder and a mic;
/// - typing: the draft and a send button;
/// - listening: the pill collapses into a pulsing mic circle, the words heard
///   so far above it;
/// - thinking: the pill breathes a glow in the scene's glow color;
/// - speaking: a stop button takes the send button's slot.
///
/// [leading] and [trailing] sit inside the pill, around the field and the
/// action (the dock layout puts History and More there). They hide while
/// listening.
class LabComposerMock extends StatefulWidget {
  const LabComposerMock({
    super.key,
    required this.state,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final LabComposerState state;
  final List<Widget> leading;
  final List<Widget> trailing;

  static const double height = 56;
  static const Key liveWordsKey = ValueKey<String>('lab-live-words');

  @override
  State<LabComposerMock> createState() => _LabComposerMockState();
}

class _LabComposerMockState extends State<LabComposerMock>
    with SingleTickerProviderStateMixin {
  static const Duration _pulsePeriod = Duration(milliseconds: 1800);
  static const Duration _breathPeriod = Duration(milliseconds: 1500);

  late final AnimationController _loop = AnimationController(vsync: this);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncLoop();
  }

  @override
  void didUpdateWidget(LabComposerMock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncLoop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Runs the one loop the current state needs, or none.
  void _syncLoop() {
    final Duration? period = _reduceMotion
        ? null
        : switch (widget.state) {
            LabComposerState.listening => _pulsePeriod,
            LabComposerState.thinking => _breathPeriod,
            _ => null,
          };
    if (period == null) {
      _loop
        ..stop()
        ..value = 0;
      return;
    }
    if (_loop.isAnimating && _loop.duration == period) {
      return;
    }
    _loop
      ..duration = period
      ..value = 0
      ..repeat(reverse: widget.state == LabComposerState.thinking);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final LabComposerState state = widget.state;
    final bool listening = state == LabComposerState.listening;
    final BorderRadius pill = BorderRadius.circular(
      tokens.radius(AppRadius.pill),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double fullWidth = constraints.maxWidth;
        final Widget content = listening
            ? const _ListeningMic(key: ValueKey<String>('listening'))
            : _ComposerRow(
                key: const ValueKey<String>('row'),
                state: state,
                leading: widget.leading,
                trailing: widget.trailing,
              );

        final Widget surface = GlassPanel(
          level: AppGlassLevel.thick,
          blur: true,
          borderRadius: pill,
          child: ClipRRect(
            borderRadius: pill,
            child: OverflowBox(
              minWidth: fullWidth,
              maxWidth: fullWidth,
              child: AnimatedSwitcher(
                duration: AppMotion.base,
                switchInCurve: AppMotion.standard,
                switchOutCurve: AppMotion.standard,
                child: content,
              ),
            ),
          ),
        );

        // The wrappers stay in the tree in every state, so switching states
        // animates the pill instead of rebuilding it.
        final Widget pillBox = CustomPaint(
          painter: _PulsePainter(
            animation: _loop,
            color: tokens.scene.accent,
            active: listening,
            still: _reduceMotion,
          ),
          child: AnimatedContainer(
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            width: listening ? LabComposerMock.height : fullWidth,
            height: LabComposerMock.height,
            child: _Breath(
              animation: _loop,
              active: state == LabComposerState.thinking,
              still: _reduceMotion,
              child: surface,
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedSwitcher(
              duration: AppMotion.slow,
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
              child: listening
                  ? const _LiveWords(key: LabComposerMock.liveWordsKey)
                  : const SizedBox(
                      key: ValueKey<String>('no-words'),
                      width: double.infinity,
                    ),
            ),
            Center(child: pillBox),
          ],
        );
      },
    );
  }
}

/// The field and the action slot, with the caller's extra buttons around.
class _ComposerRow extends StatelessWidget {
  const _ComposerRow({
    super.key,
    required this.state,
    required this.leading,
    required this.trailing,
  });

  final LabComposerState state;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LabComposerMock.height,
      child: Row(
        children: <Widget>[
          SizedBox(width: leading.isEmpty ? AppSpace.xl : AppSpace.xs),
          ...leading,
          Expanded(child: _Field(state: state)),
          _ActionSlot(state: state),
          ...trailing,
          const SizedBox(width: AppSpace.xs),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.state});

  final LabComposerState state;

  static const String _draft = 'Is the cat judging me?';

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.text.bodyLarge;
    final Color onSurface = context.colors.onSurface;
    if (state == LabComposerState.typing) {
      return Row(
        children: <Widget>[
          Flexible(
            child: Text(
              _draft,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(color: onSurface),
            ),
          ),
          // A still caret: the composer is a picture, not a field.
          Container(
            width: 2,
            height: 20,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: context.tokens.scene.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      );
    }
    final double alpha = state == LabComposerState.thinking ? 0.4 : 0.6;
    return Text(
      'Ask anything',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(color: onSurface.withValues(alpha: alpha)),
    );
  }
}

/// The one trailing action, swapped in place: mic, send or stop.
class _ActionSlot extends StatelessWidget {
  const _ActionSlot({required this.state});

  final LabComposerState state;

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (state) {
      LabComposerState.typing => AppIconButton(
        key: const ValueKey<String>('send'),
        onPressed: () {},
        icon: Icons.arrow_upward_rounded,
        semanticLabel: 'Send',
        active: true,
      ),
      LabComposerState.speaking => AppIconButton(
        key: const ValueKey<String>('stop'),
        onPressed: () {},
        icon: Icons.stop_rounded,
        semanticLabel: 'Stop',
        active: true,
      ),
      LabComposerState.thinking => const AppIconButton(
        key: ValueKey<String>('mic-off'),
        onPressed: null,
        icon: Icons.mic_none_rounded,
        semanticLabel: 'Voice input',
      ),
      _ => AppIconButton(
        key: const ValueKey<String>('mic'),
        onPressed: () {},
        icon: Icons.mic_none_rounded,
        semanticLabel: 'Voice input',
      ),
    };
    return SizedBox.square(
      dimension: AppIconButton.hitSize,
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.standard,
        transitionBuilder: (Widget child, Animation<double> animation) =>
            FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: child,
              ),
            ),
        child: button,
      ),
    );
  }
}

/// The collapsed composer while listening: the mic in the scene accent.
class _ListeningMic extends StatelessWidget {
  const _ListeningMic({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Center(
      child: Semantics(
        label: 'Listening',
        button: true,
        excludeSemantics: true,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tokens.scene.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic_rounded,
            size: 22,
            color: tokens.scene.onAccent,
          ),
        ),
      ),
    );
  }
}

/// What the recogniser has heard so far; the tail is still provisional.
class _LiveWords extends StatelessWidget {
  const _LiveWords({super.key});

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    final Color onSurface = context.colors.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xl,
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            const TextSpan(text: 'So what is the cat '),
            TextSpan(
              text: 'actually looking at',
              style: TextStyle(color: onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.35,
          color: onSurface,
          shadows: <Shadow>[
            Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Wraps the thinking composer in a glow that swells and settles.
class _Breath extends StatelessWidget {
  const _Breath({
    required this.animation,
    required this.active,
    required this.still,
    required this.child,
  });

  final Animation<double> animation;
  final bool active;
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color glow = tokens.scene.glow;
    final BorderRadius radius = BorderRadius.circular(
      tokens.radius(AppRadius.pill),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        if (!active) {
          return DecoratedBox(
            decoration: BoxDecoration(borderRadius: radius),
            child: child,
          );
        }
        final double t = still
            ? 0.5
            : Curves.easeInOut.transform(animation.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              // A wide halo that swells, and a tight rim that keeps the
              // glow readable around opaque pills.
              BoxShadow(
                color: glow.withValues(
                  alpha: (glow.a * (0.6 + 0.9 * t)).clamp(0.0, 1.0),
                ),
                blurRadius: 14 + 26 * t,
                spreadRadius: 2 + 6 * t,
              ),
              BoxShadow(
                color: glow.withValues(
                  alpha: (glow.a * (0.8 + 0.6 * t)).clamp(0.0, 1.0),
                ),
                blurRadius: 4,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Rings leaving the listening mic, in the scene accent.
class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.animation,
    required this.color,
    required this.active,
    required this.still,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool active;
  final bool still;

  static const int _rings = 2;
  static const double _reach = 34;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) {
      return;
    }
    final Offset center = size.center(Offset.zero);
    final double base = size.shortestSide / 2;
    final List<double> phases = still
        ? const <double>[0.35]
        : <double>[
            for (int i = 0; i < _rings; i++) (animation.value + i / _rings) % 1,
          ];
    for (final double p in phases) {
      final double eased = Curves.easeOutCubic.transform(p);
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - eased) + 0.5
        ..color = color.withValues(alpha: 0.55 * math.pow(1 - p, 1.4));
      canvas.drawCircle(center, base + _reach * eased, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.active != active ||
      oldDelegate.still != still;
}
