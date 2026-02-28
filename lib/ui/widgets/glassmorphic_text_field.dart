import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../res/app_colors.dart';

class GlassmorphicTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enableSpeechToText;
  final bool isSpeechListening;
  final VoidCallback? onSpeechPressed;
  final VoidCallback? onClearPressed;
  final bool showClearButton;

  const GlassmorphicTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enableSpeechToText = false,
    this.isSpeechListening = false,
    this.onSpeechPressed,
    this.onClearPressed,
    this.showClearButton = true,
  });

  @override
  State<GlassmorphicTextField> createState() => _GlassmorphicTextFieldState();
}

class _GlassmorphicTextFieldState extends State<GlassmorphicTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;
  late Animation<double> _borderAnimation;
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _borderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    final bool hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (BuildContext context, Widget? child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.2 * _glowAnimation.value,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(
                        alpha: 0.1 * _glowAnimation.value,
                      ),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.glassSurface.withValues(
                      alpha: _isFocused ? 0.15 : 0.08,
                    ),
                    AppColors.glassSurface.withValues(
                      alpha: _isFocused ? 0.1 : 0.05,
                    ),
                  ],
                ),
                border: Border.all(
                  color: _isFocused
                      ? Color.lerp(
                          AppColors.glassBorder,
                          AppColors.primary,
                          _borderAnimation.value * 0.5,
                        )!.withValues(alpha: 0.8)
                      : AppColors.glassBorder.withValues(alpha: 0.3),
                  width: _isFocused ? 1.5 : 1,
                ),
              ),
              child: BackdropFilter(
                filter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.1),
                  BlendMode.srcOver,
                ),
                child: TextField(
                  focusNode: _focusNode,
                  controller: _controller,
                  autofocus: widget.autofocus,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  cursorColor: AppColors.primary,
                  cursorWidth: 2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.onSurface,
                    height: 1.5,
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurface.withValues(alpha: 0.4),
                    ),
                    labelText: widget.labelText,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isFocused
                          ? AppColors.primary
                          : AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: _buildSuffixIcons(),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildSuffixIcons() {
    final List<Widget> icons = <Widget>[];

    if (widget.enableSpeechToText) {
      icons.add(
        _AnimatedIconButton(
          icon: Icons.mic,
          isActive: widget.isSpeechListening,
          activeColor: AppColors.error,
          onPressed: widget.onSpeechPressed,
        ),
      );
    }

    if (widget.showClearButton && _hasText) {
      icons.add(
        _AnimatedIconButton(
          icon: Icons.close_rounded,
          onPressed: () {
            _controller.clear();
            widget.onClearPressed?.call();
          },
        ),
      );
    }

    if (widget.suffixIcon != null) {
      icons.add(widget.suffixIcon!);
    }

    if (icons.isEmpty) return null;

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onPressed;

  const _AnimatedIconButton({
    required this.icon,
    this.isActive = false,
    this.activeColor,
    this.onPressed,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isActive
                  ? (widget.activeColor ?? AppColors.primary).withValues(
                      alpha: 0.15,
                    )
                  : Colors.transparent,
            ),
            child: IconButton(
              icon: Icon(
                widget.icon,
                color: widget.isActive
                    ? (widget.activeColor ?? AppColors.primary)
                    : AppColors.onSurface.withValues(alpha: 0.6),
                size: 22,
              ),
              onPressed: widget.onPressed,
            ),
          ),
        );
      },
    );
  }
}

class CosmicTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int maxLines;
  final bool autofocus;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;

  const CosmicTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return _CosmicTextFieldContent(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      labelText: labelText,
      maxLines: maxLines,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabled: enabled,
    );
  }
}

class _CosmicTextFieldContent extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int maxLines;
  final bool autofocus;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;

  const _CosmicTextFieldContent({
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  State<_CosmicTextFieldContent> createState() =>
      _CosmicTextFieldContentState();
}

class _CosmicTextFieldContentState extends State<_CosmicTextFieldContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();

    _focusNode.addListener(_onFocusChange);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (BuildContext context, Widget? child) {
        final double shimmerValue = _shimmerController.value;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * shimmerValue, 0),
              end: Alignment(2.0 * shimmerValue, 0),
              colors: _isFocused
                  ? <Color>[
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.accent.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.05),
                    ]
                  : <Color>[Colors.transparent, Colors.transparent],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _isFocused
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _isFocused ? 16 : 4,
                spreadRadius: _isFocused ? 2 : 0,
              ),
            ],
          ),
          child: TextField(
            enabled: widget.enabled,
            focusNode: _focusNode,
            controller: _controller,
            autofocus: widget.autofocus,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            cursorColor: AppColors.primary,
            cursorWidth: 2,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.onSurface,
              height: 1.5,
            ),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurface.withValues(alpha: 0.35),
              ),
              labelText: widget.labelText,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _isFocused
                    ? AppColors.primary
                    : AppColors.onSurface.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: widget.suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.glassBorder.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.glassBorder.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.glassBorder.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
