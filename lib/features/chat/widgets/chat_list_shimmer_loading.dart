import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/res/app_colors.dart';

/// Shimmering placeholder for chat list during loading
///
/// Displays multiple shimmering placeholders that mimic the chat card structure
/// to provide visual continuity during loading states.
class ChatListShimmerLoading extends StatelessWidget {
  const ChatListShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Shimmer.fromColors(
        baseColor: AppColors.onSurface.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.2),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5, // Show 5 placeholder items
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShimmerChatCard(),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerChatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                _ShimmerIndicatorDot(),
                SizedBox(width: 14),
                Expanded(child: _ShimmerChatPreview()),
                SizedBox(width: 8),
                _ShimmerChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerIndicatorDot extends StatelessWidget {
  const _ShimmerIndicatorDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
    );
  }
}

class _ShimmerChatPreview extends StatelessWidget {
  const _ShimmerChatPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ShimmerTextLine(widthFactor: 0.7),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            _ShimmerTextLine(widthFactor: 0.3, height: 10),
            const SizedBox(width: 8),
            _ShimmerTextLine(widthFactor: 0.2, height: 10),
          ],
        ),
      ],
    );
  }
}

class _ShimmerTextLine extends StatelessWidget {
  const _ShimmerTextLine({required this.widthFactor, this.height = 14});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: widthFactor * 300, // Approximate max width
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerChevron extends StatelessWidget {
  const _ShimmerChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      color: Colors.white,
      size: 18,
    );
  }
}
