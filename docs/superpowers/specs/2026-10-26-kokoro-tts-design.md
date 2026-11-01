# Kokoro on-device TTS (replacing Supertonic)

> Status: **built 2026-11-01** on branch `feat/kokoro-tts`. Differences from this design, found while
> building (see "Build notes" at the end): `sherpa_onnx` pinned to **1.13.3** (not 1.13.8), Supertonic
> kept as the fallback voice, espeak voice `fr` (not `fr-fr`), US lexicon only, peak-normalized output.
> Companion implementation plan: to be created via the writing-plans workflow.
> Replaces the `supertonic_flutter` integration shipped with v3.0.

## 1. Intent and context

Today TTS is `supertonic_flutter` ^2.0.0: an on-device plugin initialized once
(`TtsDatasource.initSupertonic()` warmup in `bootstrapApp()`, skipped on Web and macOS),
synthesizing each sentence with voice style `M1` (male) into a timestamp-named WAV in the
OS temp directory. The avatar speaks French by default (`Chat.language` defaults to `fr`).

We replace it with **Kokoro-82M v1.0 (int8)** running fully on-device through
**`sherpa_onnx` 1.13.8**, downloaded once on first launch. The avatar's voice changes from
male to female: French uses `ff_siwis` (Kokoro's only French voice), English uses `af_heart`.

**Anti-goals**

- No changes to `TtsSynthesizer`, `TtsQueueService`, playback, lip-sync, or the cue pipeline —
  the swap happens entirely inside the data layer of the `sound` feature.
- No blocking of the UI isolate: `OfflineTts.generate()` is a synchronous FFI call
  (~0.5–3 s per sentence on a phone) and must run in `Isolate.run`.
- No regression of the text-only fallback: when TTS is unavailable, chat continues without
  voice (today's behavior when Supertonic fails to initialize).

**Non-goals (v1 of this work):** voice picker in Settings, `VoiceEffect` DSP (the
`VoiceEffectsService` pass-through stays), chunked/streaming playback, Wi-Fi-only download
gating, languages beyond French/English, TTS on the web demo.

## 2. Verified facts this design rests on

All checked against primary sources on 2026-10-26.

| Fact | Source |
|---|---|
| `sherpa_onnx` **2.0.0** (2026-10-23) removed espeak-ng and piper-phonemize; `data_dir` is ignored and callers must pre-phonemize. We therefore **pin 1.13.8** (2026-09-11), the last release with built-in espeak-ng G2P. | `sherpa-onnx/c-api/c-api.h` @ v2.0.1 (`@deprecated` note on `data_dir`); release notes v2.0.0 (PR #4055) |
| sherpa's `kokoro-multi-lang-v1_1` is **Kokoro v1.1-zh** (3 English female + 100 Chinese voices). It does **not** contain `ff_siwis` or `af_heart`. The v1.0 voice set lives in **`kokoro-int8-multi-lang-v1_0`**. | sherpa-onnx PR #1942; `scripts/kokoro/v1.0/generate_voices_bin.py` |
| Speaker IDs in `voices.bin` (order fixed by `id2speaker` in `generate_voices_bin.py`): `af_heart = 3`, `ff_siwis = 30`. `em_santa` was appended at 53, so 0–52 are stable. | `scripts/kokoro/v1.0/generate_voices_bin.py` |
| Language resolution per generation: `extra["lang"]` → `config.kokoro.lang` → model metadata default (`en-us`). A non-empty lang routes the **whole sentence** through espeak-ng in that language, bypassing the English lexicon. | `sherpa-onnx/csrc/offline-tts-kokoro-impl.h` @ v1.13.8 (lines 237–244); `kokoro-multi-lang-lexicon.cc` (voice-empty ⇒ lexicon path) |
| Model download: `kokoro-int8-multi-lang-v1_0.tar.bz2`, **132.4 MB** compressed; extracts to ~175 MB (`model.int8.onnx` 114.2 MB, `voices.bin` 28.2 MB, lexicons 14.8 MB, `espeak-ng-data` 17.9 MB incl. `fr_dict`, `dict/` jieba, `tokens.txt`). | GitHub release `tts-models` assets; HF `csukuangfj/kokoro-int8-multi-lang-v1_0` file tree |
| Kokoro output is 24 kHz; `writeWave()` emits 16-bit PCM mono WAV — same format family the player and `audio_analyzer` consume today. | sherpa_onnx Dart API (`OfflineTts.sampleRate`, `wave_writer.dart`) |
| `package:archive` 4.5.2 supports streaming `BZip2Decoder.decodeStream(InputStream, OutputStream)` and `TarDecoder.decodeStream` — bounded-memory extraction is possible; already a transitive dependency. | `archive` source `bzip2_decoder.dart`, `tar_decoder.dart`; `pubspec.lock` |
| `sherpa_onnx` 1.13.8 Dart API: `OfflineTts(OfflineTtsConfig)`, `OfflineTts.fromPtr({ptr, config})`, `generateWithConfig({text, config, onProgress})`, `OfflineTtsGenerationConfig({sid, speed, silenceScale, extra})`, `initBindings()` per isolate. Platform packages exist for Android (arm64/armeabi-v7a/x86), iOS, macOS, Linux, Windows, web. | `flutter/sherpa_onnx/lib/src/{tts,tts_config}.dart` @ v1.13.8; package `pubspec.yaml` |

## 3. Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | On-device via `sherpa_onnx` 1.13.8 (vs. API server) | Keeps TTS offline as today; chosen by the user |
| D2 | French = `ff_siwis` (sid 30, espeak `fr-fr`); English = `af_heart` (sid 3) | Only French-trained voice exists; `af_heart` is Kokoro's only A-grade voice and matches the female voice; chosen by the user |
| D3 | Model downloaded on first launch, extracted to app-support dir | Keeps the APK small (~+15–20 MB native libs only); chosen by the user |
| D4 | Approach A: thin `KokoroEngine` with a shared native handle, `Isolate.run` per synthesis | Least code, no custom isolate protocol; handle lives for the process lifetime (parity with Supertonic, whose `dispose` was never called) |

Defaults accepted: engine `numThreads: 2`, `speed: 1.0`, default `silenceScale`; warmup now
also runs on **macOS** (sherpa supports it — improves the dev loop; Supertonic skipped it);
no Wi-Fi gating; no voice picker.

## 4. Components

Everything new lives in the `sound` feature. `domain/` never imports `data/`/`presentation/`;
Settings consumes sound through the barrel only.

### 4.1 Domain

```dart
// lib/features/sound/domain/tts_engine_status.dart  (freezed, sealed — matches project style)
@freezed
sealed class TtsEngineStatus with _$TtsEngineStatus {
  const factory TtsEngineStatus.notInstalled() = TtsEngineNotInstalled;
  const factory TtsEngineStatus.downloading(double progress) = TtsEngineDownloading; // 0..1
  const factory TtsEngineStatus.extracting() = TtsEngineExtracting;
  const factory TtsEngineStatus.loading() = TtsEngineLoading;
  const factory TtsEngineStatus.ready() = TtsEngineReady;
  const factory TtsEngineStatus.failed(Failure failure) = TtsEngineFailed;
}
```

```dart
// lib/features/sound/domain/services/tts_engine_status_service.dart
abstract class TtsEngineStatusService {
  /// Latest status. Read this first; the stream below replays nothing.
  TtsEngineStatus get current;

  /// Broadcast stream of status changes.
  Stream<TtsEngineStatus> get status;

  /// Ensures the model is installed and the engine loaded. Idempotent and
  /// single-flight: concurrent calls share one run; a no-op once ready.
  /// Never throws — failures are reported as `failed(Failure)` on the stream.
  Future<void> install();
}
```

Both exported from `lib/features/sound/sound.dart`.

### 4.2 Data

**`data/kokoro/kokoro_model_spec.dart`** — pure constants:

```dart
abstract final class KokoroModelSpec {
  static const String modelId = 'kokoro-int8-multi-lang-v1_0';
  static const String downloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2';
  static const int sampleRate = 24000;

  /// Files/dirs that must exist after extraction (dict/ only serves Chinese;
  /// it stays because sherpa's multi-lang frontend expects the layout).
  static const List<String> requiredPaths = <String>[
    'model.int8.onnx', 'voices.bin', 'tokens.txt',
    'lexicon-us-en.txt', 'lexicon-gb-en.txt', 'dict', 'espeak-ng-data',
  ];

  static const int sidFrench = 30;  // ff_siwis
  static const int sidEnglish = 3;  // af_heart
  static const String espeakFrench = 'fr-fr';
}
```

**`data/kokoro/kokoro_model_paths.dart`** — resolved paths
(`root`, `model`, `voices`, `tokens`, `lexicon` (comma-joined us+gb), `dictDir`, `dataDir`).

**`data/kokoro/kokoro_model_store.dart`** — on-disk lifecycle under
`<appSupport>/tts/<modelId>/`:

```dart
abstract class ModelArchiveExtractor {
  /// Streaming bz2 → tar → files, run inside Isolate.run (package:archive).
  Future<void> extractTarBz2({required String archivePath, required String destinationDir});
}

class KokoroModelStore {
  KokoroModelStore({
    required http.Client client,
    required ModelArchiveExtractor extractor,
    required Future<Directory> Function() supportDirectoryProvider,
  });

  Future<bool> isInstalled(); // ready-marker file present AND requiredPaths exist

  /// Downloads + extracts + verifies. Emits downloading(p)/extracting through
  /// [onStatus]; throws on failure (caller maps to Failure). Single-flight.
  Future<KokoroModelPaths> install({
    required void Function(TtsEngineStatus status) onStatus,
  });
}
```

Install algorithm (single-flight — later callers await the in-flight future):

1. `isInstalled()` → short-circuit and return existing paths.
2. Wipe leftovers: `<modelId>.tar.bz2.part`, `<modelId>.tmp/`, and any other
   `tts/*/` dirs whose name ≠ `modelId` (old model cleanup).
3. Stream-download `downloadUrl` to `<modelId>.tar.bz2.part`; emit
   `downloading(bytesReceived / contentLength)` when `Content-Length` is known.
4. On completion: if `Content-Length` was known and the byte count mismatches →
   throw (classified as NetworkFailure) and delete the `.part` file. If `Content-Length`
   was unknown, truncation is not detectable here; proceed — a corrupt archive is caught
   by steps 5–6.
5. `extractor.extractTarBz2(part → <modelId>.tmp/)`; emit `extracting()`.
6. Verify every `requiredPaths` entry exists under `.tmp`; write
   `.ready` marker file inside it; **atomic** rename `<modelId>.tmp/` → `<modelId>/`.
7. Delete the archive. Return `KokoroModelPaths`.

**`data/kokoro/kokoro_engine.dart`**:

```dart
abstract class KokoroEngine {
  bool get isLoaded;
  Future<void> load(KokoroModelPaths paths); // Isolate.run: initBindings + OfflineTts(config)
  Future<void> synthesizeToWav({
    required String text,
    required int sid,
    String? lang,          // null ⇒ model default (en-us lexicon path)
    double speed = 1.0,
    required String outputPath,
  });
}

class SherpaKokoroEngine implements KokoroEngine { /* stores native handle address */ }
```

`SherpaKokoroEngine` details:

- `load`: `Isolate.run(() { sherpa_onnx.initBindings(); return OfflineTts(config).ptr.address; })`
  — config: `OfflineTtsKokoroModelConfig(model, voices, tokens, dataDir: espeak-ng-data,
  lexicon: 'lexicon-us-en.txt,lexicon-gb-en.txt', dictDir, lang: '')`,
  `OfflineTtsModelConfig(numThreads: 2, debug: false, provider: 'cpu')`. The handle is kept
  as an `int` address for the process lifetime (never freed — same as Supertonic today).
- `synthesizeToWav`: `Isolate.run(() { initBindings(); OfflineTts.fromPtr(...).generateWithConfig(
  text: text, config: OfflineTtsGenerationConfig(sid: sid, speed: speed,
  extra: lang == null ? {} : {'lang': lang})) → writeWave(outputPath, samples, sampleRate) })`.
- Documented contract: **one synthesis at a time** (the TTS queue is sequential; no mutex).

**`data/kokoro/kokoro_tts_service.dart`**:

```dart
class KokoroTtsService implements TtsEngineStatusService {
  KokoroTtsService({required KokoroModelStore store, required KokoroEngine engine});
}
```

`install()`: if `ready` → no-op. Else run (single-flight): store.install (status forwarded)
→ `loading()` → `engine.load(paths)` → `ready()`. Any throw →
`failed(mapExceptionToFailure(e, stackTrace: st, tag: 'KokoroTtsService'))` and **never throws**.

**`data/datasources/kokoro_tts_datasource.dart`** (replaces `tts_datasource.dart`):

```dart
class TtsEngineNotReadyException implements Exception {}

class KokoroTtsDatasource implements TtsSynthesizer {
  KokoroTtsDatasource({required KokoroEngine engine});
}
```

- `synthesize`: if `!engine.isLoaded` → throw `TtsEngineNotReadyException` (the queue logs
  and skips the sentence → text-only, exactly as when Supertonic init fails today).
  Map language → voice: `fr` → `(sid 30, 'fr-fr')`; `en` and anything else → `(sid 3, null)`.
  Output `<tempDir>/<millisecondsSinceEpoch>.wav` — same naming as today, so the stale-file
  sweeper logic moves over unchanged and starts lazily on first synthesis.
- `delete(path)`: unchanged best-effort delete, `kIsWeb` guard kept.
- `VoiceEffect` is accepted and ignored, as it is today.

### 4.3 Settings

- `SettingsCubit` gains a `required TtsEngineStatusService ttsEngineStatusService` constructor
  parameter; subscribes in the constructor (cancel in `close()`), mirrors into a new state
  field `@Default(TtsEngineStatus.notInstalled()) TtsEngineStatus ttsEngineStatus`, and gains
  `Future<void> retryTtsInstall()` → `install()`.
- New `lib/features/settings/widgets/tts_voice_status_tile.dart` styled like
  `SoundEffectsToggle` (glass container, icon, title, trailing): shows one of
  Not installed / Downloading {percent}% (linear progress) / Installing… / Loading… /
  Ready / Failed (`localizeFailure(...)` + Retry button calling `retryTtsInstall()`).
- l10n keys added with `./scripts/fstr.sh` (FR/EN): `ttsVoiceTitle`, `ttsVoiceNotInstalled`,
  `ttsVoiceDownloading` (placeholder `percent:int`), `ttsVoiceExtracting`, `ttsVoiceLoading`,
  `ttsVoiceReady`, `ttsVoiceFailed`, `ttsVoiceRetry`, `ttsVoiceDownloadHint` (e.g.
  "~130 MB, once"). ARB files: `lib/core/l10n/app_localizations_{en,fr}.arb`.

### 4.4 DI and bootstrap (`lib/core/di/service_locator.dart`)

```dart
getIt.registerLazySingleton<KokoroModelStore>(() => KokoroModelStore(
      client: http.Client(),
      extractor: ArchivePackageExtractor(),
      supportDirectoryProvider: getApplicationSupportDirectory,
    ));
getIt.registerLazySingleton<KokoroEngine>(() => SherpaKokoroEngine());
getIt.registerLazySingleton<TtsEngineStatusService>(
    () => KokoroTtsService(store: getIt<KokoroModelStore>(), engine: getIt<KokoroEngine>()));
getIt.registerLazySingleton<TtsSynthesizer>(
    () => KokoroTtsDatasource(engine: getIt<KokoroEngine>()));
// TtsQueueService: ttsSynthesizer: getIt<TtsSynthesizer>()
// SettingsCubit: + ttsEngineStatusService: getIt<TtsEngineStatusService>()
```

`bootstrapApp()`: replace the Supertonic warmup with — skipped **only on Web**
(macOS now included):

```dart
if (PlatformUtils.checkPlatform() != 'Web') {
  unawaited(getIt<TtsEngineStatusService>().install());
}
```

## 5. Data flow

- **First launch:** bootstrap → `install()`: notInstalled → downloading(p) → extracting →
  loading → ready. Sentences spoken meanwhile throw NotReady → logged and skipped →
  text-only chat (identical to today's Supertonic-failure behavior).
- **Steady state:** queue `enqueue` → `KokoroTtsDatasource.synthesize` → `Isolate.run`
  (espeak G2P + Kokoro + writeWave) → WAV path → `VoiceEffectsService` pass-through →
  `audioStream` → playback + lip-sync + cue consumption. Unchanged code path.
- **Later launches:** marker found → download skipped → engine load (~1–3 s, off-thread) →
  ready.

## 6. Error matrix

| Situation | Behavior |
|---|---|
| Network error / HTTP ≠ 200 / byte count ≠ Content-Length | `failed(NetworkFailure)`; `.part` deleted; Retry from Settings; next launch auto-retries via bootstrap. No in-session retry loop (don't burn data). |
| Corrupt archive / extraction error / required file missing | `failed(StorageFailure)`; `.tmp/` wiped |
| Disk full (IOException) | `failed(StorageFailure)` — no portable free-space pre-check; accepted |
| Engine load failure (corrupt model, ABI mismatch) | `failed(TtsFailure)`; app stays text-only |
| Per-sentence synthesis failure | Existing queue behavior: log, skip sentence, continue |
| Sentence spoken while model not ready | `TtsEngineNotReadyException` → queue skips → text-only |
| App killed mid-install | Leftovers (`.part` / `.tmp`) wiped on next `install()` |
| Interruption mid-synthesis | Queue epoch check discards result; orphan WAV swept after 10 min (existing sweeper) |
| Model upgrade in the future | Change `modelId` → new dir; step 2 of install removes old dirs |

## 7. Platform notes

- **Android (primary):** native libs for armeabi-v7a/arm64-v8a/x86 add ~15–20 MB to the APK;
  INTERNET permission already present (LLM); model in app-support — no storage permission.
- **iOS 16 / macOS 14:** via sherpa pods; macOS warmup enabled (Impeller is already disabled
  for Rive reasons — unrelated but compatible).
- **Web:** `sherpa_onnx` ships a web package so the import compiles; no install on Web →
  TTS stays text-only (`kIsWeb` guards kept).
- **Per-isolate binding:** `initBindings()` is called inside every `Isolate.run` closure
  (required per isolate; dlopen is OS-cached and cheap).
- **Supertonic removal:** delete `supertonic_flutter` from `pubspec.yaml`, delete
  `lib/features/sound/data/datasources/tts_datasource.dart`; plugin registrants and
  Podfile.lock regenerate on `pub get`/build. Update AGENTS.md (stack/gotchas) and README
  to mention Kokoro. `docs/superpowers/baseline-2026-10-26/` is historical — untouched.

## 8. Testing

**Unit (pure Dart — no native code):**

- `KokoroModelStore` (`http` `MockClient` + fake extractor + `Directory.systemTemp`):
  happy path installs marker + paths; progress monotonic 0..1; HTTP 500 and short body →
  NetworkFailure-classified throw with no leftovers; extractor throws → `.tmp` wiped;
  concurrent `install()` shares one run (single-flight); marker missing one required file →
  reinstall.
- `KokoroTtsDatasource` (fake `KokoroEngine`): `fr` → sid 30 + `fr-fr`; `en`/unknown →
  sid 3 + null; NotReady throws `TtsEngineNotReadyException`; output path ends in `.wav`
  under the temp dir; `delete` best-effort.
- `KokoroTtsService` (fakes): status sequence notInstalled→downloading→…→ready; store
  failure → `failed(NetworkFailure)`; engine load failure → `failed(TtsFailure)`;
  `install()` after ready is a no-op; concurrent installs single-flight.
- `SettingsCubit`: mirrors status; `retryTtsInstall()` calls `install()`.
- Update `test/features/sound/tts_synthesizer_contract_test.dart` to `KokoroTtsDatasource`.
- `test/architecture_test.dart` stays green (settings imports sound via barrel only;
  sound `domain/` imports no `data/`).
- Widget test: `TtsVoiceStatusTile` renders each status variant (no golden).

**Manual device QA (native synthesis can't run in `flutter test`):**

1. Fresh install on Android: first launch downloads with progress in Settings; sentences
   typed during download stay text-only.
2. French sentence quality with `ff_siwis`; English with `af_heart`.
3. Interrupt the avatar mid-speech (new message) — no crash, stale WAV swept later.
4. Kill and relaunch: no re-download; speaking works after ~1–3 s.
5. Airplane-mode first launch → Settings shows Failed + Retry; retry works once online.
6. macOS debug run: TTS works (new — was skipped with Supertonic).

**Quality gate:** `dart fix --apply`, `dart format .`, `./scripts/fverify.sh`
(freezed regeneration via `build_runner` is required for the new status model).

## 9. Risks

| Risk | Mitigation |
|---|---|
| Pure-Dart bz2 decode is CPU-heavy (~tens of seconds on low-end phones) | One-time cost, off-thread, surfaced as "Installing…". If it proves unacceptable, swap the URL to a self-hosted `.tar.gz`/`.zip` repack (native gzip inflate) — the extractor is injected, so only the default impl changes. |
| French is "unofficial" in sherpa's Kokoro frontend (docs say Chinese + English) | The `lang` → full-espeak path is verified in 1.13.8 source and `fr_dict` ships in the tarball. Manual QA item 2 is the acceptance gate. |
| `ff_siwis` quality (grade B-, <11 h training) | Accepted in D2 by the user. Voice blending / cross-language voices remain a follow-up. |
| Pinned 1.13.8 misses upstream fixes | Accepted: 2.x removes espeak-ng entirely, which would force app-side phonemization (much larger work). Pin is explicit in `pubspec.yaml` with a comment. |
| Model download from GitHub releases may be slow/blocked in some regions | Accepted for v1; the URL is a constant in `KokoroModelSpec`. Self-hosted mirror is a trivial follow-up. |

## 10. Follow-ups (explicitly out of scope)

- Voice picker over Kokoro's 54 voices (incl. blended voices).
- `VoiceEffect` DSP or mapping `speedRate` → Kokoro `speed`.
- Chunked streaming playback via `generateWithCallback` (approach B worker isolate).
- Wi-Fi-only download gating / download size warning dialog.
- Self-hosted model mirror; additional languages (`es`, `it`, `pt`, `ja`, `zh`, `hi`).

## 11. Build notes (2026-11-01)

- **ONNX Runtime clash on Android.** `supertonic_flutter` stays (the owner asked for Supertonic as the
  fallback voice), and its `flutter_onnxruntime` pulls `onnxruntime-android` from Maven (1.28.0) while
  sherpa-onnx bundles its own `libonnxruntime.so` (1.28.2 in 1.13.8). The exports are version-tagged
  (`OrtGetApiBase@@VERS_x`), so one library cannot serve both and two cannot be packaged. sherpa-onnx
  1.13.0–1.13.3 bundle ORT 1.24.3, which Maven has: we pin `sherpa_onnx` 1.13.3 (plus every platform
  package via `dependency_overrides`; the caret otherwise floats them to 1.13.8), force the Maven
  artifact to 1.24.3 in `android/app/build.gradle` and `pickFirst` the `.so`. Supertonic thereby runs on
  ORT 1.24.3 instead of 1.28.0 (it loses the 1.28 KleidiAI conv memory fix on arm64).
- **espeak voice.** `fr-fr` is not a voice file in `espeak-ng-data/lang/` and makes sherpa-onnx throw a
  C++ exception that aborts the process; `fr` works.
- **Lexicons.** Passing both `lexicon-us-en.txt` and `lexicon-gb-en.txt` logs a duplicate-word warning per
  shared word; `af_heart` is American, so only the US lexicon is passed. `dictDir` is ignored by the 1.13.x
  Dart API (Chinese only).
- **Loudness.** Kokoro peaks near 0.47 (RMS ≈ 0.09), which keeps the amplitude lip-sync in its lower
  mouth states; samples are peak-normalized to 0.95 (gain ≤ 4×) before the WAV is written.
- **Fallback.** `FallbackTtsSynthesizer` (sound domain) tries Kokoro, then Supertonic: while the model
  downloads or loads, for languages other than fr/en, and when one sentence fails. Supertonic warms up at
  launch only while Kokoro's model is not on disk. **Android only**: on macOS (and presumably iOS)
  `onnxruntime-objc` 1.28 (flutter_onnxruntime) binds to sherpa's `libonnxruntime.1.24.4.dylib`,
  `GetApi` returns null and the app segfaults in `Ort::Env::Env`; there the fallback is off and those
  sentences stay text-only.
- **Supertonic was already broken on fresh installs** (pre-existing, not fixed here): `assets/onnx/tts.json`
  is bundled but `assets/onnx/*.onnx` is gitignored and absent, so `ModelDownloader.assetsExist()` is
  true, the asset copy throws, and Supertonic never initializes unless its cache was filled earlier.
- **First-run UX.** Install starts at launch (all platforms but web, macOS included). Home shows
  `StageVoiceNotice` above the tool chip while downloading / installing or after a failure (Retry, Hide);
  Settings shows `TtsVoiceStatusTile` (status, progress, Download / Retry, size and source).
- **No timings.** sherpa-onnx's `GeneratedAudio` has samples and a sample rate only; visemes keep coming
  from `SpeechAnalyzer` on the WAV.

