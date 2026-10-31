# M10 wardrobe dedupe: bytes (Task 2a, ruling 3)

`assets/rive/avatar.riv`, built by `rive rive/avatar --once` (rive 1.8.0) from `uv run rive/tools/gen_avatar.py`.

| | bytes | vs M9 |
|---|---:|---:|
| M9 (`a429f00`, unchanged since M8) | 564,776 | |
| M10 Task 2a (this dedupe) | 477,174 | −87,602 |
| M10 line (ruling 3) | 564,776 | headroom 87,602 for tints, `MouthAnchor`, signatures |
| hard budget | 614,400 | |

## Per part

Measured by building the generator with one part of the pass switched off at a time (scratch copies of
`rive/tools/`; same CLI):

| Part | What was merged | Elements dropped | Saved |
|---|---|---:|---:|
| group names (`Up_tshirt` → `Up_short`, …) | the sets are named by kind | 0 | 228 |
| sleeves | per arm: `long` 4 → 1 (pinkHoodie survives; longCoat, christmasSweater, blackSuitAndTie dropped), `bare` 2 → 1 (underwear survives; swimsuit dropped), upper and fore sets | 1,474 (464 skin weights) | 27,774 |
| hands | per arm: 5 skins → 1 (`Skin_skin` survives as `Skin_shared`; black, metal, stars, white dropped; the glove seams and knuckles moved in) + the hand-pose keys every gesture wrote per skin | 3,260 + keys | 59,750 |
| interaction | | | 78 |
| **total** | | | **87,602** |

Gross / net: the dropped copies were 107,640 B; the colour, opacity and thickness keys that replace them
cost 20,266 B (1,336 keyed objects at ~15 B):

| Clips | keyed objects each | what |
|---|---:|---|
| `top_pinkHoodie`, `top_longCoat`, `top_christmasSweater`, `top_blackSuitAndTie` | 84 | 26 colours (sleeve gradients, cuff, folds, elbow web, lines), 58 opacities (each outfit's own pieces: knit band and stitches, wool cuff, ribs, trench seam / tab / button, suit buttons; the hoodie's 0.55 folds) |
| `costume_none` (bare skin), `costume_batman` (black), `costume_robocop` (metal), `costume_soubrette` (white), `costume_singularity` (stars) | 200 | 146 colours, 30 opacities (glove seams and knuckles), 24 seam thicknesses (white 1.3, others 1.8) |

Not merged (one outfit per kind): `short` (tshirt), `glove` (batman), `armor` (robocop), `puff`
(soubrette), `stars` (singularity). Merging sleeves across kinds (the cloth family shares the profile)
would save more but needs keys in both the top and costume layers; ruling 3 asks for one set per kind.

## Identity gate (`uv run --with pillow --with numpy rive/tools/review_wardrobe_identity.py`)

`gates.txt`: the M9 RML builds byte-identical to the M9 `avatar.riv`; 265 cases (11 outfits × rest and
the peak + mid frame of all 11 gestures, 5 hand skins × 4 drawn poses, 6 switch-order sequences with every
prefix) against M9: 258 at 0 px, 7 at max 1/255 (≤ 20 px, renderer noise); every sequence's end state
equals the new file rendered directly at the same frame (16 at 0 px, 9 at max 1/255). `rest_sheet.png`: the
11 outfits at rest, new file.

## Tasks 2b–2c: tints, the mouth anchor, the signatures

| Step | `avatar.riv` bytes | Δ |
|---|---:|---:|
| after 2a (dedupe) | 477,174 | |
| after 2b (57 tint fills, `topTint` / `hatTint`, `MouthAnchor`) | 479,262 | +2,088 |
| after 2c (5 signature clips, their states and event, `LaserLoop`, `ScanSweep` / `AuraSwell`) | 488,418 | +9,156 |
| **M10 line** | 564,776 | headroom 76,358 |

Signature clip keys (each clip's content removed and rebuilt): batman 2,213 B, robocop 1,381 B, soubrette 2,843 B,
singularity 1,463 B; `none` keeps only the arms' rest keys (256 B). Each is under the 5 KB of ruling 6.

Gates: identity at the defaults (`gates.txt`, 277 cases incl. each costume's loop at frames 120 / 400 / 640): 0
failing; tints off = M9 everywhere. `anchor.txt`: 14 frames, the anchor at most 2.90 px from the lips' centre (6 px
allowed). `signatures.txt`: no pops except robocop's held-key steps (on purpose); the frame after each clip equals the
costume never gestured (0 px).
