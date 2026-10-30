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
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import art_bible  # noqa: E402

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
    ui_at = text.index("## `assets/rive/ui/ui_kit.riv`")
    scene_sec = text[text.index("## `assets/rive/scenes/"):ui_at]
    ui_sec = text[ui_at:]
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
    c["scene_vm_props"] = scene_vm_props(scene_sec)
    c["scene_event_name"], c["scene_event_prop"] = ticks(re.search(r"\*\*Rive event emitted:\*\*.*", scene_sec).group(0))[:2]
    scenes = {}
    for sid, evs, pids in table_after(scene_sec, r"^\| sceneId"):
        scenes[sid] = ([v.strip() for v in evs.split(",")], [v.strip() for v in pids.split(",")])
    c["scenes"] = scenes
    # v9: which scenes carry the `SceneFront` artboard ("campfire and beach have one; ...")
    flat = " ".join(scene_sec.split())
    m = re.search(r"may carry a second artboard `(\w+)`", flat)
    have = re.search(r"\. ([\w, ]+?) have one;", flat)
    c["front_artboard"] = m.group(1) if m else None
    c["front_scenes"] = {s.strip() for s in re.split(r",| and ", have.group(1)) if s.strip()} if have else set()
    ui: dict[str, dict] = {}
    for ab, size, prop, typ, vals in table_after(ui_sec, r"^\| Artboard"):
        a = ui.setdefault(ticks(ab)[0], {"size": tuple(int(v) for v in size.split("×")), "props": {}})
        values = [v.strip() for v in vals.split(",")] if typ == "enum" else None
        a["props"][ticks(prop)[0]] = (typ, values)
    c["ui"] = ui
    # v10: the journey overlay (its own section, last in the file)
    j_at = text.find("## `assets/rive/journeys/journey.riv`")
    if j_at >= 0:
        j_sec = text[j_at:]
        c["journey"] = {
            "artboard": ticks(re.search(r"\*\*Artboard:\*\*.*", j_sec).group(0))[0],
            "size": tuple(int(v) for v in re.search(r"\*\*Artboard:\*\* `\w+`, (\d+)×(\d+)", j_sec).groups()),
            "sm": ticks(re.search(r"\*\*State machine:\*\*.*", j_sec).group(0))[0],
            "vm": ticks(re.search(r"\*\*View model:\*\*.*", j_sec).group(0))[0],
            "props": {ticks(prop)[0]: typ for prop, typ, _ in table_after(j_sec, r"^\| JourneyVM property")},
            "max": int(re.search(r"`journey.riv` \(v10\) must stay at or under (\d+) KB", text).group(1)) * 1024,
        }
    c["ui_max"] = int(re.search(r"`ui_kit.riv` must stay at or under (\d+) KB", text).group(1)) * 1024
    m = re.search(r"\*\*Scene posters:\*\* `assets/rive/posters/<sceneId>.webp`.*?(\d+)×(\d+), at most (\d+) KB", text, re.S)
    c["poster"] = (int(m.group(1)), int(m.group(2)), int(m.group(3)) * 1024)
    return c


def scene_vm_props(scene_sec: str) -> dict[str, str]:
    """The SceneVM bullets: `eventId` (enum), `event` (trigger), then every v7 number / colour. A
    bullet lists names in backticks; a "(type)" or ": type" after a run of names types that run."""
    vm_at = scene_sec.index("**View model:**")
    bullets = scene_sec[vm_at:scene_sec.index("**Rive event emitted:**")]
    props: dict[str, str] = {}
    for item in re.split(r"\n\s*- ", bullets)[1:]:
        item = " ".join(item.split())
        pending: list[str] = []
        for m in re.finditer(r"`([a-z]\w*)`|\((color|colors|number|numbers|enum|trigger)\)|^[^:]*?:\s*(enum|trigger|number|color)", item):
            name, typ = m.group(1), m.group(2) or m.group(3)
            if name:
                pending.append(name)
            elif typ and pending:
                for n in pending:
                    props[n] = typ.rstrip("s")
                pending = []
        if pending and not props.keys() >= set(pending):
            head = re.search(r":\s*(enum|trigger|number|color)", item)
            for n in pending:
                if head and n not in props:
                    props[n] = head.group(1)
    return props


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


TYPE_OF = {"enum": "ViewModelPropertyEnumCustom", "number": "ViewModelPropertyNumber", "trigger": "ViewModelPropertyTrigger",
           "color": "ViewModelPropertyColor", "boolean": "ViewModelPropertyBoolean"}
# rive_native 0.1.11's Drawable::onAddedDirty rejects additive (12), although
# CLI 1.7.0 accepts and renders it. One such shape makes the entire file null
# on import. Keep this aligned with the runtime before using newer blend modes.
NATIVE_BLEND_MODES = {3, *range(14, 29)}


def check_common(label: str, j: dict, artboard: str, sm: str, vm_name: str) -> tuple[dict, dict]:
    if j.get("problems"):
        err(f"{label}: inspect problems: {j['problems']}")
    if any(n.get("type", "").endswith("ImageAsset") or n.get("type") == "Image" for n in nodes(j)):
        err(f"{label}: embedded raster image (budget: vector only)")
    checked_shapes: set[str] = set()
    for n in nodes(j, "Shape"):
        shape_id = n.get("id")
        if shape_id is None or shape_id in checked_shapes:
            continue
        checked_shapes.add(shape_id)
        mode = n.get("blendModeValue")
        if isinstance(mode, int) and mode not in NATIVE_BLEND_MODES:
            err(f"{label}: `{n.get('name', n.get('id'))}` uses blend mode {mode}, unsupported by rive_native 0.1.11")
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


def scene_light_defaults(sid: str) -> dict[str, object]:
    """v7 defaults every scene file must carry (and the avatar, for livingRoom): art_bible.SCENES."""
    sc = art_bible.SCENES[sid]
    kx, ky = sc.key_xy
    return {"parallaxX": 0.0, "parallaxY": 0.0, "lightKey": sc.key, "lightKeyIntensity": sc.key_intensity,
            "lightKeyX": kx, "lightKeyY": ky, "lightRim": sc.rim, "lightRimIntensity": sc.rim_intensity,
            "lightAmbient": sc.ambient, "lightFog": sc.fog, "lightFlicker": sc.flicker}


def check_light_defaults(label: str, j: dict, vm: dict, want: dict[str, object]) -> None:
    """The default instance's values for the names in `want` (colours exact, numbers to 1e-4)."""
    by_id = {p["id"]: p["name"] for p in vm.get("children", []) if p.get("type", "").startswith("ViewModelProperty")}
    inst = next((i for i in nodes(vm, "ViewModelInstance")), None)
    got = {by_id.get(v.get("viewModelPropertyId")): v.get("propertyValue") for v in (inst or {}).get("children", [])}
    for name, val in want.items():
        g = got.get(name)
        if isinstance(val, str):
            ok = isinstance(g, str) and g.upper() == val.upper()
        else:
            ok = isinstance(g, (int, float)) and abs(float(g) - float(val)) < 1e-4
        if not ok:
            err(f"{label}: `{name}` default {g!r} != art_bible {val!r}")


def check_riv_bytes(path: Path, names: list[str]) -> None:
    if not path.exists():
        err(f"missing built file {path.relative_to(ROOT)}")
        return
    blob = path.read_bytes()
    for n in names:
        if n.encode() not in blob:
            err(f"{path.relative_to(ROOT)}: name `{n}` not found in the built bytes (stale build?)")


def check_ui_kit(c: dict) -> None:
    """Every UI-kit artboard: size, SM `Main`, VM `<Artboard>VM`, properties in contract order,
    no events/listeners, and every property actually consumed by a bind in the source RML."""
    proj = ROOT / "rive" / "ui_kit"
    if not proj.exists():
        err("ui_kit: no project at rive/ui_kit")
        return
    j = inspect(proj)
    got_boards = [a.get("name") for a in j["artboards"]]
    if sorted(got_boards) != sorted(c["ui"]):
        err(f"ui_kit: artboards {got_boards} != contract {list(c['ui'])}")
    src = ET.parse(proj / "ui_kit.rml").getroot()
    vm_ids = {v.get("name"): v.get("id") for v in src.findall("ViewModel")}
    for name, spec in c["ui"].items():
        ab, vm = check_common(f"ui_kit/{name}", j, name, "Main", f"{name}VM")
        if not ab:
            continue
        if (ab.get("width"), ab.get("height")) != spec["size"]:
            err(f"ui_kit/{name}: size {ab.get('width')}x{ab.get('height')} != contract {spec['size']}")
        if nodes(ab, "Event") or any(n.get("type", "").startswith("StateMachineListener") for n in nodes(ab)):
            err(f"ui_kit/{name}: has Rive events or listeners (the contract forbids both)")
        if not vm:
            continue
        got = vm_props(j, vm)
        if list(got) != list(spec["props"]):
            err(f"ui_kit/{name}: properties {list(got)} != contract order {list(spec['props'])}")
        for prop, (typ, vals) in spec["props"].items():
            if prop not in got:
                continue
            gtyp, gvals = got[prop]
            if gtyp != TYPE_OF[typ]:
                err(f"ui_kit/{name}: `{prop}` is {gtyp}, contract says {typ}")
            if vals is not None and gvals != vals:
                err(f"ui_kit/{name}: `{prop}` enum values {gvals} != contract {vals}")
        # binding proof in the source: each property feeds at least one DataBindContext
        board = next(a for a in src.findall("Artboard") if a.get("name") == name)
        vm_el = next(v for v in src.findall("ViewModel") if v.get("name") == f"{name}VM")
        used = {dbc.get("sourcePathIds", "").split("-")[-1] for dbc in board.iter("DataBindContext")
                if dbc.get("sourcePathIds", "").startswith(vm_ids[f"{name}VM"] + "-")}
        for p in vm_el:
            if p.tag.startswith("ViewModelProperty") and p.get("id") not in used:
                err(f"ui_kit/{name}: `{p.get('name')}` is declared but nothing binds to it")
    check_riv_bytes(ROOT / "assets" / "rive" / "ui" / "ui_kit.riv",
                    [n for name, spec in c["ui"].items() for n in (name, f"{name}VM", *spec["props"])] + ["Main"])
    out = ROOT / "assets" / "rive" / "ui" / "ui_kit.riv"
    if out.exists() and out.stat().st_size > c["ui_max"]:
        err(f"ui_kit.riv is {out.stat().st_size} bytes, budget {c['ui_max']}")
    w, h, kb = c["poster"]
    for sid in c["scenes"]:
        poster = ROOT / "assets" / "rive" / "posters" / f"{sid}.webp"
        if not poster.exists():
            err(f"missing poster {poster.relative_to(ROOT)}")
            continue
        size = poster.stat().st_size
        dims = webp_size(poster)
        if dims != (w, h) or size > kb:
            err(f"{poster.relative_to(ROOT)}: {dims} {size} B (contract {w}x{h}, <= {kb} B)")


def webp_size(path: Path) -> tuple[int, int] | None:
    b = path.read_bytes()
    if b[:4] != b"RIFF" or b[8:12] != b"WEBP":
        return None
    chunk = b[12:16]
    if chunk == b"VP8X":
        return 1 + int.from_bytes(b[24:27], "little"), 1 + int.from_bytes(b[27:30], "little")
    if chunk == b"VP8L":
        v = int.from_bytes(b[21:25], "little")
        return (v & 0x3FFF) + 1, ((v >> 14) & 0x3FFF) + 1
    if chunk == b"VP8 ":
        return int.from_bytes(b[26:28], "little") & 0x3FFF, int.from_bytes(b[28:30], "little") & 0x3FFF
    return None


def diorama_lint(rml_of: dict[str, str] | None = None) -> list[str]:
    """M5 Review Focus 5: every diorama scene (`gen_scenes.DIORAMAS`) lints clean against its
    colour script (`art_bible.lint_colours`); one message per scene with hits. `rml_of` overrides
    the committed RML per scene (tests)."""
    import gen_scenes  # noqa: PLC0415 (the generator pulls the scene art; only this check needs it)

    out = []
    for sid in gen_scenes.DIORAMAS:
        text = (rml_of or {}).get(sid)
        if text is None:
            text = (ROOT / "rive" / "scenes" / sid / f"{sid}.rml").read_text()
        problems = art_bible.lint_colours(text, sid)
        if problems:
            out.append(f"{sid}: colour-script lint, {len(problems)} hit(s), first {problems[0]}")
    return out


def check_front(sid: str, j: dict, c: dict, scene_vm: dict) -> None:
    """Contract v9: `SceneFront` exactly in the scenes the contract names, with a `Main` state
    machine, the scene's `SceneVM`, and no listeners or events (the app never hit-tests it)."""
    name = c["front_artboard"]
    if name is None or not c["front_scenes"]:
        err("contract: the v9 front artboard paragraph could not be parsed")
        return
    fronts = [a for a in j["artboards"] if a.get("name") == name]
    want = sid in c["front_scenes"]
    if len(fronts) != (1 if want else 0):
        err(f"{sid}: {len(fronts)} `{name}` artboards, contract wants {1 if want else 0}")
        return
    if not fronts:
        return
    ab = fronts[0]
    sms = {s["id"]: s for s in nodes(ab, "StateMachine")}
    if sms.get(ab.get("defaultStateMachineId"), {}).get("name") != c["scene_sm"]:
        err(f"{sid}: `{name}` default state machine is not `{c['scene_sm']}`")
    if scene_vm and ab.get("viewModelId") != scene_vm.get("id"):
        err(f"{sid}: `{name}` does not use `{c['scene_vm']}`")
    if any(n.get("type", "").startswith("StateMachineListener") or n.get("type") == "Event" for n in nodes(ab)):
        err(f"{sid}: `{name}` has listeners or events (the contract allows none)")


def check_journey(c: dict) -> None:
    """v10: `rive/journeys` builds the `Journey` artboard (size, `Main`, `JourneyVM` with exactly the
    contract's numbers and colours), with no listener and no event; the built file is in budget."""
    jc = c.get("journey")
    if jc is None:
        err("contract: the v10 journey section could not be parsed")
        return
    proj = ROOT / "rive" / "journeys"
    if not proj.exists():
        err(f"journey: no project at {proj.relative_to(ROOT)}")
        return
    j = inspect(proj)
    ab, vm = check_common("journey", j, jc["artboard"], jc["sm"], jc["vm"])
    if ab and (ab.get("width"), ab.get("height")) != jc["size"]:
        err(f"journey: artboard is {ab.get('width')}×{ab.get('height')}, contract says {jc['size']}")
    if vm:
        got = vm_props(j, vm)
        want = {n: (TYPE_OF[t], None) for n, t in jc["props"].items()}
        if got != want:
            err(f"journey: JourneyVM {got} != {want}")
    if ab and any(n.get("type", "").startswith("StateMachineListener") or n.get("type") == "Event" for n in nodes(ab)):
        err("journey: listeners or events (the contract allows none)")
    riv = ROOT / "assets" / "rive" / "journeys" / "journey.riv"
    check_riv_bytes(riv, [jc["artboard"], jc["sm"], jc["vm"], *jc["props"]])
    if riv.exists() and riv.stat().st_size > jc["max"]:
        err(f"journey: {riv.stat().st_size} B over the {jc['max']} B budget")


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
        rig = scene_light_defaults("livingRoom")
        check_light_defaults("avatar", j, vm, {k: v for k, v in rig.items()
                                                if k in c["avatar_props"] and not k.startswith("parallax")}
                             | {"lightAmbientAmount": art_bible.SCENES["livingRoom"].ambient_amount, "lean": 0.0})
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
            want = {n: (TYPE_OF[t], ev_vals if n == "eventId" else None) for n, t in c["scene_vm_props"].items()}
            if got != want:
                err(f"{sid}: SceneVM {got} != {want}")
            check_light_defaults(sid, j, vm, {**scene_light_defaults(sid), "rain": 0.0, "daylight": 0.0, "dusk": 0.0})
        if ab:
            evs = events_of(ab)
            if set(evs) != {c["scene_event_name"]}:
                err(f"{sid}: events {sorted(evs)} != [`{c['scene_event_name']}`]")
            seen = sorted(p.get(c["scene_event_prop"], "") for p in evs.get(c["scene_event_name"], []))
            if seen != sorted(prop_ids):
                err(f"{sid}: propIds {seen} != contract {sorted(prop_ids)}")
        check_front(sid, j, c, vm)
        check_riv_bytes(ROOT / "assets" / "rive" / "scenes" / f"{sid}.riv",
                        [c["scene_artboard"], c["scene_sm"], c["scene_vm"], c["scene_event_name"], *ev_vals, *prop_ids,
                         *c["scene_vm_props"]])
    extra = {p.stem for p in (ROOT / "assets" / "rive" / "scenes").glob("*.riv")} - set(c["scenes"])
    if extra:
        err(f"scenes not in the contract: {sorted(extra)}")
    check_ui_kit(c)
    check_journey(c)
    for e in diorama_lint():
        err(e)
    if errors:
        print("✗ contract self-check failed:")
        for e in errors:
            print("  -", e)
        return 1
    print(f"✓ contract self-check: avatar + {len(c['scenes'])} scenes + ui_kit ({len(c['ui'])} artboards) "
          f"+ {len(c['scenes'])} posters + journey match rive/CONTRACT.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
