# M5 Task 8: the newspaper prop (ruling 9, contract v8b)

Rendered by `uv run --with pillow python rive/tools/motion_review.py --newspaper` (real CLI renders
of `rive/avatar`, head at the director's reading target `yaw` 0.6 / `pitch` −0.5, `autoBlink` off).

Budget first: a draft build measured 574,335 B (≤ 600,000), so the task ran. avatar.riv
563,993 → 574,335 B (+10.3 KB; 14 KB kept for M6 hands: 25.7 KB left under 600,000).

| File | What |
|---|---|
| `out_sheet.png`, `hold_sheet.png`, `away_sheet.png` | `prop_newspaper_out` / `_hold` / `_away`, 10 frames each |
| `out_hold_away.gif` | out → hold → away, every 2nd frame at 30 fps |
| `interrupt_*.png` | as the tablet's (`short_tool`, `back_early`, `back_late`, `gesture_under_away`) plus Review Focus 4: `news_none_tablet` (news, none, then tablet 4 frames into the put-away), `news_to_tablet_direct` and `tablet_to_news_direct` (one prop straight to the other) |
| `gates.txt` | hold seam, pop gate, IK check |

What the file does (`rive/tools/avatar_tablet.py` `Newspaper`, M5 id range 1,000,000+):

- **Art**: a folded broadsheet on the tablet's 280 × 190 footprint (two pages, a centre fold shade,
  generated headline bars, two + three columns of type as one multi-rectangle shape each, a photo
  block, a 3.5 px page-stack edge), projected by the tablet's own plane (SVD nodes), hung in
  `BreathShoulderLPivot` behind the tablet and both arms. Colours fitted to the scene script; no
  `emit*` paint.
- **Clips**: the tablet's out / hold / away data (grips, hand targets, chain lengths, timing) renamed
  `prop_newspaper_*`; no list scroll; the face-light track drives `PageShadow` (a face-clipped
  multiply pool under the chin, 0 → 0.5) instead of a screen glow; no lens reflections.
- **Layer**: the newspaper's three states join the existing `Prop` layer (no tablet id moves):
  none → newspaper out on `newspaper`; each prop's out / hold go to its own put-away on `none` *or
  the other prop*; a put-away hands over only at its end (→ none → the other's out). The two props
  never show together, even if the app writes one straight after the other.

Gates (`gates.txt`): hold seam 0/255; IK hand ≤ 1.23 px (elbow ≤ 1.08); no interruption step
above 1.05 × the largest step of the clips involved (newspaper 10.40, tablet 12.02, the wave
under the tablet's put-away 12.56). The hand-overs: largest steps 9.36 / 10.40 / 12.02 (the last is
the tablet's own put-away frame).

Self-check (ruling 11, one Sonnet pass over the sheets, the interrupt strips and the gates): no
objective defect; hands on the paper in every held frame; the two props never visible together in
the three hand-over strips; the page shadow is subtle at sheet size.

Known limits: a gesture started during a put-away (newspaper or tablet alike) snaps its arm up when
the put-away ends (11.03 mean-abs step at frame 30, identical for the tablet: the shared `Prop`
layer, not this prop; the M4 tablet gate hid it under its larger reference); the newspaper does not
flutter or turn a page in the hold (the arms keep the tablet's thumb flick).
