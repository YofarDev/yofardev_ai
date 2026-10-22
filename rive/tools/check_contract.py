"""Contract self-check: every name in rive/CONTRACT.md must match what the CLI built.

Reads the contract tables, runs `rive inspect --json` on each project, and also
greps the shipped .riv bytes in assets/rive/ so a stale copy fails too.
Exit code 1 on any mismatch. Run by scripts/frive.sh.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "rive" / "CONTRACT.md"
errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def ticks(s: str) -> list[str]:
    return re.findall(r"`([^`]+)`", s)


def table_after(text: str, heading_regex: str) -> list[list[str]]:
    """Rows (cells) of the first markdown table after the heading/line matching heading_regex."""
    m = re.search(heading_regex, text, re.M)
    assert m, heading_regex
    rows = []
    started = False
    for line in text[m.start():].splitlines()[(0 if m.group(0).startswith("|") else 1):]:
        if line.startswith("|"):
            started = True
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if set("".join(cells)) <= set("-: "):
                continue
            rows.append(cells)
        elif started:
            break
    return rows[1:]  # drop header


def parse_contract() -> dict:
    text = CONTRACT.read_text()
    avatar_sec = text[text.index("## `assets/rive/avatar.riv`"):text.index("## `assets/rive/scenes/")]
    scene_sec = text[text.index("## `assets/rive/scenes/"):]
    c: dict = {}
    c["avatar_artboard"] = ticks(re.search(r"\*\*Artboard:\*\*.*", avatar_sec).group(0))[0]
    c["avatar_sm"] = ticks(re.search(r"\*\*State machine:\*\*.*", avatar_sec).group(0))[0]
    c["avatar_vm"] = ticks(re.search(r"\*\*View model:\*\*.*", avatar_sec).group(0))[0]
    props = {}
    for prop, typ, vals in table_after(avatar_sec, r"^\| Property"):
        name = ticks(prop)[0]
        values = None
        if typ == "enum":
            vals = re.sub(r"\(.*?\)", "", vals)          # drop notes like "(same as `TalkingPhase`)"
            values = [v.strip() for v in vals.split(". ")[0].rstrip(".").split(",")]
        props[name] = (typ, values)
    c["avatar_props"] = props
    events = {}
    for ev, ps in table_after(avatar_sec, r"\*\*Rive events emitted:\*\*"):
        events[ticks(ev)[0]] = ticks(ps)[0]
    c["avatar_events"] = events
    c["scene_artboard"] = ticks(re.search(r"\*\*Artboard:\*\*.*", scene_sec).group(0))[0]
    c["scene_sm"] = ticks(re.search(r"\*\*State machine:\*\*.*", scene_sec).group(0))[0]
    c["scene_vm"] = ticks(re.search(r"\*\*View model:\*\*.*", scene_sec).group(0))[0]
    c["scene_event_name"], c["scene_event_prop"] = ticks(re.search(r"\*\*Rive event emitted:\*\*.*", scene_sec).group(0))[:2]
    scenes = {}
    for sid, evs, pids in table_after(scene_sec, r"^\| sceneId"):
        scenes[sid] = ([v.strip() for v in evs.split(",")], [v.strip() for v in pids.split(",")])
    c["scenes"] = scenes
    return c


def inspect(project: Path) -> dict:
    out = subprocess.run(["rive", "inspect", str(project), "--json"], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def nodes(o: object, typ: str | None = None) -> list[dict]:
    found = []
    if isinstance(o, dict):
        if typ is None or o.get("type") == typ:
            found.append(o)
        for v in o.values():
            found += nodes(v, typ)
    elif isinstance(o, list):
        for v in o:
            found += nodes(v, typ)
    return found


TYPE_OF = {"enum": "ViewModelPropertyEnumCustom", "number": "ViewModelPropertyNumber", "trigger": "ViewModelPropertyTrigger"}


def check_common(label: str, j: dict, artboard: str, sm: str, vm_name: str) -> tuple[dict, dict]:
    if j.get("problems"):
        err(f"{label}: inspect problems: {j['problems']}")
    if any(n.get("type", "").endswith("ImageAsset") or n.get("type") == "Image" for n in nodes(j)):
        err(f"{label}: embedded raster image (budget: vector only)")
    abs_ = [a for a in j["artboards"] if a.get("name") == artboard]
    if len(abs_) != 1:
        err(f"{label}: expected one artboard `{artboard}`, got {[a.get('name') for a in j['artboards']]}")
        return {}, {}
    ab = abs_[0]
    sms = {s["id"]: s for s in nodes(ab, "StateMachine")}
    if sms.get(ab.get("defaultStateMachineId"), {}).get("name") != sm:
        err(f"{label}: default state machine is not `{sm}`")
    vms = {v["id"]: v for v in nodes(j["roots"], "ViewModel")}
    vm = vms.get(ab.get("viewModelId"))
    if not vm or vm.get("name") != vm_name:
        err(f"{label}: artboard view model is not `{vm_name}`")
        return ab, {}
    return ab, vm


def vm_props(j: dict, vm: dict) -> dict[str, tuple[str, list[str] | None]]:
    enums = {e["id"]: [v["key"] for v in e.get("children", []) if v.get("type") == "DataEnumValue"]
             for e in nodes(j["roots"], "DataEnumCustom")}
    out = {}
    for p in vm.get("children", []):
        if not p.get("type", "").startswith("ViewModelProperty"):
            continue
        out[p["name"]] = (p["type"], enums.get(p.get("enumId")))
    return out


def events_of(ab: dict) -> dict[str, list[dict[str, str]]]:
    out: dict[str, list[dict[str, str]]] = {}
    for e in nodes(ab, "Event"):
        payload = {c["name"]: c.get("propertyValue", "") for c in e.get("children", [])
                   if c.get("type") == "CustomPropertyString"}
        out.setdefault(e["name"], []).append(payload)
    return out


def check_riv_bytes(path: Path, names: list[str]) -> None:
    if not path.exists():
        err(f"missing built file {path.relative_to(ROOT)}")
        return
    blob = path.read_bytes()
    for n in names:
        if n.encode() not in blob:
            err(f"{path.relative_to(ROOT)}: name `{n}` not found in the built bytes (stale build?)")


def main() -> int:
    c = parse_contract()
    # ---------------- avatar
    j = inspect(ROOT / "rive" / "avatar")
    ab, vm = check_common("avatar", j, c["avatar_artboard"], c["avatar_sm"], c["avatar_vm"])
    if vm:
        got = vm_props(j, vm)
        if set(got) != set(c["avatar_props"]):
            err(f"avatar: properties differ: extra {set(got) - set(c['avatar_props'])}, "
                f"missing {set(c['avatar_props']) - set(got)}")
        for name, (typ, vals) in c["avatar_props"].items():
            if name not in got:
                continue
            gtyp, gvals = got[name]
            if gtyp != TYPE_OF[typ]:
                err(f"avatar: `{name}` is {gtyp}, contract says {typ}")
            if vals is not None and gvals != vals:
                err(f"avatar: `{name}` enum values {gvals} != contract {vals}")
    if ab:
        evs = events_of(ab)
        if set(evs) != set(c["avatar_events"]):
            err(f"avatar: events {sorted(evs)} != contract {sorted(c['avatar_events'])}")
        for ev, prop in c["avatar_events"].items():
            for payload in evs.get(ev, []):
                if prop not in payload:
                    err(f"avatar: event `{ev}` lacks string property `{prop}`")
        # every enum value that an event reports must be covered
        cover = {"gesture_done": ("gestureId", c["avatar_props"]["gestureId"][1]),
                 "presence_done": ("presence", c["avatar_props"]["presence"][1]),
                 "avatar_tapped": ("zone", ["head", "body"])}
        for ev, (prop, vals) in cover.items():
            seen = {p.get(prop) for p in evs.get(ev, [])}
            if set(vals) != seen:
                err(f"avatar: `{ev}` reports {sorted(seen)}, expected {sorted(vals)}")
    check_riv_bytes(ROOT / "assets" / "rive" / "avatar.riv",
                    [c["avatar_artboard"], c["avatar_sm"], c["avatar_vm"], *c["avatar_props"], *c["avatar_events"]])
    # ---------------- scenes
    for sid, (ev_vals, prop_ids) in c["scenes"].items():
        proj = ROOT / "rive" / "scenes" / sid
        if not proj.exists():
            err(f"scene `{sid}`: no project at {proj.relative_to(ROOT)}")
            continue
        j = inspect(proj)
        ab, vm = check_common(sid, j, c["scene_artboard"], c["scene_sm"], c["scene_vm"])
        if vm:
            got = vm_props(j, vm)
            want = {"eventId": ("ViewModelPropertyEnumCustom", ev_vals), "event": ("ViewModelPropertyTrigger", None)}
            if got != want:
                err(f"{sid}: SceneVM {got} != {want}")
        if ab:
            evs = events_of(ab)
            if set(evs) != {c["scene_event_name"]}:
                err(f"{sid}: events {sorted(evs)} != [`{c['scene_event_name']}`]")
            seen = sorted(p.get(c["scene_event_prop"], "") for p in evs.get(c["scene_event_name"], []))
            if seen != sorted(prop_ids):
                err(f"{sid}: propIds {seen} != contract {sorted(prop_ids)}")
        check_riv_bytes(ROOT / "assets" / "rive" / "scenes" / f"{sid}.riv",
                        [c["scene_artboard"], c["scene_sm"], c["scene_vm"], c["scene_event_name"], *ev_vals, *prop_ids])
    extra = {p.stem for p in (ROOT / "assets" / "rive" / "scenes").glob("*.riv")} - set(c["scenes"])
    if extra:
        err(f"scenes not in the contract: {sorted(extra)}")
    if errors:
        print("✗ contract self-check failed:")
        for e in errors:
            print("  -", e)
        return 1
    print(f"✓ contract self-check: avatar + {len(c['scenes'])} scenes match rive/CONTRACT.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
