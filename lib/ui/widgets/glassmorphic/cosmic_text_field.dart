import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../res/app_colors.dart';

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
