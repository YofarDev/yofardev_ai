import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/components/interactive_surface.dart';
import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/failure_localization.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/talking_phase.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/speech/speech_input_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/widgets/picker_buttons.dart';
import '../../../chat/chat.dart';
import '../../../settings/settings.dart';
import '../../../talking/talking.dart';
import 'composer_mode.dart';
import 'stage_composer_menu.dart';

/// The Home "Stage" composer: one glass pill that morphs between idle,
/// typing, listening, thinking, speaking and error (see
/// [resolveComposerMode]), with the Rive [ComposerOrb] as its one action.
///
/// The orb is the mic when idle, send while typing (or listening: it stops
/// and sends the words), and stop while the avatar thinks or speaks. The
/// composer never hides: during a reply the orb is the stop control in
/// place.
///
/// [speech] is injected (Home widgets never read the service locator);
/// [pickImage] defaults to the shared gallery picker. [onModeChanged] hears
/// every mode change (after the frame that shows it), so the Stage can hide
/// its caption while the composer listens or thinks.
class StageComposer extends StatefulWidget {
  const StageComposer({
    super.key,
    required this.speech,
    this.pickImage = pickImageFile,
    this.onModeChanged,
  });

  final SpeechInputService speech;
  final Future<File?> Function() pickImage;
  final ValueChanged<ComposerOrbState>? onModeChanged;

  static const double height = 56;
  static const double orbSize = 48;
  static const Key liveWordsKey = ValueKey<String>('stage-live-words');

  /// Width used when the parent does not bound it (Home always does).
  static const double unboundedWidth = 360;

  /// How long the orb shows the error state after a failed reply.
  static const Duration errorFlash = Duration(milliseconds: 600);

  @override
  State<StageComposer> createState() => _StageComposerState();
}

class _StageComposerState extends State<StageComposer>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.max,
  );

  File? _pickedImage;
  bool _hasText = false;
  bool _listening = false;

  /// A listening tap is waiting for [SpeechInputService.stop]: the orb keeps
  /// its listening look and ignores taps until the words are in.
  bool _stopping = false;
  bool _submitting = false;
  String _partialWords = '';

  /// Bumped by every listening session, so a late [SpeechInputService.start]
  /// result can tell whether it still belongs to the current one.
  int _session = 0;

  /// The orb shows the error state; [_errorTimer] clears it after
  /// [StageComposer.errorFlash].
  bool _flashingError = false;
  Timer? _errorTimer;

  /// The last mode handed to [StageComposer.onModeChanged].
  ComposerOrbState? _reportedMode;

  StreamSubscription<double>? _levelSub;
  StreamSubscription<String>? _wordsSub;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (_listening) {
      unawaited(widget.speech.cancel());
    }
    unawaited(_levelSub?.cancel());
    unawaited(_wordsSub?.cancel());
    _errorTimer?.cancel();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    _level.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _haptic() {
    if (PlatformUtils.isMobile()) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  String _localeId() =>
      context.read<SettingsCubit>().state.currentLanguage == 'fr'
      ? 'fr_FR'
      : 'en_US';

  void _onOrbTap(ComposerOrbState mode) {
    switch (mode) {
      case ComposerOrbState.idle:
        if (widget.speech.isSupported) {
          unawaited(_startListening());
        } else {
          _focusNode.requestFocus();
        }
      case ComposerOrbState.typing:
        unawaited(_submit(_controller.text));
      case ComposerOrbState.listening:
        unawaited(_stopListening());
      case ComposerOrbState.thinking:
      case ComposerOrbState.speaking:
        unawaited(context.read<InterruptionService>().interrupt());
      case ComposerOrbState.error:
        break;
    }
  }

  Future<void> _startListening() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String localeId = _localeId();
    final int session = ++_session;
    _haptic();
    _focusNode.unfocus();
    setState(() {
      _listening = true;
      _partialWords = '';
    });
    _levelSub = widget.speech.soundLevel.listen(
      (double level) => _level.value = level,
    );
    _wordsSub = widget.speech.partialWords.listen((String words) {
      if (mounted && _listening) {
        setState(() => _partialWords = words);
      }
    });

    final SpeechStartResult result = await widget.speech.start(
      localeId: localeId,
    );
    // Stopped, restarted or gone while the start was pending: nothing to
    // report for this session.
    if (!mounted || !_listening || _stopping || session != _session) {
      return;
    }
    switch (result) {
      case SpeechStartResult.started:
      case SpeechStartResult.cancelled:
        return;
      case SpeechStartResult.permissionDenied:
        _endListening();
        showAppToast(context, l10n.micPermissionDenied);
      case SpeechStartResult.unavailable:
        _endListening();
        showAppToast(context, l10n.micUnavailable);
    }
  }

  /// Leaves the listening look (the session itself is stopped by the
  /// caller, when there is one).
  void _endListening() {
    unawaited(_levelSub?.cancel());
    unawaited(_wordsSub?.cancel());
    _levelSub = null;
    _wordsSub = null;
    _level.value = 0;
    setState(() {
      _listening = false;
      _stopping = false;
      _partialWords = '';
    });
  }

  /// Stops the session and sends what was heard. The composer stays in its
  /// listening look until [SpeechInputService.stop] answers, then leaves it
  /// in the same frame as the submit, so the orb never flashes the mic.
  Future<void> _stopListening() async {
    if (_stopping) {
      return;
    }
    setState(() => _stopping = true);
    final String words = await widget.speech.stop();
    if (!mounted) {
      return;
    }
    _endListening();
    await _submit(words);
  }

  /// Sends [text] as AiTextInput does: stream the reply, then reset the
  /// chat status.
  Future<void> _submit(String text) async {
    final String prompt = text.trim();
    if (prompt.isEmpty || _submitting) {
      return;
    }
    final ChatCubit chatCubit = context.read<ChatCubit>();
    final ChatState chatState = chatCubit.state;
    final String language = context.read<SettingsCubit>().state.currentLanguage;
    final String? attachedImage = _pickedImage?.path;
    _haptic();
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _pickedImage = null;
      _submitting = true;
    });

    try {
      await chatCubit.streamResponse(
        prompt,
        onlyText: false,
        attachedImage: attachedImage,
        avatar: chatState.currentChat.avatar,
        currentChat: chatState.currentChat,
        language: language,
        functionCallingEnabled: chatState.functionCallingEnabled,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'streamResponse failed',
        tag: 'StageComposer',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      // The cubit outlives the composer: reset it even if Home is gone.
      chatCubit.resetStatus();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _attachImage() async {
    final String describe = AppLocalizations.of(context).describeThisImage;
    final File? file = await widget.pickImage();
    if (!mounted || file == null) {
      return;
    }
    setState(() => _pickedImage = file);
    if (_controller.text.trim().isEmpty) {
      _controller.text = describe;
    }
  }

  void _onChatStatus(BuildContext context, ChatState state) {
    final Failure? failure = state.error;
    if (state.status != ChatStatus.error || failure == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorTimer = Timer(StageComposer.errorFlash, () {
      if (mounted) {
        setState(() => _flashingError = false);
      }
    });
    setState(() => _flashingError = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shake.forward(from: 0));
    }
    showAppToast(
      context,
      localizeFailure(AppLocalizations.of(context), failure),
      error: true,
    );
  }

  /// Tells [StageComposer.onModeChanged] about [mode] once this frame is
  /// done (the parent may rebuild on it, which it can't during this build).
  void _reportMode(ComposerOrbState mode) {
    if (widget.onModeChanged == null || mode == _reportedMode) {
      return;
    }
    _reportedMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reportedMode == mode) {
        widget.onModeChanged?.call(mode);
      }
    });
  }

  String _orbLabel(AppLocalizations l10n, ComposerOrbState mode) =>
      switch (mode) {
        ComposerOrbState.idle =>
          widget.speech.isSupported ? l10n.composerListen : l10n.askAnything,
        ComposerOrbState.typing => l10n.composerSend,
        // Nothing heard yet: a tap just ends the session.
        ComposerOrbState.listening =>
          _partialWords.isEmpty ? l10n.composerStop : l10n.composerSend,
        ComposerOrbState.thinking ||
        ComposerOrbState.speaking => l10n.composerStop,
        ComposerOrbState.error => l10n.composerListen,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TalkingPhase phase = context.select<TalkingCubit, TalkingPhase>(
      (TalkingCubit cubit) => cubit.state.phase,
    );
    final ChatStatus chatStatus = context.select<ChatCubit, ChatStatus>(
      (ChatCubit cubit) => cubit.state.status,
    );
    final ComposerOrbState mode = resolveComposerMode(
      phase: phase,
      chatStatus: chatStatus,
      hasText: _hasText,
      listening: _listening,
      submitting: _submitting,
      error: _flashingError,
    );
    _reportMode(mode);
    final Duration morph = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.fast
        : AppMotion.base;
    final File? pickedImage = _pickedImage;

    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (ChatState previous, ChatState current) =>
          previous.status != current.status,
      listener: _onChatStatus,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The field takes what the orb and the pill's padding leave.
          final double width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : StageComposer.unboundedWidth;
          final double fieldWidth = math.max(
            0,
            width - StageComposer.orbSize - AppSpace.xs * 2,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedSize(
                duration: morph,
                curve: AppMotion.standard,
                alignment: Alignment.bottomCenter,
                child: _listening && _partialWords.isNotEmpty
                    ? _LiveWords(
                        key: StageComposer.liveWordsKey,
                        words: _partialWords,
                      )
                    : const SizedBox(width: double.infinity),
              ),
              AnimatedSize(
                duration: morph,
                curve: AppMotion.standard,
                alignment: Alignment.bottomLeft,
                child: pickedImage == null || _listening
                    ? const SizedBox(width: double.infinity)
                    : _PickedImage(
                        file: pickedImage,
                        removeLabel: l10n.commonDelete,
                        onRemove: () => setState(() => _pickedImage = null),
                      ),
              ),
              Center(
                child: _Pill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      // The field and "+" fold away while listening, leaving
                      // the orb centred in a round pill.
                      AnimatedSwitcher(
                        duration: morph,
                        switchInCurve: AppMotion.standard,
                        switchOutCurve: AppMotion.standard,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axis: Axis.horizontal,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: child,
                                  ),
                                ),
                        child: _listening
                            ? const SizedBox(
                                key: ValueKey<String>('folded'),
                                height: StageComposer.orbSize,
                              )
                            : SizedBox(
                                key: const ValueKey<String>('field'),
                                width: fieldWidth,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    StageComposerMenu(
                                      onAttach: kIsWeb ? null : _attachImage,
                                    ),
                                    Expanded(
                                      child: _Field(
                                        controller: _controller,
                                        focusNode: _focusNode,
                                        hint: l10n.askAnything,
                                        onSubmitted: () =>
                                            _submit(_controller.text),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      _Shake(
                        animation: _shake,
                        child: _OrbButton(
                          mode: mode,
                          level: _level,
                          label: _orbLabel(l10n, mode),
                          onTap: mode == ComposerOrbState.error || _stopping
                              ? null
                              : () => _onOrbTap(mode),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The thick glass pill around the composer's row.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      level: AppGlassLevel.thick,
      blur: true,
      borderRadius: BorderRadius.circular(
        context.tokens.radius(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(AppSpace.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: StageComposer.height - AppSpace.xs * 2,
        ),
        child: child,
      ),
    );
  }
}

/// The prompt field: borderless body text, the scene accent as caret, up to
/// four lines.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final Color onSurface = context.colors.onSurface;
    final TextStyle? style = context.text.bodyLarge?.copyWith(color: onSurface);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: context.tokens.scene.accent,
      style: style,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style?.copyWith(color: onSurface.withValues(alpha: 0.6)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.md,
        ),
      ),
    );
  }
}

/// The orb in its 48 dp tap target, announced as a button named after what
/// a tap does in the current [mode]. Disabled when [onTap] is null.
class _OrbButton extends StatelessWidget {
  const _OrbButton({
    required this.mode,
    required this.level,
    required this.label,
    required this.onTap,
  });

  final ComposerOrbState mode;
  final ValueListenable<double> level;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.scene.accent;
    final bool enabled = onTap != null;
    return InteractiveSurface(
      onTap: onTap,
      builder: (BuildContext context, InteractiveStates states) {
        return Semantics(
          button: true,
          enabled: enabled,
          focusable: enabled,
          focused: states.focused,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: states.focused ? accent : Colors.transparent,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: SizedBox.square(
              dimension: StageComposer.orbSize,
              child: ValueListenableBuilder<double>(
                valueListenable: level,
                builder: (BuildContext context, double level, Widget? _) =>
                    ComposerOrb(
                      state: mode,
                      level: mode == ComposerOrbState.listening ? level : 0,
                      size: StageComposer.orbSize,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A short horizontal shake that settles (the error flash).
class _Shake extends StatelessWidget {
  const _Shake({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const double _amplitude = 6;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value;
        final double dx = t == 0 || t == 1
            ? 0
            : math.sin(t * math.pi * 6) * (1 - t) * _amplitude;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// What the recognizer has heard so far, above the listening orb.
class _LiveWords extends StatelessWidget {
  const _LiveWords({super.key, required this.words});

  final String words;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.tokens.background;
    final Color onSurface = context.colors.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.lg,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          words,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            height: 1.35,
            color: onSurface,
            shadows: <Shadow>[
              Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// The image that will go with the next prompt, with a remove button.
class _PickedImage extends StatelessWidget {
  const _PickedImage({
    required this.file,
    required this.removeLabel,
    required this.onRemove,
  });

  final File file;
  final String removeLabel;
  final VoidCallback onRemove;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.sm, bottom: AppSpace.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(
              context.tokens.radius(AppRadius.md),
            ),
            child: Image.file(
              file,
              width: _thumb,
              height: _thumb,
              fit: BoxFit.cover,
              // The file may be gone (cleared cache): keep a placeholder.
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      SizedBox.square(
                        dimension: _thumb,
                        child: Icon(
                          Icons.image_outlined,
                          color: context.colors.onSurface,
                        ),
                      ),
            ),
          ),
          AppIconButton(
            onPressed: onRemove,
            icon: Icons.close_rounded,
            semanticLabel: removeLabel,
          ),
        ],
      ),
    );
  }
}
