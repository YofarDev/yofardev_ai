"""Tabulates the `FRAME_COST <scene> <tier> {json}` lines of `integration_test/frame_cost_test.dart` (M11).

    uv run rive/tools/frame_cost_table.py <drive log> > <table.md>

One Markdown row per scene x tier; a pass that drew fewer than 20 frames a second (`valid` false) is
`invalid`, never ok; the last line counts the valid passes and those within their tier's budget.
"""

from __future__ import annotations

import json
import re
import sys

LINE = re.compile(r"FRAME_COST (\S+) (low|high|ultra) (\{.*\})")


def rows(text: str) -> list[tuple[str, str, dict]]:
    out = []
    for line in text.splitlines():
        m = LINE.search(line)
        if m:
            out.append((m.group(1), m.group(2), json.loads(m.group(3))))
    return out


def table(rs: list[tuple[str, str, dict]]) -> str:
    lines = ["| Scene | Tier | frames | worst P50 | worst P95 | worst P99 | build P95 | raster P95 | over budget | pass |",
             "|---|---|---:|---:|---:|---:|---:|---:|---:|---|"]
    for s, t, d in rs:
        valid = d.get("valid", d["frames"] >= 160)
        verdict = "ok" if d["pass"] else ("invalid" if not valid else "FAIL")
        lines.append(f"| {s} | {t} | {d['frames']} | {d['worst_p50']} | {d['worst_p95']} | {d['worst_p99']} | "
                     f"{d['build_p95']} | {d['raster_p95']} | {d['over_budget_share']:.1%} | {verdict} |")
    valid = [d for *_, d in rs if d.get("valid", d["frames"] >= 160)]
    lines.append("")
    lines.append(f"{len(valid)}/{len(rs)} passes valid (>= 20 fps drawn); "
                 f"{sum(1 for d in valid if d['pass'])}/{len(valid)} valid passes within budget")
    return "\n".join(lines)


if __name__ == "__main__":
    print(table(rows(open(sys.argv[1], encoding="utf-8").read())))
