# M11 accessibility evidence (rulings 17–23, lane D-a11y)

Everything here is Dart-only: no asset changed. Each ruling, what was checked, the tests that check it
and the result (`flutter test`, all green on 2026-10-31).

| Ruling | What was checked | Test file(s) | Result |
|---|---|---|---|
| 17 Stage semantics | One node over the Rive stage (`StageSemantics`, `lib/features/home/widgets/stage/stage_semantics.dart`): label "Yofardev AI in the <scene> scene" / "Yofardev AI dans le décor <décor>", value = phase (listening / thinking / speaking / idle, from the composer's mode), not a live region; one custom action per contract `propId` (35 keys `stageProp*`, one per id) running the tap's path (`tapProp`: haptic, NPC poke, `AvatarCubit.onPropTapped`), plus one per drag handle (10 keys `stageDrag*`) running `PropDragController.performAccessibilityAction` (pull: the threshold action, cord lights toggle / rope bell / chain whistle; spin: 1/8 turn; aim: ±0.25, back at either end; trail: one 5-dot stroke; poke: one stir + `flare`, cooldown kept). The Rive layers sit under `ExcludeSemantics` (the node has no children). | `test/features/home/widgets/stage/stage_semantics_test.dart`, `test/features/home/stage_screen_reader_test.dart`, `test/features/avatar/domain/services/prop_drag_accessibility_test.dart`, `test/features/avatar/presentation/rive/prop_drag_controller_test.dart` (group "the screen-reader action") | pass |
| 18 Reduce motion, live | `ReduceMotionSource` (`lib/core/services/motion/`) follows `didChangeAccessibilityFeatures`; DI feeds it to the parallax, the idle ladder, the camera, the NPCs and `AvatarCubit` (the three startup reads are gone). Camera locks medium; journeys are a cross-fade cut (`JourneyState.reduced`: fade out 200 ms, the scene changes and is saved with the avatar on screen, fade back once the file shows; no threshold, walk or jacket beat); idle ladder holds (and drops to 0 when the switch flips mid-stage); NPCs jump; drags: no inertia, pull back in one frame; captions placed once per sentence; parallax 0. | new: `test/core/services/motion/reduce_motion_source_test.dart`, `test/core/di/service_locator_test.dart` (live follow), `test/features/avatar/avatar_cubit_test.dart` (group "reduce motion: a journey is a cross-fade cut"), `test/features/avatar/presentation/rive/journey_choreography_test.dart` (reduced), `test/features/home/stage_screen_reader_test.dart` (the fade), `test/features/avatar/domain/services/idle_ladder_test.dart` (mid-stage); existing: `camera_director_test.dart` (rule 1), `home_content_stack_camera_test.dart`, `npc_director_test.dart`, `npc_director_gulls_test.dart`, `prop_drag_physics_test.dart`, `prop_drag_controller_test.dart`, `stage_caption_bubble_test.dart`, `parallax_source_test.dart` | pass |
| 19 Large text | Text scale 1.0 / 1.5 / 2.0 × 390×844 and 360×640 × en / fr: top chips, More menu, scene picker, tool chip, composer lay out with no overflow and no cut text. Fixes: the picker has two columns from 1.5 (and below 375 dp wide), taller tiles, names on up to two lines (three at 2.0, where "Compartiment" needs its own line on a narrow phone); the tool chip wraps to two lines (`AppPill.maxLines`). | `test/features/home/stage_large_text_test.dart` (36 cases) | pass |
| 20 Screen-reader paths | The walk on Home: History, Menu, the stage node (actions), tool chip, More options, the field, Talk (explicit `OrdinalSortKey`s); the More menu's six rows, labelled buttons in order; the picker: header, then ten buttons in contract order, the current one selected with the hint "Current scene" and no tap. | `test/features/home/stage_screen_reader_test.dart`; dumps below | pass |
| 21 Contrast | `scene_palette_test.dart` already covers the three M11 accents (onAccent ≥ 4.5:1) and the caption ink on each new scene's glass tint (≥ 4.5:1); no extension needed. | `test/core/design/scene_palette_test.dart` | pass (confirmed) |
| 22 Haptics respect the system | Every haptic is Flutter's `HapticFeedback` inside `FoleyService`'s sink (`SystemHaptics`, documented: Android `performHapticFeedback` without the ignore-global flag, iOS `UIFeedbackGenerator`); the composer's mic haptic, the one direct call left, now goes through `FoleyService.haptic` (so the sound-effects setting gates it too). A test bans vibration plugins, `vibrate(`, `HapticFeedback.vibrate`, haptic platform channels and any `HapticFeedback` outside the sink. | `test/haptics_path_test.dart` | pass |
| 23 High contrast → solid glass | `GlassPanel` with `MediaQuery.highContrastOf` on: the opaque surface colour, a full-opacity outline, no `BackdropFilter`, for both the rounded rectangle and a custom shape. | `test/core/design/components/glass_panel_test.dart` (group "high contrast") | pass |

## Semantics dumps

`debugDumpSemanticsTree(DebugSemanticsDumpOrder.traversalOrder)` plus the screen-reader walk
(`simulatedAccessibilityTraversal`, with each node's custom actions), captured by
`flutter test tool/a11y_semantics_dump_test.dart` (390×844, English, fake Rive assets: the Flutter
fallbacks of the UI kit):

- [`semantics_home_livingRoom.txt`](semantics_home_livingRoom.txt): Home, the stage in livingRoom
  (lamp, TV, cat, plant, the lamp cord).
- [`semantics_home_forestCabin.txt`](semantics_home_forestCabin.txt): Home, the stage in forestCabin
  (lantern, pinwheel, squirrel, woodpile, the pinwheel spin).
- [`semantics_scene_picker.txt`](semantics_scene_picker.txt): the picker over Home, livingRoom current.

## Notes

- The stage's name is the app's (`appName`): the persona has no name of its own.
- A prop's action runs the app's tap path; the Rive file's own tap animation (if the prop has one)
  only plays for a real pointer.
- Reduce motion's journey is a fade through the background colour (a dip), not a two-file
  cross-dissolve: both scene files are never drawn at once.
