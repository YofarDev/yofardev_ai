import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';

import '../../../core/models/sound_effects.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/router/route_constants.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/models/chat_entry.dart';
import '../widgets/chat_avatar.dart';
import 'modern_chat_bubble.dart';

class ChatMessageItem extends StatelessWidget {
  final List<ChatEntry> entries;
  final int index;
  final bool isTyping;
  final bool showEverything;
  final bool isStreaming;
  final String Function(String, bool) limitParameterSize;

  const ChatMessageItem({
    super.key,
    required this.entries,
    required this.index,
    required this.isTyping,
    required this.showEverything,
    required this.isStreaming,
    required this.limitParameterSize,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFromUser = entries[index].entryType == EntryType.user;
    String soundEffect = '';
    if (!isFromUser) {
      try {
        final dynamic json = jsonDecode(entries[index].body);
        soundEffect =
            (json as Map<String, dynamic>)['soundEffect'] as String? ?? '';
      } catch (_) {
        soundEffect = '';
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isFromUser ? (isTyping ? 0 : 32) : 0,
        right: isFromUser ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (entries[index].getMessage().isNotEmpty)
            ModernChatBubble(
              isUser: isFromUser,
              showAvatar: !isFromUser,
              avatar: const ChatAvatar(),
              timestamp: _formatTime(entries[index].timestamp),
              isStreaming: isStreaming && !isFromUser,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ParsedText(
                    selectable: true,
                    text: showEverything
                        ? limitParameterSize(entries[index].body, isFromUser)
                        : entries[index].getMessage(isFromUser: isFromUser),
                    style: TextStyle(
                      color: isFromUser
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  if (soundEffect.isNotEmpty) const SizedBox(height: 8),
                  if (soundEffect.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _SoundEffectButton(
                        soundEffect: soundEffect,
                        isFromUser: isFromUser,
                      ),
                    ),
                ],
              ),
            ),
          if (entries[index].attachedImage != null)
            _AttachedImage(
              imagePath: entries[index].attachedImage!,
              isFromUser: isFromUser,
            ),
          if (index == 0 && isTyping) const _TypingIndicator(),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SoundEffectButton extends StatelessWidget {
  final String soundEffect;
  final bool isFromUser;

  const _SoundEffectButton({
    required this.soundEffect,
    required this.isFromUser,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final SoundEffects? sound = soundEffect.getSoundEffectFromString();
        if (sound == null) return;
        final AudioPlayer player = AudioPlayer();
        await player.setSource(
          AssetSource(sound.getPath().replaceFirst('assets/', '')),
        );
        await player.resume();
        // Note: we can't easily dispose here because it might stop playback
        // In a real app we might want to manage this better or use a singleton
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.glassSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.volume_up_outlined,
          color: isFromUser
              ? AppColors.onPrimary.withValues(alpha: 0.8)
              : AppColors.primary,
          size: 16,
        ),
      ),
    );
  }
}

class _AttachedImage extends StatelessWidget {
  final String imagePath;
  final bool isFromUser;

  const _AttachedImage({required this.imagePath, required this.isFromUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Align(
        alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: GestureDetector(
            onTap: () {
              context.push('${RouteConstants.imageFullScreen}?path=$imagePath');
            },
            child: Hero(
              tag: imagePath,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                width: 150,
                height: 150,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 8),
      child: Row(
        children: <Widget>[
          const ChatAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.glassSurface.withValues(alpha: 0.15),
                  AppColors.glassSurface.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Lottie.asset(
              AppUtils.fixAssetsPath('assets/lotties/typing.json'),
              height: 40,
            ),
          ),
        ],
      ),
    );
  }
}
