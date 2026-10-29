# M4 speech: jaw coarticulation (ruling 16)

Rule (`VisemeBlender`): a consonant span other than `pp`/`ff` keeps at least 0.65 x the mean
jaw of its nearest vowel before and after it in the phrase (the search stops at a `pp` and at a
`sil` of 120 ms or more); inside a phrase the jaw never drops under 0.12 except in `pp`/`ff`.

Evidence: `tool/face_speech_trace_test.dart` on `test/fixtures/speech/*.wav` (60 fps, full
`FacePerformer` output, written `jawDrop`). Median over the frames between the first and last
sounding span ("window"; includes the silences inside it) and over the sounding frames only.

| fixture | window before | window after | sounding before | sounding after |
|---|---|---|---|---|
| blue_sky | 0.125 | 0.169 | 0.125 | 0.169 |
| so_true | 0.141 | 0.144 | 0.144 | 0.147 |
| fine_view | 0.249 | 0.251 | 0.249 | 0.251 |
| bonjour (fr) | 0.119 | 0.131 | 0.131 | 0.149 |

`pp` closure check (written face): blue_sky 550-625 ms min jaw 0.00, max press 0.88; bonjour
0-125 ms jaw 0.00, press 0.85 (0.849); bonjour 1350-1400 ms jaw 0.00, press 0.88. Unchanged.

**The 0.22 target is not met** on blue_sky, so_true and bonjour. The consonant rule works (tests),
but those fixtures are dominated by `ou` vowels (table jaw 0.15, written about 0.12-0.15), which
the rule does not touch. Experiment, not committed: `ou` jaw 0.3 in `MouthShape` gives window
medians 0.250 / 0.214 / 0.262 / 0.231.
