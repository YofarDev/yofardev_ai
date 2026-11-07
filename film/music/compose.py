"""The film's original score: a storybook-night cue in D major, 96 BPM, 4/4.

One bar = 2.5 s = 150 frames. The bar map comes from the edit
(sections.json, printed by `npx tsx scripts/sections.ts` in film/video): each
section keeps its musical role, its length follows the footage. Each
instrument group is its own MIDI, rendered to its own stem by fluidsynth
(MuseScore_General.sf3, MIT), then mixed and mastered in mix.py.

    uv run --with pretty_midi --with numpy python compose.py
"""

import json
import random
import subprocess
from pathlib import Path

import pretty_midi

BPM = 96
BEAT = 60 / BPM
BAR = 4 * BEAT
HERE = Path(__file__).parent
SF = HERE.parent / "work" / "sf" / "MuseScore_General.sf3"
STEMS = HERE / "stems"
STEMS.mkdir(exist_ok=True)
rng = random.Random(7)

SECTIONS = json.loads((HERE / "sections.json").read_text())
SEC = {s["id"]: s for s in SECTIONS}
TAIL = 3  # bars of ring-out after the edit's last bar
NBARS = sum(s["bars"] for s in SECTIONS) + TAIL

N = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
     "G#": 8, "A": 9, "A#": 10, "B": 11}
CHORDS = {
    "Dmaj9": ("D", [0, 4, 7, 11, 14]),
    "D": ("D", [0, 4, 7, 12]),
    "Dadd9": ("D", [0, 4, 7, 14]),
    "Bm7": ("B", [0, 3, 7, 10]),
    "Bm": ("B", [0, 3, 7, 12]),
    "Gmaj7": ("G", [0, 4, 7, 11]),
    "G": ("G", [0, 4, 7, 12]),
    "Asus4": ("A", [0, 5, 7, 12]),
    "A": ("A", [0, 4, 7, 12]),
    "A/C#": ("C#", [0, 3, 8, 12]),
    "F#m": ("F#", [0, 3, 7, 12]),
    "Em7": ("E", [0, 3, 7, 10]),
    "G/D": ("D", [0, 5, 9, 12]),
}

# each section's chord cycle (repeated / cut to its length)
CYCLES = {
    "cold": ["Dmaj9", "Bm7", "Gmaj7", "Asus4"],
    "title": ["Dadd9", "G/D"],
    "listen": ["D", "Bm", "G", "A", "D", "F#m", "G", "A"],
    "tools": ["Bm", "G", "D", "A", "D", "Bm", "G", "A"],
    "wardrobe": ["G", "A", "F#m", "Bm", "G", "A"],
    "journey": ["Em7", "G", "D", "A", "Em7", "G", "Asus4", "A"],
    "world": ["D", "A/C#", "Bm", "G", "D", "A", "G", "A"],
    "hood": ["Bm", "G", "Asus4", "A"],
    "finale": ["D", "G", "Em7", "A", "D", "G", "Em7", "A"],
}

PROG = []
ROLE = []  # (section id, index within section, section length)
for s in SECTIONS:
    cyc = CYCLES[s["id"]]
    n = s["bars"]
    for k in range(n):
        name = cyc[k % len(cyc)]
        if s["id"] == "journey" and k == n - 1:
            name = "A"  # the dominant before the climax
        if s["id"] == "journey" and k == n - 2 and n >= 3:
            name = "Asus4"
        if s["id"] == "finale" and k >= n - 3:
            name = "Dmaj9"  # the end card: home
        PROG.append(name)
        ROLE.append((s["id"], k, n))
for k in range(TAIL):
    PROG.append("Dmaj9")
    ROLE.append(("tail", k, TAIL))


def t(bar, beat=0.0):
    """Seconds at a 1-indexed bar and a 0-indexed beat."""
    return (bar - 1) * BAR + beat * BEAT


def bars_of(sid):
    s = SEC[sid]
    return range(s["startBar"], s["startBar"] + s["bars"])


def root(bar, octave):
    name, _ = CHORDS[PROG[bar - 1]]
    return 12 * (octave + 1) + N[name]


def tones(bar, octave):
    name, offs = CHORDS[PROG[bar - 1]]
    base = 12 * (octave + 1) + N[name]
    return [base + o for o in offs]


def voiced(bar, low=55, high=74):
    out = set()
    for p in tones(bar, 3):
        q = p
        while q < low:
            q += 12
        while q > high:
            q -= 12
        out.add(q)
    return sorted(out)


def pn(name):
    return pretty_midi.note_name_to_number(name)


class Stem:
    def __init__(self, name):
        self.name = name
        self.pm = pretty_midi.PrettyMIDI(initial_tempo=BPM)
        self.parts = {}

    def inst(self, program, key=None, drum=False):
        key = key or (program, drum)
        if key not in self.parts:
            i = pretty_midi.Instrument(program=program, is_drum=drum, name=str(key))
            self.pm.instruments.append(i)
            self.parts[key] = i
        return self.parts[key]

    def note(self, program, pitch, start, dur, vel, key=None, drum=False, human=True):
        if human:
            start += rng.uniform(-0.008, 0.008)
            vel += rng.randint(-5, 5)
        vel = max(1, min(127, int(vel)))
        start = max(0.0, start)
        self.inst(program, key, drum).notes.append(
            pretty_midi.Note(vel, int(pitch), start, start + dur))

    def cc(self, program, number, value, time, key=None):
        self.inst(program, key).control_changes.append(
            pretty_midi.ControlChange(number, int(value), time))

    def render(self):
        mid = STEMS / f"{self.name}.mid"
        wav = STEMS / f"{self.name}.wav"
        self.pm.write(str(mid))
        subprocess.run(
            ["fluidsynth", "-ni", "-R", "0", "-C", "0", "-g", "0.5",
             "-r", "48000", "-F", str(wav), str(SF), str(mid)],
            check=True, capture_output=True)
        return wav


PIANO, CELESTA, GLOCK, MUSICBOX, HARP = 0, 8, 9, 10, 46
PIZZ, STRINGS, SLOWSTR, CELLO, CONTRA = 45, 48, 49, 42, 43
FLUTE, CLARINET, HORN, TIMP, CHOIR, PAD = 73, 71, 60, 47, 52, 89
KICK, SNARE, SIDE, CLAP, CRASH, RIDE, SHAKER, TRI = 36, 38, 37, 39, 49, 51, 82, 81
TOM_L, TOM_M, TOM_H, SPLASH = 41, 45, 48, 52

THEME = {
    0: [(0, "F#5", 1), (1, "A5", 1), (2, "D6", 2)],
    1: [(0, "C#6", 1), (1, "B5", 1), (2, "A5", 1), (3, "F#5", 1)],
    2: [(0, "G5", 1.5), (1.5, "A5", 0.5), (2, "B5", 1), (3, "D6", 1)],
    3: [(0, "C#6", 2), (2, "A5", 2)],
}
THEME2 = {
    0: [(0, "F#5", 1), (1, "A5", 1), (2, "D6", 1.5), (3.5, "E6", 0.5)],
    1: [(0, "F#6", 1), (1, "E6", 1), (2, "D6", 1), (3, "C#6", 1)],
    2: [(0, "B5", 1.5), (1.5, "A5", 0.5), (2, "G5", 1), (3, "B5", 1)],
    3: [(0, "A5", 3), (3, "A5", 0.5), (3.5, "B5", 0.5)],
}
INTRO = [
    [(0, "A5"), (0.5, "D6"), (1, "F#6"), (1.5, "E6"), (2, "D6"), (3, "A5"), (3.5, "B5")],
    [(0, "F#5"), (0.5, "B5"), (1, "D6"), (1.5, "C#6"), (2, "B5"), (3, "F#5"), (3.5, "G5")],
    [(0, "G5"), (0.5, "B5"), (1, "D6"), (1.5, "F#6"), (2, "E6"), (3, "D6"), (3.5, "B5")],
    [(0, "A5"), (1, "D6"), (2, "E6"), (3, "C#6")],
]


def theme_line(k):
    """The theme's bar for the k-th bar of a melodic passage (8-bar form)."""
    return (THEME if (k // 4) % 2 == 0 else THEME2)[k % 4]


def fits(bar, line):
    """Drop long theme notes that rub a semitone against the bar's chord."""
    pcs = {p % 12 for p in tones(bar, 3)}
    out = []
    for b, n, d in line:
        pc = pn(n) % 12
        clash = pc not in pcs and any((pc - p) % 12 in (1, 11) for p in pcs)
        if clash and d >= 1:
            continue
        out.append((b, n, d))
    return out


keys, bells, strings, pizz, winds, air, perc = (
    Stem(n) for n in ("keys", "bells", "strings", "pizz", "winds", "air", "perc"))

# ============================================================== cold (intro)
c0 = SEC["cold"]["startBar"]
for i, line in enumerate(INTRO):
    for beat, name in line:
        bells.note(CELESTA, pn(name), t(c0 + i, beat), BEAT * 1.5, 66 if i < 3 else 58)
for b in bars_of("cold"):
    for p in voiced(b, 45, 62):
        air.note(PAD, p, t(b), BAR, 52, human=False)
    for p in voiced(b, 50, 69):
        strings.note(SLOWSTR, p, t(b), BAR + 0.05, 44, human=False)
for b in (c0 + 2, c0 + 3):
    for k, p in enumerate(voiced(b, 50, 66)):
        keys.note(PIANO, p, t(b, k * 0.5), BAR - k * 0.5 * BEAT, 38)
# timpani roll into the title hit
for k in range(16):
    perc.note(TIMP, root(c0 + 3, 2), t(c0 + 3, 2 + k * 0.125), 0.12, 40 + k * 4)

# ============================================================== title (hit)
h = SEC["title"]["startBar"]
keys.note(PIANO, root(h, 1), t(h), BAR * 2, 92)
keys.note(PIANO, root(h, 2), t(h), BAR * 2, 84)
for p in voiced(h, 62, 78):
    keys.note(PIANO, p, t(h), BAR * 2, 70)
for k, name in enumerate(["D6", "F#6", "A6", "D7", "E7", "F#7"]):
    bells.note(GLOCK, pn(name), t(h, k * 0.25), BEAT * 2, 70 - k * 3)
for b in bars_of("title"):
    for p in voiced(b, 50, 74):
        strings.note(STRINGS, p, t(b), BAR + 0.05, 84 if b == h else 70, human=False)
    strings.note(CONTRA, root(b, 1), t(b), BAR, 90, human=False)
perc.note(TIMP, root(h, 2), t(h), BAR, 112)
perc.note(0, CRASH, t(h), 2.5, 96, drum=True)
perc.note(0, KICK, t(h), 0.5, 110, drum=True)
for p in voiced(h + 1, 62, 79):
    air.note(CHOIR, p, t(h + 1), BAR, 46, human=False)

# ============================================================== verses
for sid in ("listen", "tools"):
    first = SEC[sid]["startBar"]
    for b in bars_of(sid):
        k = b - first
        # piano arpeggios
        ch = voiced(b, 57, 76)
        pattern = [ch[0], ch[1], ch[2], ch[-1], ch[2], ch[1], ch[2], ch[-1]]
        v = 46 if sid == "listen" else 50
        keys.note(PIANO, root(b, 2), t(b), BAR * 0.95, v + 8)
        for j, p in enumerate(pattern):
            keys.note(PIANO, p, t(b, j * 0.5), BEAT * 0.9, v - (6 if j % 2 else 0))
        # pizzicato: quarters for the first two bars of the verse, then 8ths
        pc = voiced(b, 50, 69)
        seq = [root(b, 2), pc[-1], pc[1], pc[-1], root(b, 2) + 12, pc[-1], pc[1], pc[2]]
        for j, p in enumerate(seq):
            if sid == "listen" and k < 2 and j % 2:
                continue
            pizz.note(PIZZ, p, t(b, j * 0.5), BEAT * 0.4, 64 - (8 if j % 2 else 0))
        # pad + bass
        for p in voiced(b, 52, 71):
            strings.note(SLOWSTR, p, t(b), BAR + 0.05, 50, human=False)
        strings.note(CONTRA, root(b, 1), t(b), BAR, 56, human=False)
        # melody: flute in listen (from its 2nd bar), clarinet an octave down in tools
        if sid == "listen" and k >= 1:
            for beat, name, d in fits(b, theme_line(k - 1)):
                winds.note(FLUTE, pn(name), t(b, beat), BEAT * d * 0.95, 68)
        if sid == "tools":
            for beat, name, d in fits(b, theme_line(k + 4)):
                winds.note(CLARINET, pn(name) - 12, t(b, beat), BEAT * d * 0.95, 70)
                bells.note(CELESTA, pn(name) + 12, t(b, beat), BEAT * d, 40)
        # percussion: shaker throughout, soft kick + side stick in tools
        for j in range(8):
            perc.note(0, SHAKER, t(b, j * 0.5), 0.1, 44 if j % 2 else 56, drum=True)
        if sid == "tools" or k >= 4:
            perc.note(0, KICK, t(b), 0.3, 70, drum=True)
            perc.note(0, KICK, t(b, 2.5), 0.3, 54, drum=True)
            perc.note(0, SIDE, t(b, 1), 0.2, 44, drum=True)
            perc.note(0, SIDE, t(b, 3), 0.2, 50, drum=True)
        if k % 2 == 0:
            perc.note(0, TRI, t(b), 1.0, 38, drum=True)

# ============================================================== wardrobe
w0 = SEC["wardrobe"]["startBar"]
for b in bars_of("wardrobe"):
    ch = voiced(b, 57, 76)
    keys.note(PIANO, root(b, 2), t(b), BAR * 0.95, 58)
    for j, p in enumerate([ch[0], ch[1], ch[2], ch[-1], ch[2], ch[1], ch[2], ch[-1]]):
        keys.note(PIANO, p, t(b, j * 0.5), BEAT * 0.5, 52)
    pc = voiced(b, 50, 69)
    for j, p in enumerate([root(b, 2), pc[-1], pc[1], pc[-1], root(b, 2) + 12, pc[-1], pc[1], pc[2]]):
        pizz.note(PIZZ, p, t(b, j * 0.5), BEAT * 0.4, 74 - (8 if j % 2 else 0))
    cl = voiced(b, 62, 79)
    for j, p in enumerate([cl[0], cl[1], cl[2], cl[1], cl[-1], cl[2], cl[1], cl[0]]):
        winds.note(CLARINET, p, t(b, j * 0.5), BEAT * 0.3, 64)
    for j, p in enumerate(voiced(b, 79, 93)):
        bells.note(GLOCK, p, t(b, 0.5 + j), BEAT * 0.3, 52)
    for p in voiced(b, 52, 71):
        strings.note(SLOWSTR, p, t(b), BAR + 0.05, 56, human=False)
    strings.note(CONTRA, root(b, 1), t(b), BAR, 60, human=False)
    perc.note(0, KICK, t(b), 0.3, 76, drum=True)
    perc.note(0, KICK, t(b, 2.5), 0.3, 60, drum=True)
    for beat in (1, 3):
        perc.note(0, CLAP, t(b, beat), 0.2, 70, drum=True)
    for j in range(8):
        perc.note(0, SHAKER, t(b, j * 0.5), 0.1, 48 if j % 2 else 60, drum=True)

# ============================================================== journey build
j0 = SEC["journey"]["startBar"]
jn = SEC["journey"]["bars"]
for b in bars_of("journey"):
    k = b - j0
    x = k / max(1, jn - 1)  # 0 -> 1 over the section
    ch = voiced(b, 57, 76)
    v = int(50 + 26 * x)
    keys.note(PIANO, root(b, 2), t(b), BAR * 0.95, v + 8)
    for j, p in enumerate([ch[0], ch[1], ch[2], ch[-1], ch[2], ch[1], ch[2], ch[-1]]):
        keys.note(PIANO, p, t(b, j * 0.5), BEAT * 0.9, v)
    for p in voiced(b, 50, 76):
        strings.note(STRINGS, p, t(b), BAR + 0.05, int(56 + 40 * x), human=False)
    strings.note(CONTRA, root(b, 1), t(b), BAR, int(60 + 30 * x), human=False)
    pc = voiced(b, 50, 69)
    for j in range(8):
        pizz.note(PIZZ, [root(b, 2), pc[-1], pc[1], pc[-1]][j % 4], t(b, j * 0.5), BEAT * 0.4, 66)
    if k >= jn // 2:
        for beat in range(4):
            perc.note(TIMP, root(b, 2), t(b, beat), 0.4, int(50 + 40 * x) + beat * 3)
    else:
        for j in range(8):
            perc.note(0, SHAKER, t(b, j * 0.5), 0.1, 48 if j % 2 else 58, drum=True)
        perc.note(0, KICK, t(b), 0.3, 66, drum=True)
    # the theme returns in the horn, broad, over the build
    for beat, name, d in fits(b, theme_line(k)):
        winds.note(HORN, pn(name) - 12, t(b, beat), BEAT * d * 0.95, int(56 + 30 * x))
for i in range(80):
    xx = i / 79
    strings.cc(STRINGS, 11, 70 + 57 * xx, t(j0) + xx * jn * BAR)
lb = j0 + jn - 1
for k, d in enumerate([TOM_H, TOM_H, TOM_M, TOM_M, TOM_L, TOM_L, TOM_L, TOM_L]):
    perc.note(0, d, t(lb, 2 + k * 0.25), 0.2, 80 + k * 4, drum=True)
for k, name in enumerate(["A4", "C#5", "E5", "A5", "C#6", "E6", "A6", "C#7"]):
    bells.note(HARP, pn(name), t(lb, 2 + k * 0.25), BEAT, 70)

# ============================================================== world (climax)
w0 = SEC["world"]["startBar"]
strings.cc(STRINGS, 11, 120, t(w0))
for b in bars_of("world"):
    k = b - w0
    keys.note(PIANO, root(b, 1), t(b), BAR, 86)
    keys.note(PIANO, root(b, 2), t(b), BAR, 80)
    for beat in (0, 2, 3.5):
        for p in voiced(b, 64, 81):
            keys.note(PIANO, p, t(b, beat), BEAT * (1.8 if beat < 3 else 0.45), 66)
    for beat, name, d in theme_line(k):
        strings.note(STRINGS, pn(name), t(b, beat), BEAT * d * 0.98, 104, key="vln1")
        strings.note(STRINGS, pn(name) - 12, t(b, beat), BEAT * d * 0.98, 90, key="vln2")
        winds.note(FLUTE, pn(name) + 12, t(b, beat), BEAT * d * 0.95, 70)
    for j in range(8):
        strings.note(CELLO, root(b, 2) if j % 2 == 0 else root(b, 2) + 7,
                     t(b, j * 0.5), BEAT * 0.45, 92 if j % 2 == 0 else 78)
    strings.note(CONTRA, root(b, 1), t(b), BAR, 96, human=False)
    for p in voiced(b, 55, 74):
        strings.note(SLOWSTR, p, t(b), BAR + 0.05, 76, human=False)
    for p in voiced(b, 53, 67):
        winds.note(HORN, p, t(b), BAR * 0.98, 82)
    for p in voiced(b, 60, 76):
        air.note(CHOIR, p, t(b), BAR, 58, human=False)
    if k % 2 == 0:
        for j, p in enumerate(voiced(b, 81, 98)):
            bells.note(GLOCK, p, t(b, j * 0.25), BEAT, 54)
    if k % 4 == 0:
        perc.note(0, CRASH, t(b), 3, 100, drum=True)
        perc.note(TIMP, root(b, 2), t(b), BAR, 110)
    perc.note(0, KICK, t(b), 0.3, 104, drum=True)
    perc.note(0, KICK, t(b, 1.5), 0.3, 84, drum=True)
    perc.note(0, KICK, t(b, 2.5), 0.3, 92, drum=True)
    perc.note(0, SNARE, t(b, 1), 0.3, 84, drum=True)
    perc.note(0, SNARE, t(b, 3), 0.3, 90, drum=True)
    for j in range(8):
        perc.note(0, RIDE, t(b, j * 0.5), 0.3, 58 if j % 2 else 70, drum=True)
lw = w0 + SEC["world"]["bars"] - 1
for k, d in enumerate([TOM_H, TOM_M, TOM_M, TOM_L, TOM_L, TOM_L]):
    perc.note(0, d, t(lw, 2.5 + k * 0.25), 0.2, 84 + k * 5, drum=True)

# ============================================================== hood (breakdown)
hb = SEC["hood"]["startBar"]
for i, b in enumerate(bars_of("hood")):
    for j in range(8):
        keys.note(PIANO, voiced(b, 69, 81)[-1], t(b, j * 0.5), BEAT * 0.45, 46 if j % 2 == 0 else 34)
    for beat, name in INTRO[(i + 1) % 4]:
        bells.note(MUSICBOX, pn(name), t(b, beat), BEAT * 1.5, 62)
    for p in voiced(b, 62, 81):
        strings.note(SLOWSTR, p, t(b), BAR + 0.05, 44, human=False)
    for p in voiced(b, 50, 66):
        air.note(PAD, p, t(b), BAR, 70, human=False)
    perc.note(0, KICK, t(b), 0.3, 64, drum=True)
    perc.note(0, KICK, t(b, 0.6), 0.3, 50, drum=True)
for k in range(12):
    perc.note(TIMP, root(hb + 2, 2), t(hb + 2, 2 + k * 0.166), 0.15, 30 + k * 3)

# ============================================================== finale
f0 = SEC["finale"]["startBar"]
fn = SEC["finale"]["bars"]
card = f0 + fn - 3  # the end card's downbeat: home
for b in range(f0, card):
    k = b - f0
    for j, p in enumerate(voiced(b, 50, 74)):
        keys.note(PIANO, p, t(b, j * 0.25), BAR - j * 0.25 * BEAT, 50)
    for p in voiced(b, 50, 74):
        strings.note(SLOWSTR, p, t(b), BAR + 0.05, 56, human=False)
    strings.note(CONTRA, root(b, 1), t(b), BAR, 58, human=False)
    for j in range(4):
        pizz.note(PIZZ, voiced(b, 50, 69)[j % 3], t(b, j), BEAT * 0.4, 50)
    if k < 4:
        for beat, name in INTRO[k % 4]:
            bells.note(CELESTA, pn(name), t(b, beat), BEAT * 1.6, 58)
# the last chord, rolled, ringing through the card and the tail
for k, p in enumerate([root(card, 1), root(card, 2)] + voiced(card, 57, 81)):
    keys.note(PIANO, p, t(card, k * 0.12), BAR * 5, 62 - k * 2)
for p in voiced(card, 50, 81):
    strings.note(SLOWSTR, p, t(card), BAR * 5, 60, human=False)
strings.note(CONTRA, root(card, 1), t(card), BAR * 5, 64, human=False)
for p in voiced(card, 50, 66):
    winds.note(HORN, p, t(card), BAR * 3, 58)
for p in voiced(card, 62, 79):
    air.note(CHOIR, p, t(card), BAR * 4, 50, human=False)
bells.note(CELESTA, pn("A6"), t(card), BAR, 50)
bells.note(CELESTA, pn("D7"), t(card, 1), BAR * 2, 46)
bells.note(GLOCK, pn("D7"), t(card, 2), BAR * 2, 40)
perc.note(TIMP, root(card, 2), t(card), BAR * 2, 70)
perc.note(0, SPLASH, t(card), 4, 50, drum=True)
for k in range(12):
    perc.note(TIMP, root(card, 2), t(card - 1, 2 + k * 0.166), 0.15, 30 + k * 3)

for stem in (keys, bells, strings, pizz, winds, air, perc):
    print("rendered", stem.render())
print("bars", NBARS, "seconds", NBARS * BAR)
