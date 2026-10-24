# Pipeline Optimizations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement every recommendation from the 2026-10-24 pipeline audit (text input → LLM streaming → TTS → animated avatar): fix the ChatTtsCubit memory leak, de-quadratic the JSON stream extractor, remove the dead double-emit, narrow the talking rebuild scope, cut request-token cost (aligned history cap, slim payloads), actually send attached images to the LLM, and move TTS audio to the cache dir with delete-on-play.

**Architecture:** Ten independent tasks ordered by risk (memory/state first, hot-loop CPU second, UI rebuild scope third, request-payload changes last). Stored chat data is never migrated — payload changes happen at request-build time only, so old chats keep working and the byte-stable prompt prefix survives (one-time cache invalidation on app update, stable again afterwards).

**Tech Stack:** Flutter/Dart >=3.8, flutter_bloc 9, freezed 3 (+ build_runner), mocktail 1.0.4, bloc_test 10, path_provider, audioplayers, rive.

**Spec:** Pipeline audit delivered in this session (findings §1–§6). This plan is the spec's implementation; the audit's file:line references are reproduced in each task.

## Global Constraints

- Working tree on branch `v4-plan-b-app` has unrelated uncommitted Rive work. Before Task 1: `git stash push -m "rive wip"` (or commit it), then `git checkout -b pipeline-optimizations`.
- Every task ends green: `dart fix --apply && dart format . && ./scripts/fverify.sh` (format check + `flutter analyze` + `flutter test`) must pass before its commit.
- Explicit types everywhere (`always_specify_types: true`) — no `var`, no inference in new code.
- Relative imports inside `lib/`; tests use `package:yofardev_ai/...` imports (existing convention).
- Never hand-edit `*.g.dart` / `*.freezed.dart` — run `dart run build_runner build --delete-conflicting-outputs` after touching freezed-annotated files (Tasks 4).
- `test/architecture_test.dart` enforces layering: cross-feature imports via barrels only, `getIt` only in composition roots, `domain/` never imports `data/`/`presentation/`. Keep new code inside these rules.
- No new user-facing strings (nothing here needs `AppLocalizations`).
- Test runner: plain `flutter test <path>` per task; mocks via mocktail; register fallback values with `registerFallbackValue` when stubbing `any()`.
- macOS note: Impeller is disabled in `macos/Runner/Info.plist` (Rive crashes Impeller) — do not touch.
- `dart:io` imports are acceptable in service/bloc code even though the app builds for web (precedent: `tts_datasource.dart:2`); guard runtime use with `kIsWeb` where file IO would throw.

---

### Task 1: Free played TTS sentences from ChatTtsCubit state (memory leak)

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (in `_playAndExtractAmplitudes` after the `stop()` await, ~line 200; in `_subscribeToInterruptions`, ~line 93)
- Test: `test/features/chat/bloc/chat_tts_cubit_test.dart` (extend)

**Interfaces:**
- Consumes: existing `removeWaitingSentence(String audioPath)` and `clearAudioPaths()` methods on `ChatTtsCubit` (already defined, never called).
- Produces: no API change. Later tasks rely on the fact that `audioPathsWaitingSentences` stays near-empty.

**Context:** `ChatTtsCubit` appends `{audioPath, amplitudes}` to state per sentence (`chat_tts_cubit.dart:165-171`) and nothing ever removes it — unbounded growth for the app session.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/chat/bloc/chat_tts_cubit_test.dart` (reuse the mock classes already defined at the top of that file: `MockTtsQueueService`, `MockAudioAmplitudeService`, `MockAudioPlayerService`, `MockTtsPlaybackService`; add `MockInterruptionService` below if the file does not already define one):

```dart
class MockInterruptionService extends Mock implements InterruptionService {}
```

Inside `main()`, add:

```dart
test('removes the played sentence from audioPathsWaitingSentences',
    () async {
  final MockTtsQueueService queue = MockTtsQueueService();
  final MockAudioAmplitudeService amplitudeService =
      MockAudioAmplitudeService();
  final MockAudioPlayerService player = MockAudioPlayerService();
  final MockTtsPlaybackService playback = MockTtsPlaybackService();
  final MockInterruptionService interruption = MockInterruptionService();

  when(() => amplitudeService.extractAmplitudes(any()))
      .thenAnswer((Invocation _) async => <int>[10, 20, 30]);
  when(() => player.play(any()))
      .thenAnswer((Invocation _) async => const Duration(seconds: 1));
  when(() => queue.consumeCues(any()))
      .thenReturn(const <AvatarCue>[]);
  when(() => playback.stop()).thenAnswer((Invocation _) async {});

  final ChatTtsCubit cubit = ChatTtsCubit(
    ttsQueueManager: queue,
    audioAmplitudeService: amplitudeService,
    audioPlayerService: player,
    interruptionService: interruption,
    ttsPlaybackService: playback,
  );

  queue.emitAudioPath('/tmp/tts/1.wav');
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(cubit.state.audioPathsWaitingSentences.length, 1);

  player.emitPlaybackComplete();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(cubit.state.audioPathsWaitingSentences, isEmpty);

  await cubit.close();
});

test('clears waiting sentences on interruption', () async {
  final MockTtsQueueService queue = MockTtsQueueService();
  final MockAudioAmplitudeService amplitudeService =
      MockAudioAmplitudeService();
  final MockAudioPlayerService player = MockAudioPlayerService();
  final MockTtsPlaybackService playback = MockTtsPlaybackService();
  final StreamController<void> interruptions =
      StreamController<void>.broadcast();
  final MockInterruptionService interruption = MockInterruptionService();
  when(() => interruption.interruptionStream).thenAnswer(
      (Invocation _) => interruptions.stream);
  when(() => player.stop()).thenAnswer((Invocation _) async {});
  when(() => playback.stop()).thenAnswer((Invocation _) async {});

  final ChatTtsCubit cubit = ChatTtsCubit(
    ttsQueueManager: queue,
    audioAmplitudeService: amplitudeService,
    audioPlayerService: player,
    interruptionService: interruption,
    ttsPlaybackService: playback,
  );

  // Seed one state entry directly through the playback path.
  when(() => amplitudeService.extractAmplitudes(any()))
      .thenAnswer((Invocation _) async => <int>[5]);
  when(() => player.play(any()))
      .thenAnswer((Invocation _) async => const Duration(seconds: 1));
  when(() => queue.consumeCues(any()))
      .thenReturn(const <AvatarCue>[]);
  queue.emitAudioPath('/tmp/tts/2.wav');
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(cubit.state.audioPathsWaitingSentences.length, 1);

  interruptions.add(null);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  expect(cubit.state.audioPathsWaitingSentences, isEmpty);

  await cubit.close();
});
```

If `when(() => ...).thenReturn` on `consumeCues` needs a fallback (non-nullable return), it does not — it returns a value, not uses `any()` on a nullable. If mocktail complains about `any()` for `Invocation` types, add `registerFallbackValue(<String>['']);`-style fallbacks as the file already does.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart`
Expected: both new tests FAIL — first asserts `isEmpty` but the entry stays (`length` stays 1); second same.

- [ ] **Step 3: Implement**

In `lib/features/chat/presentation/bloc/chat_tts_cubit.dart`:

3a. In `_playAndExtractAmplitudes`, after the block

```dart
      _amplitudeFutures.remove(audioPath);
      await _ttsPlaybackService
          .stop(); // Return to idle state (also cancels animation)
      if (identical(_currentPlaybackStopSignal, stopSignal)) {
        _currentPlaybackStopSignal = null;
      }
```

add:

```dart
      // The sentence is done: drop its entry so state does not grow for the
      // whole app session (audioPathsWaitingSentences is otherwise never
      // freed).
      removeWaitingSentence(audioPath);
```

3b. In `_subscribeToInterruptions`, after `_pendingPlaybackQueue.clear();` add:

```dart
      clearAudioPaths();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart`
Expected: PASS (all, including pre-existing tests).

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/features/chat/presentation/bloc/chat_tts_cubit.dart test/features/chat/bloc/chat_tts_cubit_test.dart
git commit -m "fix(tts): free played-sentence state in ChatTtsCubit (session-long leak)"
```

---

### Task 2: Per-stream extractor/splitter state in StreamProcessorService

**Files:**
- Modify: `lib/core/services/stream_processor/stream_processor_service.dart`
- Test: `test/core/services/stream_processor/stream_processor_service_test.dart` (extend)

**Interfaces:**
- Consumes: nothing new.
- Produces: unchanged public API (`processStream`). Task 3 changes the class `JsonStreamExtractor` used here; this task only changes ownership/lifetime.

**Context:** `StreamProcessorService` is a registered singleton (`service_locator.dart:182-184`) but holds mutable buffers (`_jsonExtractor`, `_sentenceSplitter`) shared across every stream. Overlapping `streamResponse` calls would interleave sentence buffers. Fix at the source: make each `processStream` call use fresh instances (cheaper and safer than changing DI registration).

- [ ] **Step 1: Write the failing test**

Append to `test/core/services/stream_processor/stream_processor_service_test.dart`:

```dart
test('state does not leak between consecutive streams', () async {
  final Stream<LlmStreamChunk> first =
      Stream<LlmStreamChunk>.fromIterable(<LlmStreamChunk>[
    const LlmStreamChunk.text(
      content: 'First incomplete sent',
      isComplete: true,
    ),
  ]);
  final List<SentenceChunk> firstResults = await processor
      .processStream(first, expectJson: false)
      .toList();

  final Stream<LlmStreamChunk> second =
      Stream<LlmStreamChunk>.fromIterable(<LlmStreamChunk>[
    const LlmStreamChunk.text(content: 'Second.', isComplete: true),
  ]);
  final List<SentenceChunk> secondResults = await processor
      .processStream(second, expectJson: false)
      .toList();

  String firstSentenceText(SentenceChunk chunk) => chunk.when(
        sentence: (String text, int _) => text,
        metadata: (Map<String, dynamic> _) => '',
        complete: () => '',
        error: (String _) => '',
      );

  expect(
    secondResults.map(firstSentenceText).where((String t) => t.isNotEmpty),
    <String>['Second.'],
  );
  expect(
    firstResults.map(firstSentenceText).where((String t) => t.isNotEmpty),
    <String>['First incomplete sent'],
  );
});
```

This fails before the fix only if state leaks — with the current shared splitter the second stream's buffer is empty at start, so **also assert ordering**: run the second stream immediately after the first *without* the first having flushed (drop `isComplete: true` from the first stream's chunk and don't drain it — instead use two concurrent streams):

Replace the test above with this stricter version:

```dart
test('concurrent streams do not share sentence buffers', () async {
  final StreamController<LlmStreamChunk> controllerA =
      StreamController<LlmStreamChunk>();
  final StreamController<LlmStreamChunk> controllerB =
      StreamController<LlmStreamChunk>();

  final Stream<SentenceChunk> streamA =
      processor.processStream(controllerA.stream, expectJson: false);
  final Stream<SentenceChunk> streamB =
      processor.processStream(controllerB.stream, expectJson: false);

  final List<String> sentencesA = <String>[];
  final List<String> sentencesB = <String>[];
  final StreamSubscription<SentenceChunk> subA = streamA.listen(
      (SentenceChunk c) => c.when(
          sentence: (String t, int _) => sentencesA.add(t),
          metadata: (_) {},
          complete: () {},
          error: (_) {}));
  final StreamSubscription<SentenceChunk> subB = streamB.listen(
      (SentenceChunk c) => c.when(
          sentence: (String t, int _) => sentencesB.add(t),
          metadata: (_) {},
          complete: () {},
          error: (_) {}));

  controllerA.add(const LlmStreamChunk.text(content: 'From A. ', isComplete: false));
  controllerB.add(const LlmStreamChunk.text(content: 'From B. ', isComplete: false));
  await Future<void>.delayed(Duration.zero);
  await controllerA.close();
  await controllerB.close();
  await Future<void>.delayed(Duration.zero);
  await subA.cancel();
  await subB.cancel();

  expect(sentencesA, <String>['From A.']);
  expect(sentencesB, <String>['From B.']);
});
```

(Add `import 'dart:async';` at the top of the test file if absent.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/stream_processor/stream_processor_service_test.dart`
Expected: FAIL — the shared `_sentenceSplitter` merges the two streams' text (`From A. From B.` ends up in whichever stream flushes last, so one of the two lists is wrong).

- [ ] **Step 3: Implement**

In `lib/core/services/stream_processor/stream_processor_service.dart`: delete the two fields

```dart
  final JsonStreamExtractor _jsonExtractor = JsonStreamExtractor();
  final SentenceSplitter _sentenceSplitter = SentenceSplitter();
```

and inside `processStream`, create per-call locals before the `await for`:

```dart
    // Fresh per call: the service is a singleton but its extractors are
    // stateful, so two overlapping streams must never share buffers.
    final JsonStreamExtractor jsonExtractor = JsonStreamExtractor();
    final SentenceSplitter sentenceSplitter = SentenceSplitter();
```

Replace every `_jsonExtractor.` with `jsonExtractor.` and every `_sentenceSplitter.` with `sentenceSplitter.` inside the method, and delete the trailing state-reset block after the loop:

```dart
    // Reset state for next stream
    _jsonExtractor.clear();
    _sentenceSplitter.clear();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/stream_processor/`
Expected: PASS (sentence_splitter + stream_processor tests).

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/services/stream_processor/stream_processor_service.dart test/core/services/stream_processor/stream_processor_service_test.dart
git commit -m "refactor(stream): per-stream extractor state in StreamProcessorService"
```

---

### Task 3: Incremental JsonStreamExtractor (kill the O(n²) per-chunk work)

**Files:**
- Modify: `lib/core/services/stream_processor/json_stream_extractor.dart` (rewrite internals; keep the public API)
- Create: `test/core/services/stream_processor/json_stream_extractor_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: unchanged public API used by `StreamProcessorService` and indirectly `CueParser` (which only shares the key list): `String? extractText(String chunk, {bool expectJson = true})`, `String? getLastFullJson()`, `String getRawContent()`, `void clear()`, `void clearJson()`, `String getBufferedContent()`, `bool get hasBufferedContent`.

**Context:** Today every chunk (a) copies the whole buffer (`:29`), (b) attempts a full `json.decode` of an incomplete document (`:44-55`), (c) copies the whole raw buffer and re-parses the text field from its opening quote (`:36`, `:95-159`) — quadratic in reply length, on the UI isolate, mid-stream. The rewrite scans only the new chunk (plus a tiny carry), tracks JSON depth/string state incrementally, and attempts one `json.decode` per top-level object close.

Behavior contract to preserve (verified by new tests):
- Streams deltas of the text field as it arrives (partial field wins while incomplete).
- At top-level object close, the decoded object's text (first non-empty of `text`, `content`, `message`, `response`) wins; if it differs from what was already emitted, the full value is emitted once (the `_emitDelta` fallback).
- Escapes (`\n`, `\"`, `\\`, `\uXXXX`) split across chunk boundaries decode exactly once.
- `getRawContent()` returns everything received; `getLastFullJson()` returns the last complete JSON object substring.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/stream_processor/json_stream_extractor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/stream_processor/json_stream_extractor.dart';

void main() {
  group('JsonStreamExtractor (incremental)', () {
    test('streams text deltas across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "Hel'), 'Hel');
      expect(extractor.extractText('lo wor'), 'lo wor');
      expect(extractor.extractText('ld. Done!"}'), 'ld. Done!"');
      // Complete JSON re-emits the decoded value minus what was already
      // emitted: nothing new, so no delta.
      expect(extractor.extractText(''), isNull);
    });

    test('decodes simple escapes split across chunks exactly once', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "a\\'), isNull); // lone backslash held
      expect(extractor.extractText('nb'), '\nb');
      expect(extractor.extractText('c"}'), 'c');
    });

    test('decodes \\uXXXX escapes split across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "\\u00'), isNull);
      expect(extractor.extractText('41\\u0042"}'), 'AB');
    });

    test('finds the text key when split across chunks', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"te'), isNull);
      expect(extractor.extractText('xt": "Hi"}'), 'Hi');
    });

    test('keeps escaped quotes inside the value', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"text": "He said \\"hi\\"'), 'He said "hi"');
      expect(extractor.extractText('!"}'), '!');
    });

    test('nested objects: outer text wins at close', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      expect(extractor.extractText('{"meta": {"text": "inner"}, "te'), 'inner');
      expect(extractor.extractText('xt": "outer"}'), 'outer');
      expect(extractor.getLastFullJson(), '{"meta": {"text": "inner"}, "text": "outer"}');
    });

    test('exposes raw content and resets', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      extractor.extractText('{"text": "abc"}');
      expect(extractor.getRawContent(), '{"text": "abc"}');
      extractor.clear();
      expect(extractor.getRawContent(), '');
      expect(extractor.extractText('{"text": "ne'), 'ne');
    });

    test('large reply stays linear: 2k chars in 40 chunks all extracted', () {
      final JsonStreamExtractor extractor = JsonStreamExtractor();
      final StringBuffer expected = StringBuffer();
      expect(extractor.extractText('{"text": "'), isNull);
      for (int i = 0; i < 40; i++) {
        final String piece = 'chunk$i '.padRight(50, 'x');
        expected.write(piece);
        expect(extractor.extractText(piece), piece);
      }
      expect(
        extractor.extractText('"}'),
        isNot(contains('chunk')),
      );
    });
  });
}
```

Run: `flutter test test/core/services/stream_processor/json_stream_extractor_test.dart`
Expected: most tests FAIL against the current implementation (the current one emits `ld. Done!"` for the close chunk? no — it re-extracts and emits only the delta, so several of these pass today; the ones that must fail before the rewrite: `decodes simple escapes split across chunks exactly once` — current code holds the `\` differently and emits `'a\'`…` — verify at least 3 tests fail; if a test passes today, keep it (regression guard) — the rewrite must keep them green).

- [ ] **Step 2: Verify failure mode**

Run: `flutter test test/core/services/stream_processor/json_stream_extractor_test.dart`
Expected: FAIL on the escape-split and/or nested tests. Record which failed; after the rewrite all must PASS.

- [ ] **Step 3: Rewrite the extractor**

Replace the class body of `lib/core/services/stream_processor/json_stream_extractor.dart` (keep the class name, doc it, keep `_textKeys` order) with:

```dart
class JsonStreamExtractor {
  static const List<String> _textKeys = <String>[
    'text',
    'content',
    'message',
    'response',
  ];

  /// Raw stream content, appended once per chunk (read once at stream end).
  final StringBuffer _rawBuffer = StringBuffer();

  /// Window not yet consumed: a chunk tail that may grow into a key, an
  /// escape, or the field opening. Bounded by the longest key + quotes.
  String _carry = '';

  /// Structure state, advanced once per character.
  int _depth = 0;
  bool _inString = false;
  bool _escaped = false;
  bool _sawOpenBrace = false;

  /// Text-field capture state (set when the opening quote of the value is
  /// found; capture ends at its unescaped closing quote).
  bool _capturing = false;
  bool _captureDone = false;
  final StringBuffer _captured = StringBuffer();

  String? _lastFullJson;
  String _lastExtractedText = '';

  /// Process a chunk and return the newly extracted text delta, if any.
  String? extractText(String chunk, {bool expectJson = true}) {
    _rawBuffer.write(chunk);
    if (!expectJson) {
      // Non-JSON streams pass the chunk through untouched (as before —
      // do NOT route through _emitDelta, whose dedupe state must stay
      // reserved for the JSON path).
      return chunk;
    }

    final String window = '$_carry$chunk';
    _carry = '';
    String? delta;

    int i = 0;
    while (i < window.length) {
      if (!_capturing && !_captureDone) {
        // Looking for the value opening of the first text key.
        final int valueQuote = _findValueQuote(window, i);
        if (valueQuote < 0) {
          i = window.length; // carry handled below
          break;
        }
        _capturing = true;
        i = valueQuote + 1;
        continue;
      }

      final String char = window[i];
      if (_capturing) {
        if (_escaped) {
          _captured.write(_decodeEscape(char, window, i));
          _escaped = false;
          i += _escapeLength(char);
          continue;
        }
        if (char == r'\\') {
          _escaped = true;
          i++;
          continue;
        }
        if (char == '"') {
          _capturing = false;
          _captureDone = true;
          delta = _mergeDelta(delta, _emitDelta(_captured.toString()));
          i++;
          continue;
        }
        _captured.write(char);
        i++;
        continue;
      }

      // _captureDone: track structure only, to spot the top-level close.
      _advanceStructure(char);
      i++;
    }

    // Hold back a tail that may still grow into a key/escape/opening.
    _carry = _carryTail(window);

    return delta;
  }

  /// Finds the opening quote of the value for the first of [_textKeys]
  /// appearing at or after [from] in [window]. Returns -1 (and stashes the
  /// possible partial match into [_carry]) when none is complete yet.
  int _findValueQuote(String window, int from) {
    int best = -1;
    for (final String key in _textKeys) {
      final int keyIndex = window.indexOf('"$key"', from);
      if (keyIndex < 0) {
        continue;
      }
      final int colonIndex = window.indexOf(':', keyIndex + key.length + 2);
      if (colonIndex < 0) {
        continue;
      }
      int cursor = colonIndex + 1;
      while (cursor < window.length &&
          (window[cursor] == ' ' ||
              window[cursor] == '\n' ||
              window[cursor] == '\r' ||
              window[cursor] == '\t')) {
        cursor++;
      }
      if (cursor >= window.length) {
        continue; // opening quote not arrived yet
      }
      if (window[cursor] != '"') {
        continue; // not a string field
      }
      if (best < 0 || keyIndex < best) {
        best = cursor;
      }
    }
    return best;
  }

  /// Carries the smallest tail that could still grow into a match: from the
  /// last quote, or the last backslash while capturing, else nothing.
  String _carryTail(String window) {
    if (_capturing && window.endsWith(r'\')) {
      return r'\';
    }
    final int lastQuote = window.lastIndexOf('"');
    if (lastQuote >= 0) {
      return window.substring(lastQuote);
    }
    return '';
  }

  void _advanceStructure(String char) {
    if (_inString) {
      if (_escaped) {
        _escaped = false;
      } else if (char == r'\\') {
        _escaped = true;
      } else if (char == '"') {
        _inString = false;
      }
      return;
    }
    switch (char) {
      case '"':
        _inString = true;
      case '{':
        _depth++;
        _sawOpenBrace = true;
      case '}':
        _depth--;
        if (_sawOpenBrace && _depth <= 0) {
          _onTopLevelClose();
          _depth = 0;
          _sawOpenBrace = false;
        }
    }
  }

  /// One json.decode attempt per completed top-level object (was: per chunk).
  void _onTopLevelClose() {
    final String raw = _rawBuffer.toString();
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return;
    }
    final String jsonStr = raw.substring(start, end + 1);
    try {
      final Map<String, dynamic> decoded =
          json.decode(jsonStr) as Map<String, dynamic>;
      _lastFullJson = jsonStr;
      for (final String key in _textKeys) {
        final dynamic value = decoded[key];
        if (value is String && value.isNotEmpty) {
          // Complete JSON wins; if it differs from the streamed prefix, the
          // _emitDelta fallback re-emits the full value once.
          _emitDelta(value);
          return;
        }
      }
    } on FormatException {
      AppLogger.debug(
        'Top-level close without valid JSON; continuing to buffer',
        tag: 'JsonStreamExtractor',
      );
    } catch (e) {
      AppLogger.warning(
        'Error extracting JSON at top-level close: $e',
        tag: 'JsonStreamExtractor',
      );
    }
  }

  /// Decodes one escape whose leading backslash was already consumed.
  /// `u` escapes read 4 hex digits starting at [i] (the char after `u`).
  String _decodeEscape(String char, String window, int i) {
    if (char != 'u') {
      return _decodeSimpleEscape(char);
    }
    if (i + 4 >= window.length) {
      // Hex digits not fully arrived: hold by returning nothing; the digits
      // are re-read once complete thanks to _carryTail re-injection.
      return '';
    }
    final String hex = window.substring(i + 1, i + 5);
    final int? codePoint = int.tryParse(hex, radix: 16);
    return codePoint == null ? '' : String.fromCharCode(codePoint);
  }

  int _escapeLength(String char) {
    return char == 'u' ? 5 : 1;
  }

  String _decodeSimpleEscape(String escaped) {
    return switch (escaped) {
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      'b' => '\b',
      'f' => '\f',
      '"' => '"',
      '\\' => '\\',
      '/' => '/',
      _ => escaped,
    };
  }

  String? _mergeDelta(String? accumulated, String? latest) {
    if (latest == null) {
      return accumulated;
    }
    return accumulated == null ? latest : '$accumulated$latest';
  }

  String? _emitDelta(String candidateText) {
    if (candidateText.isEmpty) {
      return null;
    }
    if (candidateText == _lastExtractedText) {
      return null;
    }
    if (candidateText.startsWith(_lastExtractedText)) {
      final String delta = candidateText.substring(_lastExtractedText.length);
      _lastExtractedText = candidateText;
      return delta.isEmpty ? null : delta;
    }
    // Fallback when extraction context shifts: emit full candidate once.
    _lastExtractedText = candidateText;
    return candidateText;
  }

  /// Get the last complete full JSON that was extracted.
  String? getLastFullJson() => _lastFullJson;

  /// Get the full raw content received so far.
  String getRawContent() => _rawBuffer.toString();

  /// Clear the stored JSON.
  void clearJson() {
    _lastFullJson = null;
  }

  /// Get any remaining buffered content (for cleanup).
  String getBufferedContent() => _rawBuffer.toString();

  /// Clear the buffer.
  void clear() {
    _rawBuffer.clear();
    _carry = '';
    _depth = 0;
    _inString = false;
    _escaped = false;
    _sawOpenBrace = false;
    _capturing = false;
    _captureDone = false;
    _captured.clear();
    _lastExtractedText = '';
  }

  /// Whether buffer contains content that might be partial JSON.
  bool get hasBufferedContent => _rawBuffer.isNotEmpty;
}
```

**Implementation notes for the implementer (read before coding):**
- The `\uXXXX`-split case works because when the hex digits have not fully arrived, `_decodeEscape` returns `''` and consumes 5 chars — WRONG for the split case. Handle it explicitly instead: when `i + 4 >= window.length` while capturing a `u` escape, stop scanning (`break`), set `_carry` to the un-consumed tail starting at the backslash (i.e. `window.substring(backslashIndex)`), and return. Adjust `extractText` so the escape branch can break out of the loop with the carry set. The tests `decodes \uXXXX escapes split across chunks` and `decodes simple escapes split across chunks exactly once` are the acceptance criteria for this behavior — iterate until green.
- Keep `import 'dart:convert';` (for `json.decode`) and the `AppLogger` import.
- The structure tracker only runs after `_captureDone` in this design; that is sufficient because the value's own closing quote is what ends capture, and `_onTopLevelClose` triggers the single decode. If a test reveals the close is missed (e.g. value contains a `}` — impossible inside a JSON string before the closing quote), adjust `_advanceStructure` to also run during capture for non-captured characters.

- [ ] **Step 4: Run extractor + processor tests**

Run: `flutter test test/core/services/stream_processor/`
Expected: ALL PASS (new file + existing `stream_processor_service_test.dart` + `sentence_splitter_test.dart`). The existing `should handle JSON streaming` test is the key regression guard.

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/services/stream_processor/json_stream_extractor.dart test/core/services/stream_processor/json_stream_extractor_test.dart
git commit -m "perf(stream): incremental JsonStreamExtractor — per-chunk scan instead of O(n^2) re-parse"
```

---

### Task 4: Remove dead streaming state (single emit per sentence)

**Files:**
- Modify: `lib/features/chat/presentation/bloc/chat_state.dart` (drop `streamingContent`, `streamingSentenceCount`)
- Modify: `lib/features/chat/presentation/bloc/chat_cubit.dart` (`streamResponse`, `clearStreamingContent`, `onStreamingUpdate` callback wiring)
- Modify: `lib/features/chat/domain/services/chat_streaming_service.dart` (drop the `onStreamingUpdate` parameter and its call; `deliverSentence` no longer counts sentences)
- Regenerate: `chat_state.freezed.dart` via build_runner

**Interfaces:**
- Consumes: nothing.
- Produces: `ChatStreamingService.streamResponse` loses its `onStreamingUpdate` parameter (breaking change internal to the app — exactly two call sites: `chat_cubit.dart` and `global_memory_injection_test.dart`). `ChatState` loses two fields (no consumers exist — verified: zero references outside `chat_cubit.dart` and the freezed output, in both `lib/` and `test/`).

**Context:** Per streamed sentence the pipeline emits twice (`chat_streaming_service.dart:253-255` → `updateChatStreaming` + `onStreamingUpdate`), each a full home-stack rebuild via `BlocBuilder<ChatCubit>`. `streamingContent`/`streamingSentenceCount` have no readers anywhere — the entries already carry the streaming text.

- [ ] **Step 1: Capture the current behavior (regression net)**

Run: `flutter test test/features/chat/ test/features/screens/`
Expected: PASS. (These suites cover chat streaming behavior; they must stay green after the removal.)

- [ ] **Step 2: Remove the fields and the callback**

2a. `lib/features/chat/presentation/bloc/chat_state.dart`: delete the `streamingContent` and `streamingSentenceCount` fields from the factory, and the `streamingContent: ''` argument at line ~58's `copyWith`-style reset (keep the rest of that method intact).

2b. `lib/features/chat/presentation/bloc/chat_cubit.dart`:
- Delete the `clearStreamingContent` method.
- In `streamResponse`, delete the first line `emit(state.copyWith(streamingContent: '', streamingSentenceCount: 0));`.
- Delete the whole `onStreamingUpdate: (String content, int sentenceCount) {...}` callback argument from the `_chatStreamingService.streamResponse(...)` call (the `onChatUpdated`, `onStreamComplete`, `onError` callbacks stay).

2c. `lib/features/chat/domain/services/chat_streaming_service.dart`:
- Delete `required void Function(String content, int sentenceCount) onStreamingUpdate,` from the parameter list.
- In `deliverSentence`, delete `sentenceCount++;` and the `onStreamingUpdate(contentBuffer.toString(), sentenceCount);` line.
- Delete the now-unused `int sentenceCount = 0;` declaration (keep the log at `complete:` — replace `$sentenceCount sentences` with `_`/remove the counter from the message; simplest: log `'Stream complete'`).
- Remove the now-unused `sentenceCount` references in the `metadata`/`complete` handlers if any.

2d. Update the one test call site: `test/features/chat/global_memory_injection_test.dart` passes `onStreamingUpdate: ...` — delete that argument (and its import fallout).

- [ ] **Step 3: Regenerate freezed + run tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/chat/ test/features/screens/
```
Expected: PASS. If any test still references the removed fields, delete those references (they are asserting dead state).

- [ ] **Step 4: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add -A lib/features/chat test/features/chat
git commit -m "refactor(chat): drop dead streamingContent state — one emit per sentence"
```

---

### Task 5: Narrow the TalkingCubit rebuild scope + memoize getMessage

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart:130-145` (remove the `BlocBuilder<TalkingCubit>` wrapper)
- Modify: `lib/features/home/widgets/home_content_stack.dart` (drop the `talkingState` prop; wrap only `RiveAvatarView` in its own `BlocBuilder<TalkingCubit, TalkingState>`)
- Modify: `lib/core/models/chat_entry.dart` (Expando memo for `getMessage`)
- Create: `test/features/home/home_content_stack_rebuild_test.dart`

**Interfaces:**
- Consumes: `TalkingCubit` provided at app root (`app.dart:30`) — context lookups below it work unchanged.
- Produces: `HomeContentStack` constructor loses its `talkingState` parameter (call site: `home_screen.dart` only). `ChatEntry.getMessage()` behavior unchanged, now memoized per instance.

**Context:** `home_screen.dart:132-141` wraps the whole `HomeContentStack` in `BlocBuilder<TalkingCubit>`, so every mouth-level change (several per second while speaking) rebuilds the scene view, scene light, text input, stop button and home buttons — only `RiveAvatarView` consumes `talkingState`. `AiTextInput` and `FloatingStopButton` already have their own `BlocListener`/`BlocBuilder` on `TalkingCubit` (`ai_text_input.dart:116,126`, `floating_stop_button.dart:28`), so the top-level builder exists only to feed the avatar.

- [ ] **Step 1: Write the failing rebuild-scope test**

Create `test/features/home/home_content_stack_rebuild_test.dart`. The test pumps the real `HomeScreen`, because the defect lives in `HomeScreen`'s top-level `BlocBuilder<TalkingCubit>`. The subtree needs five cubits plus `InterruptionService` (verified: `home_buttons.dart:18,26`, `floating_stop_button.dart:48`, `ai_text_input.dart:99,114`, plus `HomeScreen`'s own `BlocListener<DemoCubit>`). Take the mock wiring from the named existing files:

- `ChatCubit` — `test/features/chat/chats_cubit_test.dart`
- `AvatarCubit`, `TalkingCubit` (real instance, cheap deps) — `test/features/avatar/avatar_cubit_test.dart`
- `SettingsCubit` — `test/features/settings/bloc/settings_cubit_test.dart`
- `DemoCubit` — `test/features/demo/demo_cubit_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/home/screens/home_screen.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

void main() {
  testWidgets('mouth-state changes do not rebuild the text input', (
    WidgetTester tester,
  ) async {
    // Real TalkingCubit: its deps are all cheap, real constructibles.
    final TalkingCubit talkingCubit = TalkingCubit(
      TalkingRepositoryImpl(),
      InterruptionService(),
      TtsPlaybackService(TalkingRepositoryImpl()),
      AppLifecycleService(),
    );
    addTearDown(() => talkingCubit.close());

    // Mock-wired cubits per the four harness files named above. Construct
    // them exactly as those files' setUp blocks do.
    final ChatCubit chatCubit = buildMockedChatCubit(); // from chats_cubit_test
    final AvatarCubit avatarCubit = buildMockedAvatarCubit(); // from avatar_cubit_test
    final SettingsCubit settingsCubit = buildMockedSettingsCubit(); // from settings_cubit_test
    final DemoCubit demoCubit = buildMockedDemoCubit(); // from demo_cubit_test

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<Object>>[
          BlocProvider<ChatCubit>.value(value: chatCubit),
          BlocProvider<TalkingCubit>.value(value: talkingCubit),
          BlocProvider<AvatarCubit>.value(value: avatarCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<DemoCubit>.value(value: demoCubit),
        ],
        child: Provider<InterruptionService>.value(
          value: InterruptionService(),
          child: const MaterialApp(home: HomeScreen()),
        ),
      ),
    );

    final List<String> rebuildLogs = <String>[];
    final void Function(String? message, {int? wrapWidth}) originalDebugPrint =
        debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        rebuildLogs.add(message);
      }
    };
    debugPrintRebuildDirtyWidgets = true;

    talkingCubit.emit(const TalkingState.speaking());
    await tester.pump();

    debugPrintRebuildDirtyWidgets = false;
    debugPrint = originalDebugPrint;

    expect(
      rebuildLogs.any((String l) => l.contains('AiTextInput')),
      isFalse,
      reason:
          'mouth-only TalkingState changes must not rebuild the text input',
    );
  });
}
```

The four `buildMocked*Cubit()` helpers are private functions you add to this test file, each copying the mock constructor wiring from its named harness file verbatim (mock repositories via mocktail, same stubs for `init()`/lifecycle calls those files already perform). If `HomeScreen`'s construction requires additional providers beyond the five listed (the test failure will name any missing one), add it the same way.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/home_content_stack_rebuild_test.dart`
Expected: FAIL — today `HomeScreen` wraps the whole `HomeContentStack` in `BlocBuilder<TalkingCubit>`, so the emit marks `AiTextInput` dirty and it appears in the rebuild logs.

- [ ] **Step 3: Implement the scope narrowing**

3a. `lib/features/home/widgets/home_content_stack.dart`:

```dart
class HomeContentStack extends StatelessWidget {
  const HomeContentStack({
    super.key,
    required this.chatsState,
    required this.onTripleTap,
  });

  final ChatState chatsState;
  final VoidCallback onTripleTap;
```

and replace the `AvatarSceneLight(...)` block with:

```dart
                  AvatarSceneLight(
                    scene: avatarState.scene,
                    sceneEvent: avatarState.sceneEvent,
                    // Narrow scope: only the avatar view depends on
                    // TalkingState (mouth + phase); a mouth change must not
                    // rebuild the input, buttons, or scene view.
                    child: BlocBuilder<TalkingCubit, TalkingState>(
                      builder: (BuildContext context, TalkingState talkingState) {
                        return RiveAvatarView(
                          avatarState: avatarState,
                          talkingState: talkingState,
                          onAvatarTapped: (String zone) {
                            context.read<AvatarCubit>().onAvatarTapped(zone);
                          },
                          onPresenceDone: (String presence) {
                            context.read<AvatarCubit>().onPresenceDone(presence);
                          },
                        );
                      },
                    ),
                  ),
```

Keep the `talking` import; delete the unused `talkingState` field.

3b. `lib/features/home/screens/home_screen.dart` — replace the double builder with:

```dart
        body: BlocBuilder<ChatCubit, ChatState>(
          builder: (BuildContext context, ChatState chatsState) {
            return HomeContentStack(
              chatsState: chatsState,
              onTripleTap: _handleTripleTap,
            );
          },
        ),
```

Remove the now-unused `talking` import if nothing else in the file uses it.

- [ ] **Step 4: Memoize getMessage (per-instance cache)**

In `lib/core/models/chat_entry.dart`, add a private top-level Expando and use it inside `getMessage`:

```dart
/// Memoizes [ChatEntryExtension.getMessage] per entry instance: bubbles call
/// it on every rebuild, and the JSON decode of the same immutable body is
/// pure waste. New instances (copyWith during streaming) simply miss.
final Expando<String> _messageCache = Expando<String>();
```

then at the top of `getMessage`:

```dart
  String getMessage({bool isFromUser = false}) {
    final String? cached = _messageCache[this];
    if (cached != null) {
      return cached;
    }
    // ... existing body, producing `result` ...
    _messageCache[this] = result;
    return result;
  }
```

Restructure the existing method so both return paths (`message` found and fallback) flow through the cache write; keep `isFromUser` behavior identical (cache is per instance; `isFromUser` varies per entry type only, so no key conflict — user entries always pass `true`, assistant `false`, from the widgets).

- [ ] **Step 5: Add the memo unit test + run everything**

Append to the new test file (or `test/core/models/` if a chat_entry test file exists there):

```dart
test('getMessage returns the identical cached instance', () {
  final ChatEntry entry = ChatEntry(
    id: 'id',
    entryType: EntryType.yofardev,
    body: '{"text": "hello"}',
    timestamp: DateTime(2026),
  );
  final String first = entry.getMessage();
  final String second = entry.getMessage();
  expect(identical(first, second), isTrue);
});
```

Run: `flutter test test/features/home/ test/features/screens/ test/core/models/`
Expected: PASS.

- [ ] **Step 6: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/features/home lib/core/models/chat_entry.dart test/features/home
git commit -m "perf(ui): narrow TalkingCubit rebuild scope to the avatar view; memoize getMessage"
```

---

### Task 6: Block-aligned history cap (prompt-cache friendly)

**Files:**
- Modify: `lib/core/models/chat.dart` (`llmMessages`, ~line 86-110)
- Create: `test/core/models/chat_llm_messages_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: unchanged `List<LlmMessage> get llmMessages` — Task 7 builds on this getter's file.

**Context:** `maxLlmMessages = 40` trims with a shifting `sublist` start: once a chat exceeds 40 messages the start moves 1-2 entries per turn, invalidating the provider prompt cache the memory-injection design works to preserve. Trimming in blocks of 8 keeps the start constant for several consecutive turns (8 is even, so the user/assistant alternation phase is also preserved).

- [ ] **Step 1: Write the failing test**

Create `test/core/models/chat_llm_messages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';

ChatEntry _entry(int i, {EntryType type = EntryType.user}) => ChatEntry(
      id: 'e$i',
      entryType: type,
      body: 'message $i',
      timestamp: DateTime(2026, 1, 1),
    );

Chat _chatWithEntries(int count) => Chat(
      id: 'c',
      entries: List<ChatEntry>.generate(
        count,
        (int i) => _entry(i, type: i.isEven ? EntryType.user : EntryType.yofardev),
      ),
    );

void main() {
  test('below the cap: all messages kept', () {
    expect(_chatWithEntries(10).llmMessages.length, 10);
  });

  test('just above the cap: start index snaps to the block boundary', () {
    // 41 messages: naive start would be 1; aligned start is 8 → 33 kept.
    expect(_chatWithEntries(41).llmMessages.length, 33);
    expect(_chatWithEntries(41).llmMessages.first.body, 'message 8');
  });

  test('cap boundary: 48 messages keep exactly 40', () {
    expect(_chatWithEntries(48).llmMessages.length, 40);
    expect(_chatWithEntries(48).llmMessages.first.body, 'message 8');
  });

  test('next block: 49 messages snap to start 16', () {
    expect(_chatWithEntries(49).llmMessages.length, 33);
    expect(_chatWithEntries(49).llmMessages.first.body, 'message 16');
  });

  test('start stays constant while the chat grows within a block', () {
    // Turn N has 41 entries, turn N+1 has 46: both trim to start 8, so the
    // provider prompt-cache prefix stays byte-identical.
    final List<String> at41 = _chatWithEntries(41).llmMessages
        .map((dynamic m) => m.body as String)
        .toList();
    final List<String> at46 = _chatWithEntries(46).llmMessages
        .map((dynamic m) => m.body as String)
        .toList();
    expect(at46.sublist(0, at41.length), at41);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/models/chat_llm_messages_test.dart`
Expected: FAIL — current code keeps 40 at length 41 (`first.body == 'message 1'`), not 33.

- [ ] **Step 3: Implement**

In `lib/core/models/chat.dart`, replace the `llmMessages` trimming block:

```dart
    if (messages.length > maxLlmMessages) {
      return messages.sublist(messages.length - maxLlmMessages);
    }
    return messages;
```

with:

```dart
    if (messages.length > maxLlmMessages) {
      // Trim in blocks so the kept-prefix start stays constant across
      // consecutive turns (a shifting start would invalidate provider
      // prompt caches every turn). Even block size keeps the
      // user/assistant role alternation stable too.
      const int trimBlockSize = 8;
      final int neededStart = messages.length - maxLlmMessages;
      final int alignedStart =
          ((neededStart + trimBlockSize - 1) ~/ trimBlockSize) *
              trimBlockSize;
      return messages.sublist(alignedStart);
    }
    return messages;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/models/chat_llm_messages_test.dart`
Expected: PASS.

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/models/chat.dart test/core/models/chat_llm_messages_test.dart
git commit -m "perf(llm): block-aligned history trim keeps the prompt-cache prefix stable"
```

---

### Task 7: Slim request payloads + avatar/date context injection

**Files:**
- Modify: `lib/core/models/chat.dart` (`llmMessages`: strip wrappers, clean assistant JSON, single-image rule)
- Modify: `lib/features/chat/domain/services/chat_streaming_service.dart` (inject a transient context message with the current avatar config + date at the existing memory-insertion point)
- Test: extend `test/features/chat/global_memory_injection_test.dart`

**Interfaces:**
- Consumes: `ChatEntryExtension.getMessage` (Task 5 memoized it), `StringExtensions.getVisiblePrompt` (`core/utils/extensions.dart`), the `avatar` + `language` parameters `streamResponse` already receives.
- Produces: request-time message shape only. Stored bodies are untouched — no migration, display unaffected.

**Context:** Today every request re-sends: (a) each user body's `Date : …\nAvatar Config :\n{…}\nUser : '''…'''` wrapper (~50+ tokens/message), (b) each assistant reply as raw JSON (escaping overhead), (c) every history image path (currently harmless only because Task 8 will make images actually send — so this task must land the single-image rule BEFORE Task 8). The per-turn avatar/date context moves to a transient system-role message injected at the same cache-tail position as the memory message.

- [ ] **Step 1: Write the failing tests**

Extend `test/features/chat/global_memory_injection_test.dart`. The file's harness already provides everything needed: `buildService(GlobalMemoryService)` constructs the `ChatStreamingService` with the mocked `llmService` whose `promptModelStream` stub captures messages into `capturedMessages`, and `FakeGlobalMemoryService(message)` fakes memory. Add these tests (note: Task 4 already removed the `onStreamingUpdate` parameter — do not pass it):

```dart
Chat slimPayloadChat() => Chat(
      id: 'chat-id',
      entries: <ChatEntry>[
        ChatEntry(
          id: 'u1',
          entryType: EntryType.user,
          body:
              "Date : vendredi 23 octobre 2026 - 14:30\nAvatar Config :\n{\n\"background\": \"beach\",\n}\nUser : \n'''hello'''",
          timestamp: DateTime(2026),
          attachedImage: '/tmp/old.png',
        ),
        ChatEntry(
          id: 'a1',
          entryType: EntryType.yofardev,
          body: '{"text": "hi there", "mood": "happy"}',
          timestamp: DateTime(2026),
        ),
        ChatEntry(
          id: 'u2',
          entryType: EntryType.user,
          body:
              "Date : vendredi 23 octobre 2026 - 14:31\nAvatar Config :\n{\n}\nUser : \n'''second question'''",
          timestamp: DateTime(2026),
          attachedImage: '/tmp/new.png',
        ),
        ChatEntry(
          id: 'a2',
          entryType: EntryType.yofardev,
          body: '',
          timestamp: DateTime(2026),
        ),
      ],
    );

test('request payloads are slimmed: wrapper stripped, JSON extracted, single image',
    () async {
  final ChatStreamingService service =
      buildService(FakeGlobalMemoryService(null));
  await service.streamResponse(
    prompt: 'second question',
    onlyText: true,
    avatar: const Avatar(),
    currentChat: slimPayloadChat(),
    language: 'en',
    functionCallingEnabled: false,
    onChatUpdated: (_) {},
    onStreamComplete: (_) {},
    onError: (_) {},
  );

  final List<LlmMessage> sent = capturedMessages;
  // User wrappers stripped:
  expect(sent.any((LlmMessage m) => m.body.contains("'''")), isFalse);
  expect(sent.any((LlmMessage m) => m.body.contains('Avatar Config')), isFalse);
  // Visible prompts only:
  expect(sent.any((LlmMessage m) => m.body == 'hello'), isTrue);
  expect(sent.any((LlmMessage m) => m.body == 'second question'), isTrue);
  // Assistant JSON extracted to clean text:
  expect(sent.any((LlmMessage m) => m.body == 'hi there'), isTrue);
  expect(sent.any((LlmMessage m) => m.body.contains('"mood"')), isFalse);
  // Only the LATEST entry keeps its image:
  expect(
    sent.where((LlmMessage m) => m.attachedFile != null).length,
    1,
  );
  expect(
    sent.firstWhere((LlmMessage m) => m.attachedFile != null).attachedFile,
    '/tmp/new.png',
  );
});

test('current avatar config and date ride a transient system message',
    () async {
  final ChatStreamingService service =
      buildService(FakeGlobalMemoryService(null));
  await service.streamResponse(
    prompt: 'second question',
    onlyText: true,
    avatar: const Avatar(),
    currentChat: slimPayloadChat(),
    language: 'en',
    functionCallingEnabled: false,
    onChatUpdated: (_) {},
    onStreamComplete: (_) {},
    onError: (_) {},
  );

  final LlmMessage contextMessage = capturedMessages.firstWhere(
    (LlmMessage m) =>
        m.role == LlmMessageRole.system && m.body.contains('Avatar Config'),
  );
  expect(contextMessage.body, contains('beach'));
  expect(contextMessage.body, contains('Date :'));
});
```

The `contextMessage` assertion checks the CURRENT avatar (`const Avatar()` default scene, e.g. `livingRoom`) — adjust `contains('beach')` to the default scene name if `Avatar()`'s default differs, or pass an explicit `Avatar(background: AvatarScene.beach)` to `streamResponse`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/chat/global_memory_injection_test.dart`
Expected: FAIL (wrappers/JSON present in payloads; no context message).

- [ ] **Step 3: Implement llmMessages slimming**

In `lib/core/models/chat.dart`, replace the getter body:

```dart
  List<LlmMessage> get llmMessages {
    final List<LlmMessage> messages = <LlmMessage>[];
    int lastImageIndex = -1;
    for (final ChatEntry entry in entries) {
      if (entry.entryType == EntryType.functionCalling) continue;
      final bool isUser = entry.entryType == EntryType.user;
      messages.add(
        LlmMessage(
          role: isUser ? LlmMessageRole.user : LlmMessageRole.assistant,
          // Requests carry the visible text only: user wrappers and
          // assistant JSON envelopes are re-sent-token waste. The current
          // avatar config + date ride a transient context message instead
          // (see ChatStreamingService).
          body: entry.getMessage(isFromUser: isUser),
          attachedFile: entry.attachedImage,
        ),
      );
      if (entry.attachedImage != null) {
        lastImageIndex = messages.length - 1;
      }
    }
    // Only the latest attached image is sent: re-sending every history
    // image each turn would dominate request cost once images actually
    // travel to the provider.
    for (int i = 0; i < messages.length; i++) {
      if (i != lastImageIndex && messages[i].attachedFile != null) {
        final LlmMessage m = messages[i];
        messages[i] = LlmMessage(role: m.role, body: m.body);
      }
    }
    if (messages.length > maxLlmMessages) {
      // ... block-aligned trim from Task 6 unchanged ...
    }
    return messages;
  }
```

(Import `EntryType` is already available via `chat_entry.dart`.)

- [ ] **Step 4: Implement the context message injection**

In `lib/features/chat/domain/services/chat_streaming_service.dart`, extend the memory-injection block (currently lines ~163-183). Replace it with:

```dart
      // Transient tail context, injected AFTER the history (right before the
      // current user message), never into the system prompt: the prefix
      // [system prompt | history] then stays byte-identical across turns so
      // provider-side prompt caches keep hitting. Global memory and the
      // per-turn avatar/date context (previously baked into every stored
      // user body) both ride here.
      final List<LlmMessage> tailContext = <LlmMessage>[];
      if (_globalMemoryService != null && messagesForStream.isNotEmpty) {
        final LlmMessage? memoryMessage = await _globalMemoryService
            .buildMemoryMessage();
        if (memoryMessage != null) {
          tailContext.add(memoryMessage);
        }
      }
      tailContext.add(
        LlmMessage(
          role: LlmMessageRole.system,
          body:
              'Date : ${DateTime.now().toLongLocalDateString(language: language)}\n'
              'Avatar Config :\n'
              '{\n$avatar\n}\n',
        ),
      );
      if (tailContext.isNotEmpty) {
        int insertIndex = messagesForStream.length - 1;
        for (int i = messagesForStream.length - 1; i >= 0; i--) {
          if (messagesForStream[i].role == LlmMessageRole.user) {
            insertIndex = i;
            break;
          }
        }
        messagesForStream = <LlmMessage>[
          ...messagesForStream.sublist(0, insertIndex),
          ...tailContext,
          ...messagesForStream.sublist(insertIndex),
        ];
      }
```

Add `import '../../../../core/utils/extensions.dart';` for `toLongLocalDateString`. `Avatar.toString()` already renders `"background": "beach", …` lines (`avatar_config.dart:87-90`), so the wrapper matches the old baked format byte-for-byte.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/chat/`
Expected: PASS. If an existing test asserts the OLD wrapper inside sent messages, update that assertion to the new shape (the behavior change is the point of this task).

- [ ] **Step 6: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/models/chat.dart lib/features/chat/domain/services/chat_streaming_service.dart test/features/chat/global_memory_injection_test.dart
git commit -m "perf(llm): slim request payloads; avatar/date context moves to the cache-safe tail"
```

---

### Task 8: Send attached images to the LLM

**Files:**
- Modify: `lib/core/services/llm/llm_streaming_service.dart` (build content-part messages for user entries with `attachedFile`)
- Test: extend `test/core/services/llm/llm_service_stream_test.dart`

**Interfaces:**
- Consumes: `LlmMessage.attachedFile` (a file path — `ai_text_input.dart:322` passes `_pickedImage?.path`), populated only for the latest image by Task 7.
- Produces: OpenAI-compatible request bodies — `"content": [{"type":"text",...},{"type":"image_url","image_url":{"url":"data:<mime>;base64,..."}}]`.

**Context:** `LlmMessage.toMap` silently drops `attachedFile` (`llm_message.dart` toMap comment: "attachedFile logic depends on implementation"), so attached images never reach the model — the feature is broken end-to-end. Build the image parts in `LlmStreamingService` (it is async and owns request assembly), not in `toMap` (sync, shared with memory/title paths).

- [ ] **Step 1: Write the failing test**

Extend `test/core/services/llm/llm_service_stream_test.dart`. The file's harness injects a `MockHttpClient` via `LlmService.setTestClient(mockClient)` and resets it in `tearDown` — follow exactly that pattern (add `dart:convert` and `dart:io` imports if absent):

```dart
test('user message with attached image sends a data-URL image part', () async {
  const LlmConfig testConfig = LlmConfig(
    id: 'image-config',
    label: 'Image Config',
    baseUrl: 'https://api.test.com',
    apiKey: 'test-key',
    model: 'test-model',
    temperature: 0.7,
  );

  final Directory tmp = await Directory.systemTemp.createTemp('img');
  final File image = File('${tmp.path}/photo.png');
  await image.writeAsBytes(<int>[1, 2, 3, 4]);

  late Request capturedRequest;
  when(() => mockClient.send(any())).thenAnswer((Invocation inv) async {
    capturedRequest = inv.positionalArguments[0] as Request;
    return StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[
        'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n'
            .codeUnits,
        'data: [DONE]\n\n'.codeUnits,
      ]),
      200,
    );
  });

  await llmService
      .promptModelStream(
        messages: <LlmMessage>[
          LlmMessage(
            role: LlmMessageRole.user,
            body: 'what is this?',
            attachedFile: image.path,
          ),
        ],
        systemPrompt: 'You are helpful.',
        config: testConfig,
      )
      .drain<void>();

  final Map<String, dynamic> body =
      jsonDecode(capturedRequest.body) as Map<String, dynamic>;
  final List<dynamic> apiMessages = body['messages'] as List<dynamic>;
  final Map<String, dynamic> userMessage =
      apiMessages.last as Map<String, dynamic>;
  final List<dynamic> content = userMessage['content'] as List<dynamic>;
  expect(content, hasLength(2));
  expect((content[0] as Map<String, dynamic>)['type'], 'text');
  expect((content[1] as Map<String, dynamic>)['type'], 'image_url');
  final Map<String, dynamic> imageUrl = (content[1]
      as Map<String, dynamic>)['image_url'] as Map<String, dynamic>;
  expect(imageUrl['url'], startsWith('data:image/png;base64,'));
  expect(imageUrl['url'], endsWith(base64Encode(<int>[1, 2, 3, 4])));

  await tmp.delete(recursive: true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/llm/llm_service_stream_test.dart`
Expected: FAIL — `userMessage['content']` is the plain string `'what is this?'`, so the `content as List<dynamic>` cast throws (or the `hasLength(2)` fails).

- [ ] **Step 3: Implement**

In `lib/core/services/llm/llm_streaming_service.dart`:

3a. Add imports:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
```

3b. Replace the `apiMessages` construction (lines ~44-47) with a call, and add the helpers below the class or as private methods:

```dart
    final List<Map<String, dynamic>> apiMessages =
        await _buildApiMessages(messages, systemPrompt);
```

```dart
  /// Builds the OpenAI message array. A user message carrying an image path
  /// becomes a two-part content array (text + data-URL image); everything
  /// else maps via [LlmMessage.toMap].
  Future<List<Map<String, dynamic>>> _buildApiMessages(
    List<LlmMessage> messages,
    String systemPrompt,
  ) async {
    final List<Map<String, dynamic>> apiMessages = <Map<String, dynamic>>[
      <String, dynamic>{'role': 'system', 'content': systemPrompt},
    ];
    for (final LlmMessage m in messages) {
      final String? dataUrl = m.role == LlmMessageRole.user
          ? await _imageDataUrl(m.attachedFile)
          : null;
      if (dataUrl != null) {
        apiMessages.add(<String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': m.body},
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, dynamic>{'url': dataUrl},
            },
          ],
        });
        continue;
      }
      apiMessages.add(m.toMap());
    }
    return apiMessages;
  }

  /// Reads the image at [path] into a base64 data URL, or null when absent,
  /// unreadable, or on web (file IO unsupported there).
  Future<String?> _imageDataUrl(String? path) async {
    if (path == null || kIsWeb) {
      return null;
    }
    try {
      final File file = File(path);
      if (!await file.exists()) {
        AppLogger.debug('Attached image not found: $path', tag: 'LlmStreaming');
        return null;
      }
      final Uint8List bytes = await file.readAsBytes();
      final String ext = path.split('.').last.toLowerCase();
      final String mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (e) {
      AppLogger.error(
        'Failed to read attached image',
        tag: 'LlmStreaming',
        error: e,
      );
      return null;
    }
  }
```

(`base64Encode` comes from the existing `dart:convert` import.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/llm/`
Expected: PASS (new test + all existing stream tests).

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/services/llm/llm_streaming_service.dart test/core/services/llm/llm_service_stream_test.dart
git commit -m "feat(llm): send the latest attached image as an OpenAI image_url content part"
```

---

### Task 9: TTS audio to the cache dir + delete-on-play

**Files:**
- Modify: `lib/features/sound/data/datasources/tts_datasource.dart` (`getMusicDirectoryPath` → temp dir; implement `delete`; keep the 10-min sweep as a safety net)
- Modify: `lib/features/sound/domain/services/tts_synthesizer.dart` (add `delete` to the interface)
- Modify: `lib/features/sound/domain/services/tts_queue_service.dart` (expose `deleteAudio`, delegating to the synthesizer)
- Modify: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (call `_ttsQueueManager.deleteAudio(...)` after playback completes)
- Test: extend `test/features/chat/bloc/chat_tts_cubit_test.dart` and `test/features/sound/tts_queue_manager_test.dart`

**Interfaces:**
- Consumes: Task 1's `removeWaitingSentence` call site (the delete goes next to it).
- Produces: `TtsSynthesizer.delete(String path)` → `TtsQueueService.deleteAudio(String path): Future<void>`. Layering note (flutter-architecture): file IO stays in the sound feature's `data/` layer — the presentation cubit only calls the domain service it already depends on. No `dart:io` in `ChatTtsCubit`.

The legacy waiting-sentences cache (`prepareWaitingSentences`) references old absolute paths that no longer resolve — acceptable: nothing produces those files anymore (the TTS queue is the only producer, `chat_streaming_service.dart:219`), and the loader is best-effort.

**Context:** Uncompressed WAVs are written to the user-visible Music folder on Android (`tts_datasource.dart:85-108`) and linger for 10 minutes. They are pure scratch: write → play once → never read again.

- [ ] **Step 1: Write the failing tests**

1a. Extend `test/features/chat/bloc/chat_tts_cubit_test.dart` (same wiring as Task 1's first test, plus one stub):

```dart
test('deletes the played WAV via the TTS queue service', () async {
  final Directory tmp = await Directory.systemTemp.createTemp('tts');
  final File wav = File('${tmp.path}/1000.wav');
  await wav.writeAsBytes(<int>[1, 2, 3]);

  final MockTtsQueueService queue = MockTtsQueueService();
  final MockAudioAmplitudeService amplitudeService =
      MockAudioAmplitudeService();
  final MockAudioPlayerService player = MockAudioPlayerService();
  final MockTtsPlaybackService playback = MockTtsPlaybackService();
  final MockInterruptionService interruption = MockInterruptionService();

  when(() => amplitudeService.extractAmplitudes(any()))
      .thenAnswer((Invocation _) async => <int>[10]);
  when(() => player.play(any()))
      .thenAnswer((Invocation _) async => const Duration(seconds: 1));
  when(() => queue.consumeCues(any()))
      .thenReturn(const <AvatarCue>[]);
  when(() => playback.stop()).thenAnswer((Invocation _) async {});
  when(() => queue.deleteAudio(any())).thenAnswer((Invocation _) async {});

  final ChatTtsCubit cubit = ChatTtsCubit(
    ttsQueueManager: queue,
    audioAmplitudeService: amplitudeService,
    audioPlayerService: player,
    interruptionService: interruption,
    ttsPlaybackService: playback,
  );

  queue.emitAudioPath(wav.path);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  player.emitPlaybackComplete();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  verify(() => queue.deleteAudio(wav.path)).called(1);
  await cubit.close();
  await tmp.delete(recursive: true);
});
```

Add `import 'dart:io';` to the test file, and add `deleteAudio` to the test file's `MockTtsQueueService` override list (it is a hand-written fake subclass — give it a no-op override like the existing `enqueue`).

1b. Extend `test/features/sound/tts_queue_manager_test.dart` with a real-file test of the deletion path:

```dart
test('deleteAudio removes the file via the synthesizer', () async {
  final Directory tmp = await Directory.systemTemp.createTemp('tts-del');
  final File wav = File('${tmp.path}/1.wav');
  await wav.writeAsBytes(<int>[1]);

  final TtsQueueService service = TtsQueueService(
    ttsSynthesizer: fakeSynthesizer, // the file's existing fake, with delete
    interruptionService: interruptionService,
    voiceEffectsService: VoiceEffectsService(),
  );

  await service.deleteAudio(wav.path);
  expect(await wav.exists(), isFalse);
  await tmp.delete(recursive: true);
});
```

Where `fakeSynthesizer` is the test file's existing synthesizer double — extend it with a real `delete` implementation (`try { final File f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart test/features/sound/tts_queue_manager_test.dart`
Expected: FAIL — `deleteAudio` does not exist on `TtsQueueService` (compile error in both files).

- [ ] **Step 3: Implement**

3a. `lib/features/sound/domain/services/tts_synthesizer.dart` — add to the abstract class:

```dart
  /// Deletes a synthesized audio file. Best-effort: failures are swallowed
  /// by implementations (scratch cleanup, never a user-facing error).
  Future<void> delete(String path);
```

3b. `lib/features/sound/data/datasources/tts_datasource.dart`:

Replace `getMusicDirectoryPath` with:

```dart
  /// Scratch space for one-shot TTS audio: the OS-managed temp dir, not a
  /// user-visible folder. Files are deleted after playback (and swept after
  /// 10 minutes as a safety net).
  Future<String> getTtsCacheDirectoryPath() async {
    final Directory tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }
```

Update the two internal call sites (`_cleanOldWavFiles` and `_synthesizeWithSupertonic`) from `getMusicDirectoryPath()` to `getTtsCacheDirectoryPath()`. Delete the Android external-storage branch and the now-unused `PlatformUtils` import if nothing else in the file uses it. Then implement the interface method:

```dart
  @override
  Future<void> delete(String path) async {
    if (kIsWeb) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.debug(
        'Failed to delete TTS file: $e',
        tag: 'TtsService',
      );
    }
  }
```

(with `import 'package:flutter/foundation.dart' show kIsWeb;`). Run `rg -n "getMusicDirectoryPath" lib test` — if an external reference exists, update it too; none is expected.

3c. `lib/features/sound/domain/services/tts_queue_service.dart` — add:

```dart
  /// Deletes a played audio file (scratch cleanup; the synthesizer owns the
  /// IO). Safe to call for a path that no longer exists.
  Future<void> deleteAudio(String path) =>
      _ttsSynthesizer.delete(path);
```

3d. `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` — next to Task 1's `removeWaitingSentence(audioPath);` add:

```dart
      // Played TTS files are scratch: delete now instead of waiting for the
      // 10-minute sweep.
      unawaited(_ttsQueueManager.deleteAudio(audioPath));
```

- [ ] **Step 4: Run tests to verify they pass**

Adding an abstract method to `TtsSynthesizer` breaks every other implementer or test double: run `rg -n "implements TtsSynthesizer" lib test` and give each one a no-op `delete` (or the real implementation for `TtsDatasource`). Then:

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart test/features/sound/`
Expected: PASS (including `tts_synthesizer_contract_test.dart` and `tts_queue_manager_test.dart`).

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/features/sound lib/features/chat/presentation/bloc/chat_tts_cubit.dart test/features/chat/bloc/chat_tts_cubit_test.dart test/features/sound
git commit -m "perf(tts): WAV scratch files move to the cache dir and are deleted on play"
```

---

### Task 10 (optional, lowest priority): Preload the next sentence's audio

**Files:**
- Modify: `lib/core/services/audio/audio_player_service.dart` (second player + `preload`)
- Modify: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (preload on enqueue while playing)
- Test: extend `test/features/chat/bloc/chat_tts_cubit_test.dart` (verify `preload` is called for the second file while the first plays)

**Interfaces:**
- Consumes: nothing.
- Produces: `AudioPlayerService.preload(String audioPath)`; `play` unchanged externally (returns duration).

**Context:** Between sentences, playback does stop → setSource → resume → getDuration platform round trips (`audio_player_service.dart:40-57`) — audible gaps. Preloading the next source on a second idle `AudioPlayer` while the current sentence plays removes the setSource wait from the gap.

**Skip criteria:** if the inter-sentence gap is inaudible on the target device after Tasks 1-9, drop this task — the added player-swap complexity is real (completion-listener rebinding), the win is tens of milliseconds.

- [ ] **Step 1: Write the failing test**

```dart
test('preloads the next file while the current one plays', () async {
  // same mock wiring as Task 1's first test, plus:
  when(() => player.preload(any())).thenAnswer((Invocation _) async {});

  queue.emitAudioPath('/tmp/tts/a.wav');
  await Future<void>.delayed(Duration.zero);
  queue.emitAudioPath('/tmp/tts/b.wav');
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  verify(() => player.preload('/tmp/tts/b.wav')).called(1);
  // ...close cubit
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart`
Expected: FAIL — `preload` does not exist.

- [ ] **Step 3: Implement**

3a. `lib/core/services/audio/audio_player_service.dart`: add

```dart
  AudioPlayer? _nextPlayer;
  String? _preloadedPath;
  StreamSubscription<void>? _completionSubscription;

  /// Loads [audioPath] into a second idle player so the next `play` skips
  /// the setSource round trip. Safe to call repeatedly; ignored on error.
  Future<void> preload(String audioPath) async {
    if (_preloadedPath == audioPath) {
      return;
    }
    try {
      final AudioPlayer player = await (_nextPlayer ??= AudioPlayer());
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(DeviceFileSource(audioPath));
      _preloadedPath = audioPath;
    } catch (e) {
      AppLogger.error(
        'Failed to preload audio',
        tag: 'AudioPlayerService',
        error: e,
      );
      _preloadedPath = null;
    }
  }
```

Refactor the completion forwarding so it survives a player swap: in `_getOrCreatePlayer`, replace the inline `player.onPlayerComplete.listen` with `_completionSubscription = player.onPlayerComplete.listen(...)` stored on the service. In `play`, before `_getOrCreatePlayer()`:

```dart
      if (_preloadedPath == audioPath && _nextPlayer != null) {
        final AudioPlayer ready = _nextPlayer!;
        await _player?.stop();
        _player = ready;
        _nextPlayer = null;
        _preloadedPath = null;
        _sourceGeneration = playbackGeneration;
        await _completionSubscription?.cancel();
        _completionSubscription = ready.onPlayerComplete.listen((_) {
          if (_sourceGeneration != _playbackGeneration) {
            return;
          }
          _playbackCompleteController.add(null);
        });
        await ready.resume();
        return await ready.getDuration() ?? Duration.zero;
      }
```

`stop()` also stops `_nextPlayer`; `dispose()` disposes both players and cancels the subscription.

3b. `lib/features/chat/presentation/bloc/chat_tts_cubit.dart`, in `_enqueueForPlayback` after `_pendingPlaybackQueue.add(audioPath);`:

```dart
    if (_isPlayingFromQueue) {
      // Next sentence: start decoding it while the current one plays.
      unawaited(_audioPlayerService.preload(audioPath));
    }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/chat/bloc/chat_tts_cubit_test.dart test/features/talking/`
Expected: PASS.

- [ ] **Step 5: Quality gate + commit**

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
git add lib/core/services/audio/audio_player_service.dart lib/features/chat/presentation/bloc/chat_tts_cubit.dart test/features/chat/bloc/chat_tts_cubit_test.dart
git commit -m "perf(tts): preload the next sentence source during playback"
```

---

## Verification (whole plan)

After the last task, run the full gate one more time and confirm the audit's acceptance criteria:

```bash
dart fix --apply && dart format .
./scripts/fverify.sh
flutter test
```

- Memory: `audioPathsWaitingSentences` empties after each played sentence (Task 1 test).
- CPU: `JsonStreamExtractor` scans per-chunk work only (Task 3 tests, incl. the 2k-char linear test).
- Rebuild scope: mouth-state changes rebuild only the avatar view (Task 5 widget test).
- Cost: history trim start constant within blocks (Task 6), payloads carry no wrappers/JSON envelopes/old images (Task 7), usage logs show a stable cached-token percentage across turns of a long chat (manual check with `LlmUsage` logs on a real provider).
- Images: a user message with an attached image sends a `data:image/...` content part (Task 8).
- Disk: TTS WAVs live under the cache dir and disappear right after playing (Task 9).

## Descoped deliberately (from the audit's minor notes)

- `VoiceEffectsService` no-op: no change — implementing DSP is a feature, not an optimization.
- Hot-path log interpolation: negligible; not worth touching call sites.
- `_cuesByPath` stale entries between clears: cleared on every `clear()` (interruption/new message); the residual edge does not justify API churn.
