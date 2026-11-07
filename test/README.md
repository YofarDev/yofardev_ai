# Test Suite

The quality gate is local — `./scripts/fverify.sh` (format check + analyze +
the whole suite, including the architecture and DI smoke tests). Line coverage
for the logic layers: `./scripts/fcoverage.sh` (see `scripts/README.md`).

## Layout

| Path | What lives there |
|------|------------------|
| `test/core/…` | mirrors `lib/core/…` — models, services, design tokens, DI smoke test |
| `test/features/<name>/…` | mirrors `lib/features/<name>/…` — data / domain / presentation |
| `test/architecture_test.dart` (+ `test/support/`) | the layering gate: analyzer-based checker + scan rules; the checker has its own tests with negative fixtures |
| `test/core/di/service_locator_test.dart` | DI smoke test — every registration resolves |
| `test/integration/…` | feature-flow tests: real dependency chains over scripted fakes |
| `test/helpers/` | `golden_test_helper.dart` (fonts + theme wrapper), `rive_test_assets.dart` (`serveFakeRiveAssets()`) |
| `test/**/goldens/` | golden PNGs — see `golden_tests_README.md`; regenerate only on intentional visual change |
| `tool/` | critic/trace harnesses (face–speech, body language, a11y dump) — run with env-var args, not part of `fverify.sh` |
| `integration_test/` | device/emulator tests, several manual-gated (kokoro TTS, wow captures, frame cost) — see `AGENTS.md` |
| `rive/tools/tests/` | the Python suite for the Rive asset pipeline (gated by `./scripts/frive.sh`) |

## Harnesses (reuse before writing a new rig)

The suite's feature-flow tests pump the **real** dependency chain and replace
only the I/O seams with fakes — the opposite of isolated unit tests, on purpose:

- `test/features/home/widgets/stage/real_reply_rig.dart` — real
  `ChatStreamingService` + `TalkingRepositoryImpl`, mocked LLM/settings I/O
- `test/features/chat/bloc/chat_reply_failure_harness.dart` — the reply path
  driven to failure
- `test/features/home/stage_harness.dart` — the stage assembled with fakes

When you add a cross-layer test, extend a harness instead of rebuilding one.

## Conventions

- `mocktail` (never mockito); `registerFallbackValue` for non-primitives used with `any()`.
- Repository tests assert mapping + typed failures (`isA<StorageFailure>()`), never `Failure.message` strings — see any `*_failure_test.dart`.
- Cubit tests use `bloc_test`; widget tests use fake cubits pushed state via a test-only helper.
- Rive widget tests call `serveFakeRiveAssets()` and `UiKitFile.resetForTest()` in `setUp`.
- New test files mirror the lib path of the class under test.
