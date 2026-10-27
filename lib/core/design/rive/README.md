# core/design/rive

Home of the UI-kit widgets backed by Rive (built in milestone M2). This is the only place under `lib/core/` allowed to import `package:rive/`, besides `lib/features/avatar/presentation/`; `test/architecture_test.dart` enforces it. Artboard, state-machine, view-model and event names are defined by `rive/CONTRACT.md`.
