import 'dart:async';

import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens/app_glass.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_tokens.dart';
import 'glass_panel.dart';

/// The toast on screen, if any: a new one replaces it.
OverlayEntry? _activeToast;

/// How long a toast stays up before it leaves.
const Duration appToastDuration = Duration(seconds: 3);

/// Shows [message] in a glass pill at the top of the screen, above every
/// route. It slides and fades in, then leaves on its own after
/// [appToastDuration]. One toast at a time: showing another replaces it.
/// [error] tints the pill with the error color.
void showAppToast(BuildContext context, String message, {bool error = false}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  _removeToast(_activeToast);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _AppToastHost(
      message: message,
      error: error,
      onDismissed: () => _removeToast(entry),
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

void _removeToast(OverlayEntry? entry) {
  if (entry == null) {
    return;
  }
  if (identical(entry, _activeToast)) {
    _activeToast = null;
  }
  // An entry whose overlay is already gone (torn-down tree) is just dropped.
  if (entry.mounted) {
    entry
      ..remove()
      ..dispose();
  }
}

/// Positions the toast under the top inset and runs its enter, wait and
/// exit.
class _AppToastHost extends StatefulWidget {
  const _AppToastHost({
    required this.message,
    required this.error,
    required this.onDismissed,
  });

  final String message;
  final bool error;
  final VoidCallback onDismissed;

  @override
  State<_AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<_AppToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.fast
        : AppMotion.base;
    if (_timer == null) {
      _controller.forward();
      _timer = Timer(appToastDuration, _dismiss);
    }
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    return Positioned(
      top: insets.top + AppSpace.sm,
      left: AppSpace.lg,
      right: AppSpace.lg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(_curve),
              child: AppToast(message: widget.message, error: widget.error),
            ),
          ),
        ),
      ),
    );
  }
}

/// The toast pill itself (what [showAppToast] shows): thick glass, the
/// message, and an error icon and tint when [error] is set. Screen readers
/// announce it as a live region.
class AppToast extends StatelessWidget {
  const AppToast({super.key, required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme colors = context.colors;
    final BorderRadius pill = BorderRadius.circular(
      tokens.radius(AppRadius.pill),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      // The overlay sits outside any Material: give the text its own.
      child: Material(
        type: MaterialType.transparency,
        child: GlassPanel(
          level: AppGlassLevel.thick,
          blur: true,
          borderRadius: pill,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: pill,
              color: error ? colors.error.withValues(alpha: 0.14) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (error) ...<Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 20,
                      color: colors.error,
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  Flexible(
                    child: Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
