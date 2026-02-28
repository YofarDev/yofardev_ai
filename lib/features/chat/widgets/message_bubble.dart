import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../l10n/localization_manager.dart';
import '../../../../models/chat_entry.dart';
import '../../../../models/sound_effects.dart';
import '../../../../utils/app_utils.dart';

/// Message bubble widget for individual chat messages
/// Extracted from chat_details_page.dart (326 → 180 lines)
class MessageBubble extends StatelessWidget {
  final ChatEntry entry;
  final bool isTyping;
  final bool showEverything;
  final void Function(String)? onImageTap;

  const MessageBubble({
    super.key,
    required this.entry,
    required this.isTyping,
    required this.showEverything,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFromUser = entry.entryType == EntryType.user;
    String soundEffect = '';
    if (!isFromUser) {
      final dynamic json = jsonDecode(entry.body);
      soundEffect =
          (json as Map<String, dynamic>)['soundEffect'] as String? ?? '';
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isFromUser ? (isTyping ? 0 : 32) : 0,
        right: isFromUser ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isFromUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: <Widget>[
                if (!isFromUser) const _CircleAvatar(),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !isFromUser ? Colors.blue : Colors.pink[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        ParsedText(
                          selectable: true,
                          text: showEverything
                              ? _limitParameterSize(
                                  entry.body,
                                  isFromUser,
                                  context,
                                )
                              : entry.getMessage(isFromUser: isFromUser),
                          style: TextStyle(
                            color: !isFromUser ? Colors.white : Colors.black,
                          ),
                        ),
                        if (soundEffect.isNotEmpty)
                          _SoundEffectButton(soundEffect: soundEffect),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (entry.attachedImage != null)
            _AttachedImage(
              imagePath: entry.attachedImage!,
              onTap: () => onImageTap?.call(entry.attachedImage!),
            ),
          if (isTyping) const _TypingIndicator(),
        ],
      ),
    );
  }
}

String _limitParameterSize(String body, bool isFromUser, BuildContext context) {
  if (!isFromUser) return body;
  try {
    const int limit = 2000;
    if (body.length > limit) {
      final String reduced = '${body.substring(0, limit)} [...]';
      String userMessage = '';
      final int startIndex = body.indexOf("'''");
      final int endIndex = body.lastIndexOf("'''");
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        userMessage = body.substring(startIndex + 3, endIndex);
      } else {
        return body;
      }
      final LocalizationManager localized = LocalizationManager();
      return "$reduced\n${localized.currentLanguage.userMessage} : \n'''$userMessage'''";
    }
    return body;
  } catch (e) {
    debugPrint('Error: $e');
    return body;
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CircleAvatar(
        backgroundColor: Colors.blue,
        foregroundImage: AssetImage(AppUtils.fixAssetsPath("assets/icon.png")),
      ),
    );
  }
}

class _SoundEffectButton extends StatelessWidget {
  final String soundEffect;

  const _SoundEffectButton({required this.soundEffect});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () async {
          final SoundEffects? sound = soundEffect.getSoundEffectFromString();
          if (sound == null) return;
          final AudioPlayer player = AudioPlayer();
          await player.setAsset(sound.getPath());
          await player.play();
          player.dispose();
        },
        child: const Icon(Icons.volume_up_outlined, color: Colors.white),
      ),
    );
  }
}

class _AttachedImage extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onTap;

  const _AttachedImage({required this.imagePath, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: GestureDetector(
            onTap: onTap,
            child: Hero(
              tag: imagePath,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                width: 100,
                height: 100,
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
    return Row(
      children: <Widget>[
        const _CircleAvatar(),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 60,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
