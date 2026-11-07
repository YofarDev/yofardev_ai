# The avatar goes in (contract v17 notes, 2026-11-07)

Before this, the avatar walked off to the right and was clipped at artboard x 640 while every threshold drew
over it: it always passed *behind* the book, the path, the portal and the rocket. Now the app stages the avatar
*into* each one. The work is app-side; `journey.riv` is unchanged.

| Family | Walk out (≈ 1 s of the 1.6 s walk) | Walk in |
|---|---|---|
| **portal** | drawn off its feet to a point inside the ring (742, 420), spinning anticlockwise with the vortex (−0.8 turn), stretched, shrinking to a point, turning to the far scene's key light | spun out of the ring, unwinding and growing |
| **path** | walks down the tunnel towards its far end (850, 882), shrinking to 0.26 and darkening into a silhouette, then the dark takes it | a silhouette out of the tunnel, growing and lighting up |
| **rocket** | shrinks to 0.16 as it walks up, hops onto the hatch's sill (690, 827.5), walks on into the lit cabin, clipped to the opening, and fades into its depth | steps out of the cabin, hops down, grows back |
| **book** | folds flat into the gutter like a paper figure (clipped at the spine, the book over it) | unfolds out of the gutter |

The path, the portal and the rocket are now drawn **under** the avatar, the book stays over it.

| Evidence | What it shows | Known limits |
|---|---|---|
| [exits.jpg](exits.jpg) | every 2nd captured frame (~130 ms) of each family's walk out, macOS tour capture | from the run before the portal's pull point moved up (y 545 → 420; it spiralled near the floor in the wide shot) |
| [arrivals.jpg](arrivals.jpg) | the same for the walk in | same run |
| [strips.py](strips.py) | builds the two sheets from a wow capture: `uv run --with pillow --with numpy python -I strips.py <WOW_DIR> out.png 2 portal:exit,rocket:exit,path:exit,book:exit` | |

Tests: `test/features/avatar/presentation/rive/journey_passage_test.dart` (the walk mirror against the
generator's values, each family's passage, the choreography over the beats),
`test/features/avatar/presentation/widgets/rive/avatar_passage_box_test.dart` (the avatar is painted every
frame even fully faded; no pointer while the passage acts), `rive/tools/tests/test_journeys.py::
test_the_passage_mirrors_the_journey_geometry` (the Dart points equal the file's).

## Not verified

- **The latest wow tour capture is unusable for review, and the cause predates this work.** From
  ~16:40 every `WOW=tour` run on this Mac froze the avatar's Rive when the beach scene loaded:
  `presence_done ... not received` five times, then no walks. A clean worktree of `893f8c3` (HEAD,
  none of these changes) froze the same way, mid-walk at the threshold. The harness gates still
  all pass with a frozen avatar, so they do not catch it. The sheets above come from the last good
  run, 16:36.
- No phone or emulator run. The passage adds at most a clip, a transform, an opacity and a colour
  filter layer over the avatar, during a walk only.
