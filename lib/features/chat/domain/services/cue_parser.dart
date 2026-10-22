import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/utils/logger.dart';

/// The clean text and the cues completed within one parsed stream chunk.
class ParsedChunk {
  const ParsedChunk(this.text, this.cues);

  /// Text with every cue removed — used for both display and TTS.
  final String text;

  /// Cues whose closing bracket appeared in this chunk, in order.
  final List<AvatarCue> cues;
}

/// Incremental parser for inline avatar cues (`[g:<gesture>]`,
/// `[s:<sceneEvent>]`) in the LLM stream.
///
/// The parser is stateful across chunks: a cue split across two chunks
/// (`[g:la` + `ugh]`) is still parsed, while text that merely looks like a
/// cue (`[note]`) passes through untouched. Cues are removed from the text
/// and returned per chunk so they can fire in time with TTS.
///
/// When [currentScene] is set, scene events that the scene's state machine
/// cannot play are dropped; when it is null (scene unknown), valid scene
/// events are kept unfiltered. Unknown cue names are always dropped and
/// logged.
class CueParser {
  CueParser({AvatarScene? currentScene}) : _currentScene = currentScene;

  AvatarScene? _currentScene;

  set currentScene(AvatarScene? scene) => _currentScene = scene;

  /// Tail of the input that may still grow into a cue.
  String _pending = '';

  /// `shootingStar` — the longest cue name in the contract.
  static const int _maxCueNameLength = 12;

  static final RegExp _cuePrefix = RegExp(r'^\[([gs]):([a-zA-Z]*)');

  /// Parses one chunk, returning clean text plus the cues it completed.
  ParsedChunk parse(String input) {
    final StringBuffer out = StringBuffer();
    final List<AvatarCue> cues = <AvatarCue>[];
    final String buffer = _pending + input;
    _pending = '';

    int i = 0;
    while (i < buffer.length) {
      final int start = buffer.indexOf('[', i);
      if (start < 0) {
        out.write(buffer.substring(i));
        break;
      }
      out.write(buffer.substring(i, start));

      final RegExpMatch? match = _cuePrefix.firstMatch(buffer.substring(start));
      if (match == null) {
        // Cannot be a cue: emit the bracket literally and rescan after it.
        out.write('[');
        i = start + 1;
        continue;
      }

      final bool closed =
          buffer.length > start + match.end &&
          buffer.codeUnitAt(start + match.end) == 0x5D; // ']'
      if (!closed) {
        if (match.group(2)!.length > _maxCueNameLength) {
          // Too long to ever become a valid cue: emit literally.
          out.write('[');
          i = start + 1;
          continue;
        }
        // Could still become a cue: hold until more input arrives.
        _pending = buffer.substring(start);
        break;
      }

      final AvatarCue? cue = _resolveCue(match.group(1)!, match.group(2)!);
      if (cue != null) {
        cues.add(cue);
      }
      i = start + match.end + 1;
    }

    return ParsedChunk(out.toString(), cues);
  }

  /// Emits whatever the parser was still holding as literal text. Call at
  /// the end of the stream.
  String flush() {
    final String remaining = _pending;
    _pending = '';
    return remaining;
  }

  /// Drops any held partial text, e.g. when a new stream starts.
  void reset() {
    _pending = '';
  }

  AvatarCue? _resolveCue(String kind, String name) {
    if (kind == 'g') {
      final AvatarGesture? gesture = AvatarGesture.values.firstWhereOrNull(
        (AvatarGesture g) => g.name == name,
      );
      if (gesture == null) {
        AppLogger.debug('Dropped unknown gesture cue: $name', tag: 'CueParser');
        return null;
      }
      return AvatarCue.gesture(gesture);
    }
    final SceneEvent? event = SceneEvent.values.firstWhereOrNull(
      (SceneEvent e) => e.name == name,
    );
    if (event == null) {
      AppLogger.debug(
        'Dropped unknown scene event cue: $name',
        tag: 'CueParser',
      );
      return null;
    }
    final AvatarScene? scene = _currentScene;
    if (scene != null && !scene.allowedEvents.contains(event)) {
      AppLogger.debug(
        'Dropped scene event cue "$name": not valid for scene ${scene.name}',
        tag: 'CueParser',
      );
      return null;
    }
    return AvatarCue.sceneEvent(event);
  }

  /// One-shot convenience: removes every cue from a complete text.
  static String stripCues(String text) {
    final CueParser parser = CueParser();
    final ParsedChunk result = parser.parse(text);
    return '${result.text}${parser.flush()}';
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final T element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
