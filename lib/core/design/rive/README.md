# core/design/rive

Home of the UI-kit widgets backed by Rive (built in milestone M2). This is the only place under `lib/core/` allowed to import `package:rive/`, besides `lib/features/avatar/presentation/`; `test/architecture_test.dart` enforces it. Artboard, state-machine, view-model and event names are defined by `rive/CONTRACT.md`.

- `rive_vm_binding.dart`: `RiveVmBinding`, the view-model property layer shared with the avatar (state-machine input fallback, skips unchanged writes, logs each missing name once).
- `ui_kit_contract.dart`: Dart mirror of the `ui_kit.riv` contract section, plus `ComposerOrbState` and `ToolIconKind`.
- `ui_kit_file.dart` + `ui_kit_artboard.dart`: the shared, lazily decoded file and the per-widget controller; every widget shows its Flutter fallback until (or instead of) the Rive artboard.
- `ui_kit.dart`: the public barrel (`ComposerOrb`, `StatusGlow`, `ToolIcon`, `RiveToggle`, `MarkSting`); it exports no Rive type.
- Widget tests use `test/helpers/rive_test_assets.dart` (`serveFakeRiveAssets()`) and call `UiKitFile.resetForTest()` in `setUp`.
