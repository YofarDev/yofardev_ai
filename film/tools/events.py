"""Indexes every captured run's timeline for the edit: events (send, start,
stop, caption, journey phases, gestures, pokes, drags) and spoken sentences,
keyed by run tag, into video/src/data/events.json.

    python3 film/tools/events.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAP = ROOT / "work" / "cap"
CLIPS = ROOT / "work" / "clips"
OUT = ROOT / "video" / "src" / "data" / "events.json"

KEEP = {"typing", "send", "start", "stop", "preroll", "caption", "gesture",
        "gestureDone", "poke", "gullPoke", "drag", "dragStart", "dragEnd",
        "sceneEvent", "journey", "dragPoint", "turn", "turnEnd", "foley", "presenceDone"}


def main():
    data = json.loads(OUT.read_text()) if OUT.exists() else {}
    for tag_dir in sorted(p for p in CAP.iterdir() if p.is_dir()):
        tag = tag_dir.name
        if not (CLIPS / f"{tag}.json").exists():
            continue  # not synced yet
        try:
            run = next((tag_dir / "wow").iterdir())
            tl = json.loads((run / "timeline.json").read_text())
        except (StopIteration, FileNotFoundError):
            continue  # being re-captured
        events = [
            {k: v for k, v in e.items() if k in ("ms", "type", "text", "name", "label", "kind", "i", "to", "from", "prop", "x", "y", "id")}
            for e in tl["events"] if e["type"] in KEEP
        ]
        # journey phases from the samples (phase changes)
        last = None
        for s in tl["samples"]:
            ph = s.get("journey")
            if ph != last:
                events.append({"ms": s["ms"], "type": "phase", "name": ph or "none"})
                last = ph
        events.sort(key=lambda e: e["ms"])
        clip = json.loads((CLIPS / f"{tag}.json").read_text())
        data[tag] = {"events": events, "duration": clip["duration"],
                     "audio": [a["text"] for a in tl["audio"]]}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, indent=1))
    print("indexed", sorted(data))


if __name__ == "__main__":
    main()
