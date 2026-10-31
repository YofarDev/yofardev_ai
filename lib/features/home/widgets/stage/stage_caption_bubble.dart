import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/performance/shot.dart';
import '../../../../core/models/talking_phase.dart';
import '../../../avatar/avatar.dart';
import '../../../talking/talking.dart';
import 'stage_bubble_layout.dart';
import 'stage_caption.dart';

/// Why the classic caption shows instead of the bubble (M10 ruling 14).
enum CaptionFallback {
  /// A screen reader is on: the classic caption is one stable live region.
  screenReader,

  /// Text scaled to [StageCaptionBubble.largeTextScale] or more.
  largeText,

  /// A journey or a presence walk runs.
  walking,

  /// The camera frames the prop insert.
  propInsert,

  /// The avatar file has no `MouthAnchor` (or the web, or no avatar yet).
  noAnchor,

  /// The mouth is off the stage.
  offStage,

  /// The sentence needs more than [StageBubbleLayout.maxLines] lines.
  tooLong,

  /// The bubble does not fit beside or over the face inside the chrome.
  noRoom,
}

/// The live caption in the world (moonshot M10 rulings 13–14): while the
/// avatar speaks a sentence with captions on, a glass speech bubble beside
/// the mouth, its tail pointing at it.
///
/// The bubble takes the side of the face with more room (over the head when
/// neither side has [StageBubbleLayout.minSideWidth]), at most 72 % of the
/// stage wide and 4 lines tall, inside the stage minus [reserved] (the top
/// chips, the tool chip and the composer), never over the face (a keep-out
/// box around the mouth, the head's size mapped to the stage). Its side,
/// size and text are laid out once per sentence; it then follows the mouth
/// ([anchor], artboard px, mapped through the avatar's fit and the
/// [camera]) with a critically damped ~8 Hz follow that ignores moves under
/// 1 dp. Reduce motion: placed once per sentence, never follows, a plain
/// [AppMotion.fast] fade.
///
/// [shown] is true while the bubble stands in for the classic
/// [StageCaption] (which then hides); false for any [CaptionFallback]. A
/// tap turns captions off, like the classic caption.
class StageCaptionBubble extends StatefulWidget {
  const StageCaptionBubble({
    super.key,
    required this.composerMode,
    required this.anchor,
    required this.shown,
    this.camera,
    this.reserved = EdgeInsets.zero,
  });

  final ValueListenable<ComposerOrbState> composerMode;

  /// The mouth in avatar-artboard px; null: no anchor.
  final ValueListenable<Offset?> anchor;

  /// Written (after the frame) with whether the bubble shows the caption.
  final ValueNotifier<bool> shown;

  /// What the stage camera frames (null: no camera, the whole stage).
  final StageCameraView? camera;

  /// The stage's edges the chrome takes; the bubble stays inside the rest.
  final EdgeInsets reserved;

  static const Key bubbleKey = ValueKey<String>('stage-caption-bubble');
  static const Key textKey = ValueKey<String>('stage-caption-bubble-text');

  /// Text scaled this much or more: the classic caption.
  static const double largeTextScale = 1.5;

  /// The bubble's opaque-ish backing under the glass (`glassSurface`), so
  /// the caption ink keeps 4.5:1 over any scene.
  static const double backingAlpha = 0.78;

  /// The glass level of the bubble.
  static const AppGlassLevel glassLevel = AppGlassLevel.thick;

  /// Text padding inside the bubble's body (the tail adds its height below).
  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    AppSpace.lg,
    AppSpace.md,
    AppSpace.lg,
    AppSpace.md,
  );

  /// The fill the caption ink sits on, over a [backdrop] (the scene): the
  /// backing, then the glass at [glassAlpha] (a `GlassPanel` gradient runs
  /// from its level's `fillAlpha` to 0.4 of it).
  static Color fillOver(AppTokens tokens, Color backdrop, double glassAlpha) {
    final Color backing = tokens.glassSurface.withValues(alpha: backingAlpha);
    final Color glass = Color.alphaBlend(
      tokens.scene.glassTint,
      tokens.glassSurface.withValues(alpha: 1),
    );
    return Color.alphaBlend(
      glass.withValues(alpha: glassAlpha),
      Color.alphaBlend(backing, backdrop),
    );
  }

  /// Why the classic caption must show, sentence aside (null: the bubble
  /// may). [anchor] is the mouth on a [stage] in stage px.
  static CaptionFallback? fallbackFor({
    required bool screenReader,
    required double textScale,
    required bool walking,
    required Shot shot,
    required Offset? anchor,
    required Size stage,
  }) {
    if (screenReader) {
      return CaptionFallback.screenReader;
    }
    if (textScale >= largeTextScale) {
      return CaptionFallback.largeText;
    }
    if (walking) {
      return CaptionFallback.walking;
    }
    if (shot == Shot.propInsert) {
      return CaptionFallback.propInsert;
    }
    if (anchor == null) {
      return CaptionFallback.noAnchor;
    }
    if (!(Offset.zero & stage).contains(anchor)) {
      return CaptionFallback.offStage;
    }
    return null;
  }

  @override
  State<StageCaptionBubble> createState() => _StageCaptionBubbleState();
}

/// One sentence's bubble, laid out once.
class _Sentence {
  _Sentence({
    required this.seq,
    required this.text,
    required this.key,
    required this.side,
    required this.size,
    required this.tailAt,
  });

  final int seq;
  final String text;

  /// What the layout depended on (a change re-lays it out).
  final Object key;
  final BubbleSide side;
  final Size size;
  final double tailAt;
}

/// Bumped to move the bubble without rebuilding its parent.
class _Moves extends ChangeNotifier {
  void moved() => notifyListeners();
}

class _StageCaptionBubbleState extends State<StageCaptionBubble>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _Moves _moves = _Moves();
  Duration _lastTick = Duration.zero;

  Size _stage = Size.zero;
  Rect _safe = Rect.zero;
  bool _reduceMotion = false;

  /// The sentence on the bubble (kept while it fades out).
  _Sentence? _sentence;

  /// The sentence the bubble is showing now (null: fading out or none).
  _Sentence? _active;

  /// A sentence that stopped fitting while it followed: classic until the
  /// next one.
  int? _stuckSeq;

  BubbleFollow? _follow;
  Offset _topLeft = Offset.zero;

  /// What the last build saw of the anchor and the shot (a change of either
  /// rebuilds; a move does not).
  bool _anchorUsable = false;
  Shot _shot = Shot.wide;

  bool? _shownPending;

  @override
  void initState() {
    super.initState();
    widget.anchor.addListener(_onMoved);
    widget.camera?.addListener(_onMoved);
  }

  @override
  void didUpdateWidget(StageCaptionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchor != oldWidget.anchor) {
      oldWidget.anchor.removeListener(_onMoved);
      widget.anchor.addListener(_onMoved);
    }
    if (widget.camera != oldWidget.camera) {
      oldWidget.camera?.removeListener(_onMoved);
      widget.camera?.addListener(_onMoved);
    }
  }

  @override
  void dispose() {
    widget.anchor.removeListener(_onMoved);
    widget.camera?.removeListener(_onMoved);
    _ticker.dispose();
    _moves.dispose();
    super.dispose();
  }

  StageFrame get _frame => widget.camera?.frame ?? StageFraming.identity;

  Shot get _currentShot => widget.camera?.shot ?? Shot.wide;

  /// The mouth on the stage now (null: no anchor or no stage yet).
  Offset? _anchorOnStage() {
    final Offset? a = widget.anchor.value;
    if (a == null || _stage.isEmpty) {
      return null;
    }
    return StageFraming.artboardToStage(a, _stage, frame: _frame);
  }

  double get _scale => StageFraming.stageScale(_stage, _frame);

  bool _usable(Offset? p) => p != null && (Offset.zero & _stage).contains(p);

  /// The anchor or the camera moved (never during a build).
  void _onMoved() {
    if (!mounted) {
      return;
    }
    final Offset? p = _anchorOnStage();
    if (_usable(p) != _anchorUsable || _currentShot != _shot) {
      setState(() {});
      return;
    }
    final _Sentence? sentence = _active;
    if (sentence == null || p == null) {
      return;
    }
    if (_reduceMotion) {
      // Placed once, never follows; the face moving under it sends the
      // sentence to the classic caption.
      final Rect rect = _topLeft & sentence.size;
      if (rect.overlaps(StageBubbleLayout.keepOut(p, _scale))) {
        _stick(sentence);
      }
      return;
    }
    final BubbleFollow? follow = _follow;
    if (follow != null && follow.target(p) && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final BubbleFollow? follow = _follow;
    final _Sentence? sentence = _active;
    final Offset? target = _anchorOnStage();
    if (follow == null || sentence == null || target == null) {
      _ticker.stop();
      return;
    }
    follow.step(dt);
    final double scale = _scale;
    final BubblePlacement? at = StageBubbleLayout.place(
      side: sentence.side,
      size: sentence.size,
      anchor: follow.position,
      keepOut: StageBubbleLayout.keepOut(follow.position, scale),
      safe: _safe,
      tailAt: sentence.tailAt,
    );
    if (at == null ||
        at.rect.overlaps(StageBubbleLayout.keepOut(target, scale))) {
      _stick(sentence);
      return;
    }
    _topLeft = at.rect.topLeft;
    _moves.moved();
    if (follow.isSettled) {
      _ticker.stop();
    }
  }

  /// [sentence] no longer fits: the classic caption takes it over.
  void _stick(_Sentence sentence) {
    _ticker.stop();
    setState(() => _stuckSeq = sentence.seq);
  }

  /// Tells [StageCaptionBubble.shown] after this frame (a listener may
  /// rebuild, which a build must not).
  void _publishShown(bool shown) {
    if (_shownPending == shown ||
        (_shownPending == null && widget.shown.value == shown)) {
      return;
    }
    _shownPending = shown;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      final bool? pending = _shownPending;
      _shownPending = null;
      if (mounted && pending != null) {
        widget.shown.value = pending;
      }
    });
  }

  /// The bubble for the sentence [text] ([seq]), laid out once; null with
  /// the reason the classic caption shows instead.
  (_Sentence?, CaptionFallback?) _layOut(
    BuildContext context,
    int seq,
    String text,
    Offset anchor,
    TextStyle? style,
    TextScaler scaler,
  ) {
    final Object key = (seq, text, _stage, _safe, scaler, style);
    final _Sentence? cached = _sentence;
    if (cached != null && cached.key == key) {
      return (cached, null);
    }
    final double scale = _scale;
    final BubblePlan plan = StageBubbleLayout.plan(
      stage: _stage,
      safe: _safe,
      anchor: anchor,
      scale: scale,
    );
    final EdgeInsets pad = StageCaptionBubble.padding;
    final double textMax = plan.maxWidth - pad.horizontal;
    if (textMax <= 0) {
      return (null, CaptionFallback.noRoom);
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: textMax);
    final int lines = painter.computeLineMetrics().length;
    final Size size = Size(
      painter.width.ceilToDouble() + pad.horizontal,
      painter.height.ceilToDouble() +
          pad.vertical +
          SpeechBubbleBorder.tailHeight,
    );
    painter.dispose();
    if (lines > StageBubbleLayout.maxLines) {
      return (null, CaptionFallback.tooLong);
    }
    final BubblePlacement? at = StageBubbleLayout.place(
      side: plan.side,
      size: size,
      anchor: anchor,
      keepOut: StageBubbleLayout.keepOut(anchor, scale),
      safe: _safe,
    );
    if (at == null) {
      return (null, CaptionFallback.noRoom);
    }
    final _Sentence sentence = _Sentence(
      seq: seq,
      text: text,
      key: key,
      side: plan.side,
      size: size,
      tailAt: at.tailAt,
    );
    _sentence = sentence;
    // A new sentence starts where it is laid out.
    _ticker.stop();
    _follow = BubbleFollow(anchor);
    _topLeft = at.rect.topLeft;
    return (sentence, null);
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool screenReader = MediaQuery.accessibleNavigationOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final bool generating = context.select<TalkingCubit, bool>(
      (TalkingCubit cubit) => cubit.state.phase == TalkingPhase.generating,
    );
    final bool walking = context.select<AvatarCubit, bool>(
      (AvatarCubit cubit) =>
          cubit.state.journey != null ||
          cubit.state.presence != AvatarSpecials.onScreen,
    );
    final TextStyle? style = context.text.titleLarge?.copyWith(
      height: 1.22,
      color: context.tokens.scene.captionInk,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _stage = constraints.biggest;
        final EdgeInsets r = widget.reserved;
        _safe = Rect.fromLTRB(
          r.left,
          r.top,
          _stage.width - r.right,
          _stage.height - r.bottom,
        );
        return ValueListenableBuilder<ComposerOrbState>(
          valueListenable: widget.composerMode,
          builder: (BuildContext context, ComposerOrbState mode, Widget? _) =>
              BlocBuilder<CaptionCubit, CaptionState>(
                builder: (BuildContext context, CaptionState caption) {
                  final Offset? anchor = _anchorOnStage();
                  _anchorUsable = _usable(anchor);
                  _shot = _currentShot;
                  CaptionFallback? reason = StageCaptionBubble.fallbackFor(
                    screenReader: screenReader,
                    textScale: scaler.scale(1),
                    walking: walking,
                    shot: _shot,
                    anchor: anchor,
                    stage: _stage,
                  );
                  final String? text =
                      caption.enabled &&
                          !StageCaption.hiddenDuring(
                            mode,
                            generating: generating,
                          )
                      ? caption.text
                      : null;
                  _Sentence? sentence;
                  if (reason == null &&
                      anchor != null &&
                      text != null &&
                      text.isNotEmpty) {
                    if (_stuckSeq == caption.seq) {
                      reason = CaptionFallback.noRoom;
                    } else {
                      (sentence, reason) = _layOut(
                        context,
                        caption.seq,
                        text,
                        anchor,
                        style,
                        scaler,
                      );
                    }
                  }
                  _publishShown(reason == null);
                  if (sentence != null && _active?.seq != sentence.seq) {
                    _stuckSeq = null;
                  }
                  _active = sentence;
                  if (sentence == null) {
                    _ticker.stop();
                  }
                  return _visual(context, style);
                },
              ),
        );
      },
    );
  }

  /// The bubble of [_sentence], fading in while [_active], out otherwise.
  Widget _visual(BuildContext context, TextStyle? style) {
    final _Sentence? sentence = _sentence;
    if (sentence == null) {
      return const SizedBox.shrink();
    }
    final bool visible = _active == sentence;
    final Duration duration = _reduceMotion ? AppMotion.fast : AppMotion.base;
    final Alignment tail = Alignment(sentence.tailAt * 2 - 1, 1);
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          width: sentence.size.width,
          height: sentence.size.height,
          child: AnimatedBuilder(
            animation: _moves,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(offset: _topLeft, child: child),
            child: TweenAnimationBuilder<double>(
              key: ValueKey<int>(sentence.seq),
              tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
              duration: duration,
              curve: AppMotion.standard,
              builder: (BuildContext context, double t, Widget? child) {
                final Widget faded = Opacity(opacity: t, child: child);
                return IgnorePointer(
                  ignoring: !visible,
                  child: ExcludeSemantics(
                    excluding: !visible,
                    child: _reduceMotion
                        ? faded
                        : Transform.scale(
                            scale: 0.92 + 0.08 * t,
                            alignment: tail,
                            child: faded,
                          ),
                  ),
                );
              },
              child: _BubbleBody(
                text: sentence.text,
                tailAt: sentence.tailAt,
                style: style,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.text,
    required this.tailAt,
    required this.style,
  });

  final String text;
  final double tailAt;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final SpeechBubbleBorder shape = SpeechBubbleBorder(tailAt: tailAt);
    final EdgeInsets pad = StageCaptionBubble.padding;
    return Semantics(
      container: true,
      liveRegion: true,
      onTapHint: AppLocalizations.of(context).stageHideCaptions,
      child: GestureDetector(
        key: StageCaptionBubble.bubbleKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<CaptionCubit>().toggle(),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: context.tokens.glassSurface.withValues(
              alpha: StageCaptionBubble.backingAlpha,
            ),
            shape: shape,
          ),
          child: GlassPanel(
            level: StageCaptionBubble.glassLevel,
            shape: shape,
            padding: pad.copyWith(
              bottom: pad.bottom + SpeechBubbleBorder.tailHeight,
            ),
            child: Text(
              text,
              key: StageCaptionBubble.textKey,
              style: style,
              maxLines: StageBubbleLayout.maxLines,
              overflow: TextOverflow.ellipsis,
              textWidthBasis: TextWidthBasis.longestLine,
            ),
          ),
        ),
      ),
    );
  }
}
