"""Moonshot M8 Task 3: the tablet's weather card (ruling 14, contract v11 `tabletWeather`, `tabletTemp`).

The segment map is checked as a table (every temperature's segments decode back to its digits), and the
generated formula converters are evaluated token by token (a small evaluator with the usual precedence),
so each segment's bound opacity equals the table for every temperature."""

from __future__ import annotations

import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import avatar_tablet as tb  # noqa: E402

RML = Path(__file__).resolve().parents[2] / "avatar" / "avatar.rml"
WEATHER = ["none", "clear", "clouds", "rain", "snow", "storm", "fog"]


def test_the_segment_map_decodes_every_temperature() -> None:
    for t in range(-40, 51):
        assert tb.shown(t) == str(t), t
    assert [tb.shown(t) for t in (-9.4, -0.4, 0.4, 9.6, 49.5)] == ["-9", "0", "0", "10", "50"]
    assert tb.shown(-0.6) == "-1"
    assert tb.shown(-130) == "-99" and tb.shown(250) == "99"  # out of range: clamped to +-99
    # one-digit negatives put the minus in the tens slot, two-digit ones in the sign slot
    assert tb.readout(-5)[:2] == (False, {"g"}) and tb.readout(-15)[0] is True
    assert tb.readout(7)[1] == set()  # no leading zero


# ------------------------------------------------------------------ the formulas in the RML

OPS = {0: "+", 1: "-", 2: "*", 3: "/", 4: "%"}
FNS = {0: min, 1: max, 2: lambda x: math.copysign(math.floor(abs(x) + 0.5), x), 4: math.floor, 6: math.pow}


class Formula:
    def __init__(self, tokens: list[ET.Element]) -> None:
        self.toks = tokens

    def __call__(self, x: float) -> float:
        self.i, self.x = 0, x
        v = self.expr()
        assert self.i == len(self.toks)
        return v

    def peek(self) -> ET.Element | None:
        return self.toks[self.i] if self.i < len(self.toks) else None

    def expr(self) -> float:
        v = self.term()
        while (t := self.peek()) is not None and t.tag == "FormulaTokenOperation" and \
                OPS[int(t.get("operationType", 0))] in "+-":
            self.i += 1
            r = self.term()
            v = v + r if OPS[int(t.get("operationType", 0))] == "+" else v - r
        return v

    def term(self) -> float:
        v = self.factor()
        while (t := self.peek()) is not None and t.tag == "FormulaTokenOperation" and \
                OPS[int(t.get("operationType", 0))] in "*/%":
            self.i += 1
            r = self.factor()
            op = OPS[int(t.get("operationType", 0))]
            v = v * r if op == "*" else (v / r if op == "/" else math.fmod(v, r))
        return v

    def factor(self) -> float:
        t = self.toks[self.i]
        self.i += 1
        if t.tag == "FormulaTokenValue":
            return float(t.get("operationValue", 0))
        if t.tag == "FormulaTokenInput":
            return self.x
        if t.tag == "FormulaTokenParenthesisOpen":
            v = self.expr()
            assert self.toks[self.i].tag == "FormulaTokenParenthesisClose"
            self.i += 1
            return v
        assert t.tag == "FormulaTokenFunction", t.tag
        args = [self.expr()]
        while self.toks[self.i].tag == "FormulaTokenArgumentSeparator":
            self.i += 1
            args.append(self.expr())
        assert self.toks[self.i].tag == "FormulaTokenParenthesisClose"
        self.i += 1
        return float(FNS[int(t.get("functionType", 0))](*args))


@pytest.fixture(scope="module")
def root() -> ET.Element:
    return ET.parse(RML).getroot()


def _converter(root: ET.Element, cid: str):  # type: ignore[no-untyped-def]
    el = next(e for e in root.iter() if e.get("id") == cid)
    if el.tag == "DataConverterFormula":
        return Formula(list(el))
    assert el.tag == "DataConverterGroup"
    chain = [_converter(root, item.get("converterId")) for item in el]
    return lambda x: _apply(chain, x)


def _apply(chain: list, x: float) -> float:
    for c in chain:
        x = c(x)
    return x


def test_names_and_defaults(root: ET.Element) -> None:
    enum = next(e for e in root.iter("DataEnumCustom") if e.get("name") == "TabletWeather")
    assert [v.get("key") for v in enum] == WEATHER
    vm = next(v for v in root.iter("ViewModel") if v.get("name") == "AvatarVM")
    props = {c.get("name"): c for c in vm if c.tag.startswith("ViewModelProperty")}
    assert props["tabletWeather"].tag == "ViewModelPropertyEnumCustom"
    assert props["tabletTemp"].tag == "ViewModelPropertyNumber"
    inst = next(c for c in vm if c.tag == "ViewModelInstance")
    vals = {c.get("viewModelPropertyId"): c.get("propertyValue") for c in inst}
    none = next(v for v in enum if v.get("key") == "none")
    assert vals[props["tabletWeather"].get("id")] == none.get("id")
    assert vals[props["tabletTemp"].get("id")] == "0"


def test_every_segment_formula_matches_the_table(root: ET.Element) -> None:
    vm = next(v for v in root.iter("ViewModel") if v.get("name") == "AvatarVM")
    temp = next(c for c in vm if c.get("name") == "tabletTemp").get("id")
    segs = {}
    for shape in root.iter("Shape"):
        if not str(shape.get("name", "")).startswith("Seg"):
            continue
        (b,) = shape.findall("DataBindContext")
        assert b.get("sourcePathIds").endswith(temp) and b.get("propertyKey") == "18"
        segs[shape.get("name")] = _converter(root, b.get("converterId"))
    assert len(segs) == 15
    for t in [*range(-45, 56), -9.4, 0.6, 12.5, -12.5, 150, -150]:
        sign, tens, units = tb.readout(t)
        for name, f in segs.items():
            want = sign if name == "SegSign" else (
                name[-1].lower() in (tens if name.startswith("SegTens") else units))
            assert f(t) == float(want), (t, name, f(t))


def test_the_card_layer(root: ET.Element) -> None:
    board = root.find("Artboard")
    anims = {a.get("name"): a for a in board.findall("LinearAnimation")}
    ids = {e.get("id"): e for e in root.iter() if e.get("id")}
    layer = next(la for la in board.iter("StateMachineLayer") if la.get("name") == "TabletWeather")
    played = {ids[s.get("animationId")].get("name") for s in layer.iter("AnimationState")}
    assert played == {f"tablet_weather_{w}" for w in WEATHER}
    none = {ids[o.get("objectId")].get("name"): ids[o[0][0].get("value")].get("name")
            for o in anims["tablet_weather_none"].findall("KeyedObject")}
    assert none == {"emitWeather": "WeatherGeneric"}
    for w in WEATHER[1:]:
        keyed = {ids[o.get("objectId")].get("name"): o[0][0].get("value") for o in
                 anims[f"tablet_weather_{w}"].findall("KeyedObject")}
        assert ids[keyed["emitWeather"]].get("name") == "WeatherNow"
        assert ids[keyed["WeatherExtra"]].get("name") == f"Wx_{w}"
        assert keyed["WxCloudShown"] == ("1" if w in ("clouds", "rain", "snow", "storm") else "0")
