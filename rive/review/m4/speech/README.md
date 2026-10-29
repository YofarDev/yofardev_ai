# M4 speech: jaw coarticulation (ruling 16)

Rule (`VisemeBlender`): a consonant span other than `pp`/`ff` keeps at least 0.65 x the mean
jaw of its nearest vowel before and after it in the phrase (the search stops at a `pp` and at a
`sil` of 120 ms or more); inside a phrase the jaw never drops under 0.12 except in `pp`/`ff`.

Evidence: `tool/face_speech_trace_test.dart` on `test/fixtures/speech/*.wav` (60 fps, full
`FacePerformer` output, written `jawDrop`). Median over the frames between the first and last
sounding span ("window"; includes the silences inside it) and over the sounding frames only.

| fixture | window before | window after | sounding before | sounding after | window after 16b | sounding after 16b |
|---|---|---|---|---|---|---|
| blue_sky | 0.125 | 0.169 | 0.125 | 0.169 | 0.234 | 0.234 |
| so_true | 0.141 | 0.144 | 0.144 | 0.147 | 0.201 | 0.205 |
| fine_view | 0.249 | 0.251 | 0.249 | 0.251 | 0.255 | 0.255 |
| bonjour (fr) | 0.119 | 0.131 | 0.131 | 0.149 | 0.224 | 0.231 |

`pp` closure check (written face): blue_sky 550-625 ms min jaw 0.00, max press 0.88; bonjour
0-125 ms jaw 0.00, press 0.85 (0.849); bonjour 1350-1400 ms jaw 0.00, press 0.88. Unchanged.

**Ruling 16b (orchestrator):** the consonant rule alone left the median at the `ou` vowels'
jaw (table 0.15, a closed "rubber ring" /u/ the M3 critics disliked). `Viseme.ou` is now jaw 0.28
(pucker 1 unchanged). After 16b three fixtures pass 0.22; so_true reaches 0.201 (window) / 0.205
(sounding), still under the target (ou-heavy text and a 225 ms inner silence). The `pp` closures
above are unchanged by 16b (jaw 0.00 each; press 0.88 / 0.849 / 0.88).
