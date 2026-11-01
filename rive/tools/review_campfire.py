"""Evidence for the campfire diorama: kept as an alias of the shared `review_diorama.py` (M5 Task 3).

    uv run --with pillow --with numpy rive/tools/review_campfire.py [before_poster.webp] [--out=<dir>]

Same as `review_diorama.py campfire ...` (default output rive/review/m5/campfire/).
"""

from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review_diorama  # noqa: E402

if __name__ == "__main__":
    sys.exit(review_diorama.main(["campfire", *sys.argv[1:]]))
