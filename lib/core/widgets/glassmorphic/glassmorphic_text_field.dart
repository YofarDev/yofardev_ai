import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../res/app_colors.dart';
import 'animated_icon_button.dart';

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
        AnimatedIconButton(
          icon: Icons.mic,
          isActive: widget.isSpeechListening,
          activeColor: AppColors.error,
          onPressed: widget.onSpeechPressed,
        ),
      );
    }

    if (widget.showClearButton && _hasText) {
      icons.add(
        AnimatedIconButton(
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
