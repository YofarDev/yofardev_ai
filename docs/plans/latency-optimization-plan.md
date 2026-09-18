# Latency Optimization Plan: User Input → LLM → TTS → Playback

> **For the implementing agent:** Work through the phases in order. Each phase is
> independently shippable — commit after each one. If a phase breaks tests you
> cannot fix, stop, revert that phase, and report back instead of guessing.
> Line numbers below are approximate (they reference the code as of 2026-09-18).

## Background: the pipeline today

Voice/text message flow when function calling is enabled (the default,
`functionCallingEnabled = true` in `chat_state.dart`):

1. `ChatStreamingService.streamResponse` (`lib/features/chat/domain/services/chat_streaming_service.dart:66`)
   calls `_chatRepository.askYofardevAi(...)` → `YofardevAgent.ask()`
   (`lib/core/services/agent/yofardev_agent.dart:35`), which makes:
   - **LLM call #1** — `checkFunctionsCalling`, a full non-streamed round trip
     just to decide which tools to call (`lib/core/services/llm/llm_service.dart:199`)
   - **LLM call #2** — `promptModel`, a full non-streamed generation of the final
     answer (`yofardev_agent.dart:172`). This runs **even when no tools were called**.
2. Back in `ChatStreamingService`, if no function-calling entries came back, that
   fully generated answer is **discarded** and **LLM call #3** is made:
   `promptModelStream` (SSE streaming, `lib/core/services/llm/llm_streaming_service.dart:29`).
3. Stream chunks → `StreamProcessorService` → `JsonStreamExtractor` (extracts the
   `"message"` field from partial JSON) → `SentenceSplitter` → each complete
   sentence is enqueued for TTS immediately (good — keep this).
4. `TtsQueueService` synthesizes sentences one at a time (Supertonic TTS, WAV files)
   with a fixed 100 ms timer between items.
5. `ChatTtsCubit._playAndExtractAmplitudes` extracts amplitudes from the whole WAV
   **before** starting playback, creating a new `AudioPlayer` per sentence.

The sentence-level TTS pipelining (3–5) is already correct in shape. The dominant
latency problem is the three sequential LLM round trips; the secondary problems are
per-sentence playback gaps.

## Goal

Reduce end-to-end latency from user send to first audio out, without changing
LLM or TTS providers and without changing UI behavior.

## Non-goals / hard constraints

- Do **not** swap the LLM provider, TTS engine, or request endpoints.
- Do **not** change UI layout or user-visible behavior (except where a phase
  explicitly says so).
- Do **not** break demo mode: `FakeLlmService` (registered as the
  `LlmServiceInterface` in `lib/core/di/service_locator.dart:100`) must keep
  working end to end.
- Follow `AGENTS.md` + `docs/04_CONVENTIONS.md`:
  - All DI wiring only in `lib/core/di/service_locator.dart`.
  - Errors via `Result<T>` (`Result.ok` / `Result.err(Failure)`); no thrown
    exceptions across repository boundaries.
  - No cubit-to-cubit dependencies; features may only import another feature's
    barrel or `core/services/`; `core/` never imports `features/`.
  - `test/architecture_test.dart` enforces import rules — it must stay green.

## Phase 1 — Eliminate the discarded LLM generation (biggest win)

**Why:** the default path pays three sequential LLM round trips; call #2 is a
complete answer that is thrown away. This phase removes call #2 and also makes
the tools-called path stream (today it is fully non-streamed).

### Step 1.1 — New agent method `checkAndExecuteTools`

File: `lib/core/services/agent/yofardev_agent.dart`

Extract from `ask()` into a new public method:

```dart
/// Detects and executes tools for the turn. Does NOT generate the final answer.
/// Returns the function-calling entries (empty if no tools were called) and the
/// user message augmented with tool results (unchanged if no tools were called).
Future<(List<ChatEntry> functionEntries, String augmentedUserMessage)>
    checkAndExecuteTools({
  required Chat chat,
  required String userMessage,
  required SettingsRepository settingsRepository,
}) async
```

- Reuse, verbatim, the existing logic of `ask()` steps 1–2 (tool detection +
  execution, `yofardev_agent.dart:50-115`) and the function-entry building from
  step 5 (`yofardev_agent.dart:222-242`).
- Reuse, verbatim, the "augmented prompt" text from step 3
  (`yofardev_agent.dart:118-129`): when `toolResults` is non-empty,
  `augmentedUserMessage = userMessage + '\n\n[System: The following functions were executed...]\n...'`
  (identical wording). Otherwise it equals `userMessage`.
- Keep `ask()` only if something still calls it after Step 1.3; otherwise delete it.

### Step 1.2 — Replace the repository method

Files:
- `lib/features/chat/domain/repositories/chat_repository.dart` (interface)
- `lib/features/chat/data/repositories/yofardev_repository_impl.dart` (impl)

Replace `askYofardevAi` with:

```dart
Future<Result<(List<ChatEntry> functionEntries, String augmentedUserMessage)>>
    prepareToolTurn({required Chat chat, required String userMessage});
```

Impl:
- **Demo short-circuit:** keep the existing `_fakeLlmService.isActive` check but
  return the "no tools" outcome — `(const <ChatEntry>[], userMessage)` — instead
  of consuming a scripted response. Rationale: the streaming path already
  consumes scripted responses through `FakeLlmService.promptModelStream`.
  ⚠️ Decision procedure: this changes *which* scripted response the turn uses
  (the old code consumed one in the repository and one in the stream). Run demo
  mode manually after this phase; if the script feels off-by-one, restore the
  old `getNextResponse()` consumption in the short-circuit and discard its
  result, preserving the current pairing.
- Otherwise call `_agent.checkAndExecuteTools(...)`, wrap in `Result.ok`.
  Errors → `Result.err(NetworkFailure(...))` as today.

### Step 1.3 — Rewire `ChatStreamingService.streamResponse`

File: `lib/features/chat/domain/services/chat_streaming_service.dart:131-206`

- Replace the `askYofardevAi` call with `prepareToolTurn`.
- Add the function-calling entries to the chat exactly as today
  (`chat_streaming_service.dart:154-163`), so the UI expansion tiles are unchanged.
- If `functionEntries` is **empty** → stream exactly as today (step 3 of the
  current method), using `chat.llmMessages` unchanged.
- If `functionEntries` is **non-empty** → do **not** take a pre-baked final
  response anymore. Instead, build the message list for streaming:
  - Take `chat.llmMessages` (which already ends with the wrapped user entry).
  - Replace the last element's body with `augmentedUserMessage`
    (mirror the replacement logic of `yofardev_agent.dart:135-148`).
  - Feed that list to the **same** `_streamProcessor.processStream(
    _llmService.promptModelStream(...))` loop used for the normal path.
  - Delete the old non-streamed branch (`chat_streaming_service.dart:170-205`),
    including its whole-text `_ttsQueueManager.enqueue` — the per-sentence
    enqueue inside the streaming loop now covers the tools path too.
- Keep: interruption checks, `onChatUpdated`/`onStreamingUpdate`/
  `onStreamComplete`/`onError` callback semantics, `returnJson: true`,
  the `fullJsonResponse` final-body handling, and `updateChat` persistence.

### Step 1.4 — Update affected tests

- `test/integration/function_calling_integration_test.dart` and
  `test/functions_test.dart` reference the old flow; update mocks/expectations
  to `prepareToolTurn`. If a test's intent is obsolete (asserting the discarded
  generation), delete that assertion with a note.

**Acceptance criteria**
- With function calling ON and no tools involved: exactly **one** streamed LLM
  call per turn (verify via `AppLogger` — you should see one
  `'LLM stream started'` and **no** `'LLM response received: status=200'`
  non-streamed line).
- With a weather/time question (tool fires): function-calling entry still shows
  in chat, and the answer streams sentence-by-sentence (TTS starts before the
  full answer exists).
- Demo mode still plays a scripted response.

## Phase 2 — Pipeline the playback pre-steps (remove inter-sentence gaps)

**Why:** `ChatTtsCubit._playAndExtractAmplitudes`
(`lib/features/chat/presentation/bloc/chat_tts_cubit.dart:117`) decodes the whole
WAV for amplitudes *before* playing, and only after the previous sentence
finished. Every sentence transition pays a full file decode + player setup.

### Step 2.1 — Prefetch amplitudes on arrival

File: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart`

- Add `final Map<String, Future<List<int>>> _amplitudeFutures = {};`
- In `_enqueueForPlayback(audioPath)` (line 87): if not already present, start
  `_amplitudeFutures[audioPath] = _audioAmplitudeService.extractAmplitudes(audioPath)`
  immediately (unawaited future stored).
- In `_playAndExtractAmplitudes`: `final amplitudes = await _amplitudeFutures.putIfAbsent(audioPath, () => _audioAmplitudeService.extractAmplitudes(audioPath));`
  — extraction now overlaps with previous playback instead of blocking the
  transition. Do **not** reorder play-before-extract for a single file; keep
  "await the future, then play" so lip-sync stays aligned.
- After playback completes (and in `close()`/interruption cleanup), remove the
  entry from the map to bound memory. Keep appending to
  `state.audioPathsWaitingSentences` exactly as today (UI contract unchanged).

### Step 2.2 — Persistent audio player

File: `lib/core/services/audio/audio_player_service.dart`

- Keep one `AudioPlayer` instance across plays: create it lazily; per `play()`
  call reuse it (`setSource(DeviceFileSource(...))` then `resume()`).
- Keep the `_playbackGeneration` guard semantics and the single
  `onPlayerComplete` subscription; re-subscribe only if the player was recreated.
- `stop()` keeps its current behavior (stop + dispose is acceptable if simpler —
  the requirement is only that back-to-back sentences don't each create a player
  while playing normally).
- `playAsset` can stay as-is.

**Acceptance criteria**
- In debug logs, timestamps of "Starting TTS playback" → "Audio playback
  completed" chains show no decode-sized gap between consecutive sentences.
- Interruption (stop button / interruption stream) still stops instantly and
  clears queues; `test/features/chat/bloc/chat_tts_cubit_test.dart` stays green
  (update mocks if the player lifecycle changed).

## Phase 3 — TTS synthesis critical-path cleanup

**Why:** the synthesis path carries avoidable serial work.

File: `lib/features/sound/data/datasources/tts_datasource.dart`

- **3.1** Move the old-WAV cleanup scan (`tts_datasource.dart:117-140`) out of
  `_synthesizeWithSupertonic`. Start a `Timer.periodic` (every 5 minutes) in
  `initSupertonic()` and cancel it in `disposeSupertonic()`.
- **3.2** Remove the file-existence retry loop
  (`tts_datasource.dart:156-177`). `writeAsBytes(flush: true)` completing is the
  guarantee; keep at most a single `exists()` sanity check with an error log.

File: `lib/features/sound/domain/services/tts_queue_service.dart`

- **3.3** Remove the `Timer(const Duration(milliseconds: 100), _processNext)`
  indirection (lines 181-185 and 200-204) — after `_isProcessing = false`, call
  `_processNext()` directly (it re-checks the guard).
- **3.4** Fix the interruption race in `clear()` (line 85): add
  `int _epoch = 0;` — `clear()` increments it; `_processNext` captures the epoch
  at start and, after each `await`, aborts (returns without emitting to
  `_audioController`) if the epoch changed. Today `clear()` sets
  `_isProcessing = false` while a synthesis is still in flight, so a stale
  sentence can be emitted after an interruption.

**Acceptance criteria**
- `test/features/sound/tts_queue_manager_test.dart` updated and green
  (add a test: enqueue → immediately `clear()` → nothing is emitted on
  `audioStream` afterwards).
- No behavior change in normal synthesis order.

## Phase 4 — Trim conversation history + fix duplicated user message

**Why:** `chat.llmMessages` (`lib/core/models/chat.dart:87`) sends every entry
forever, and each user entry embeds the date + full avatar JSON
(`lib/features/chat/domain/services/chat_entry_service.dart:34`), so prompt size
—and therefore time-to-first-token—grows every turn.

- **4.1** In the `ChatExtension.llmMessages` getter: cap the returned list to the
  last `40` messages (named constant with a comment explaining the latency
  motive). Do **not** rewrite entry bodies — the avatar-config content is how the
  model knows current state; only the count is capped.
- **4.2** In `LlmService.checkFunctionsCalling` (`llm_service.dart:205-211`):
  `messages` already ends with the user's message (the chat passed in includes
  it). Only append `lastUserMessage` if `messages` is empty or the last message's
  role is not `user`; log a warning if a duplicate would have been sent.

**Acceptance criteria**
- `test/models/chat_test.dart` updated: long chats return at most 40 messages.
- Normal conversation behavior unchanged (recent context intact).

## Phase 5 — Sentence splitter max-length flush

**Why:** `SentenceSplitter` (`lib/core/services/stream_processor/sentence_splitter.dart:3`)
only flushes on `.!?` — one long unpunctuated clause delays first TTS
proportionally.

- Add an optional constructor parameter `maxBufferLength` (default `180`
  characters). In `extractCompleteSentences`, after the normal scan, if
  `_incompleteBuffer.length >= maxBufferLength`:
  - flush at the **last soft boundary** (`,` followed by a space, else any
    space) that is at least `60` characters in, emitting the prefix as a
    sentence;
  - if no such boundary exists, hard-flush the entire buffer.
- This trades a little TTS prosody for bounded first-audio latency. Keep the
  default conservative so ordinary sentences are unaffected.

**Acceptance criteria**
- New unit tests in `test/core/services/stream_processor/sentence_splitter_test.dart`
  (create the file): normal sentences unchanged; a 400-char input without `.!?`
  yields chunks no larger than ~`maxBufferLength + slack`;
  `test/core/services/stream_processor/stream_processor_service_test.dart` green.

## Phase 6 (optional stretch) — Single streamed call with tools

**Why:** supersedes Phase 1's remaining tool-check round trip: pass `tools` in
the streamed request itself; only re-stream when tools actually fire.

Only attempt this after Phases 1–5 are green. Design sketch:

- Extend the stream request body in `llm_streaming_service.dart` with the
  `tools` / `tool_choice: 'auto'` fields (same mapping as
  `checkFunctionsCalling`, `llm_service.dart:213-233`).
- SSE deltas can carry `delta.tool_calls[]` whose `function.arguments` string
  arrives **fragmented across chunks** (accumulate by `index`, concatenating
  `arguments`; `id`/`name` usually arrive once). Extend `LlmStreamChunk`
  (freezed — run `build_runner`) with a `toolCallDelta` variant carrying
  `{index, id?, name?, argumentsDelta?}`. `FakeLlmService` must handle the new
  variant (it never emits it — fine).
- In `ChatStreamingService`: if the stream ends with accumulated tool calls,
  execute them (via the Phase 1 agent method or the registry), append the
  assistant `tool_calls` message + one `role: 'tool'` message per result to the
  message list, and stream again. Loop with a hard cap of **3** tool rounds.
- Keep `JsonStreamExtractor` untouched (tool-call streams carry no content).
- If this proves too invasive (provider quirks with streamed tool calls),
  Phase 1 alone already removes the worst latency — report and stop.

## Final verification checklist (run after every phase, and at the end)

1. `flutter analyze` — zero new warnings.
2. `flutter test` — all green (including `test/architecture_test.dart`).
3. Manual smoke (device or emulator), function calling **on**:
   - Plain message: one stream in logs, text appears progressively, TTS starts
     after the first sentence, no gap-silence between sentences.
   - Tool message (e.g. weather): function tile appears, answer streams, TTS
     per sentence.
   - Interruption mid-speech: audio stops, queues clear, next message works.
   - Function calling **off**: unchanged behavior.
   - Demo mode: scripted response plays.
4. Commit per phase: `perf(chat): <phase summary>`.

## Suggested commit sequence

1. `perf(chat): remove discarded LLM generation, stream tool-call answers`
2. `perf(tts): prefetch amplitudes and reuse audio player for gapless sentences`
3. `perf(tts): move WAV cleanup off critical path, fix queue interruption race`
4. `perf(llm): cap conversation history, dedupe tool-check user message`
5. `perf(tts): flush long unpunctuated text for faster first audio`
6. (optional) `perf(llm): single streamed call with inline tool detection`
