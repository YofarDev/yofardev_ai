# Costume voice effects (Batman, RoboCop) — plan

**Goal:** when the assistant wears the `batman` or `robocop` costume, its TTS
voice is post-processed: Batman = low, gravelly; RoboCop = metallic, band-limited,
synthetic. Every other costume (and `none`) sounds unchanged.

**Today:** `lib/core/models/voice_effect.dart` (`VoiceEffect{pitch, speedRate}`),
`CostumeExtension.getVoiceEffect()` in `avatar_config.dart` and
`VoiceEffectsService` (`lib/core/services/audio/voice_effects_service.dart`) are
a dead scaffold: the service returns its input path, and
`ChatStreamingService.deliverCues` always enqueues `VoiceEffect(pitch: 1.0,
speedRate: 1.0)`. The synthesizers (Kokoro, Supertonic) ignore the parameter.

## Global constraints

- Read `AGENTS.md` and `~/.claude/skills/flutter-architecture/SKILL.md` first
  (AGENTS.md wins). Explicit types, relative imports, `AppLogger`, `Result<T>`
  rules unchanged, no `fpdart`. `test/architecture_test.dart` must stay green
  (core never imports features).
- Pure Dart DSP, no new packages, no platform channels, no FFmpeg.
- **Duration-preserving**: the processed WAV has exactly the same sample count
  and sample rate as the input (lip-sync timing depends on it).
- Do NOT touch these files (owner's work in progress):
  `lib/features/home/widgets/stage/stage_caption.dart`,
  `lib/features/home/widgets/stage/stage_line.dart`,
  `test/features/home/widgets/stage/stage_caption_test.dart`.
- Nothing under `assets/`, `rive/`, `lib/features/avatar/presentation/rive/`.
- Test-first. Leave everything uncommitted.

## Task 1 — `VoiceEffect` becomes a preset enum

- Replace the class in `lib/core/models/voice_effect.dart` with
  `enum VoiceEffect { none, batman, robocop }` (doc comment: a post-processing
  preset picked by the costume; values only ever appended).
- In `avatar_config.dart` replace `CostumeExtension.getVoiceEffect()` with a
  getter `VoiceEffect get voiceEffect` : `batman → VoiceEffect.batman`,
  `robocop → VoiceEffect.robocop`, everything else `VoiceEffect.none`
  (exhaustive `switch` expression, no `default`). Drop the `PlatformUtils`
  import if it becomes unused.
- Keep the `voiceEffect` parameter on `TtsSynthesizer.synthesize`,
  `TtsQueueItem`, `TtsQueueService.enqueue` and the datasources (now typed by
  the enum; synthesizers keep ignoring it). Update every call site and test
  that built `VoiceEffect(pitch: …, speedRate: …)` to `VoiceEffect.none`.

## Task 2 — DSP: `lib/core/services/audio/voice_fx/`

`voice_fx.dart`: `abstract final class VoiceFx` with
`static Float32List process(Float32List samples, int sampleRate, VoiceEffect effect)`.
Pure, synchronous, returns a NEW list of the same length (for `none`: a copy).
All tuning constants in one `const` block at the top of the file (named, with a
comment each) so the owner can tune by ear. Small private helpers: RBJ biquad
(lowpass, highpass, low shelf; Direct Form I, per call state), peak normalize.

**Batman** (in order):
1. Pitch down, duration-preserving: dual-tap delay-line pitch shifter, ratio
   `0.78` (≈ −4.3 semitones), window `50 ms`, the two taps half a window apart,
   crossfaded with a raised-cosine (Hann) gain so the sum is constant.
2. Low shelf `+5 dB` at `180 Hz` (S = 1).
3. Lowpass `4500 Hz`, Q `0.707`.
4. Grit: `wet = tanh(2.2·x) / tanh(2.2)`, output `0.4·x + 0.6·wet`.
5. Peak normalize to `0.89` (skip when the peak is below `1e-6`).

**RoboCop** (in order):
1. Highpass `250 Hz` then lowpass `3800 Hz` (Q `0.707` each) — helmet radio band.
2. Ring modulation: `x · (1 − d + d·sin(2π·55·t))`, depth `d = 0.5`.
3. Metallic feedback comb: `y[n] = x[n] + 0.45·y[n − D]`, `D = round(7 ms · sr)`.
4. Bit crush to 10 bits: `round(x · 512) / 512` (after a pre-normalize to 0.89
   so the crush depth is level-independent).
5. Peak normalize to `0.89`.

`wav_pcm.dart`: add `Uint8List encodePcm16()` on `WavPcm` (mono, 16-bit PCM,
canonical 44-byte header, clamp to [−1, 1]) so a processed buffer round-trips
through `WavPcm.decode`.

## Task 3 — `VoiceEffectsService` does the work

`applyVoiceEffects(String inputPath, VoiceEffect effect) → Future<String>`:
- `none` or `kIsWeb` → return `inputPath` (no file written).
- Else read the bytes, run decode → `VoiceFx.process` → `encodePcm16` inside
  `Isolate.run` (pass only bytes + the enum, like
  `AudioAmplitudeService._analyzeInIsolate`), write next to the input as
  `<input path without .wav>_fx.wav` (`flush: true`), return that path.
- Any failure → `AppLogger.error(..., tag: 'VoiceEffectsService')` and return
  `inputPath` (the sentence still plays, dry). Remove the old placeholder
  comments / TODO.

## Task 4 — wire the costume, keep lip-sync on the dry WAV

- `ChatStreamingService.deliverCues`: enqueue
  `voiceEffect: (currentAvatar?.call() ?? avatar).costume.voiceEffect`, read at
  each sentence (a `change_avatar` tool mid-reply switches the voice for the
  following sentences).
- `TtsQueueService`: when `processedAudioPath != rawAudioPath`, remember
  `processed → raw`; add `String peekAnalysisPath(String audioPath)` (the raw
  path when known, else `audioPath`); clear the entry wherever `_textByPath`
  is cleared/removed (same lifecycle). Add it to `TtsQueueManager` if that is
  the interface `ChatTtsCubit` holds (check; keep fakes/mocks compiling).
- `ChatTtsCubit`: `analyzeSpeech(_ttsQueueManager.peekAnalysisPath(audioPath), …)`
  (the futures stay keyed by the played `audioPath`). Amplitudes stay on the
  played (processed) file.
- Leave scratch-file cleanup as it is; if `TtsScratchFiles` deletes by
  directory/age, the `_fx.wav` sibling is covered — say so in the report; if it
  deletes by exact path, also delete the raw sibling there and say so.

## Tests (all new unless noted)

- `test/core/services/audio/voice_fx_test.dart`:
  - every effect returns the input length; `none` returns equal samples;
    silence stays silence (all |s| < 1e-6) for every effect.
  - Batman on a 1 s 220 Hz sine @ 24 kHz: dominant frequency of the middle
    0.5 s (zero-crossing count) is `171.6 ± 8 Hz`; peak ≤ 0.89 + 1e-3.
  - RoboCop: a 100 Hz sine (amplitude 0.5) comes out at least 6 dB quieter
    (RMS) than a 1 kHz sine of the same amplitude. Normalizing hides this, so
    `VoiceFx` exposes `@visibleForTesting static Float32List
    processUnnormalized(...)` (every step except the final peak normalize;
    `process` = it + normalize) and the test uses it.
- `wav_pcm` round trip: `decode(encodePcm16())` keeps sample rate, length and
  samples within 1/32767.
- `voice_effects_service_test.dart`: `none` returns the input path and writes
  nothing; batman writes `<name>_fx.wav` decodable with the same sample count;
  a corrupt input returns the input path.
- `avatar_config` test: costume → voiceEffect mapping for all five costumes.
- Chat streaming: a reply whose `currentAvatar()` returns a robocop costume
  enqueues `VoiceEffect.robocop` (extend the existing streaming / queue test
  that captures `enqueue` args).
- Queue: `peekAnalysisPath(processed) == raw` when an effect produced a new
  file, `== path` otherwise; cleared with the queue.

## Done

`dart run build_runner build --delete-conflicting-outputs` only if a freezed
model changed, `dart fix --apply`, `dart format .`, `./scripts/fverify.sh`
green. Add one line to `AGENTS.md` Gotchas: costume voice effects live in
`core/services/audio/voice_fx/` (pure Dart, duration-preserving, Batman and
RoboCop only; speech analysis reads the dry WAV via `peekAnalysisPath`).
