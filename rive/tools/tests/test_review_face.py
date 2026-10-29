"""Tests for the evidence helpers of rive/tools/review_face.py (no Rive render)."""

from __future__ import annotations

from pathlib import Path
import math
import struct
import sys
import wave

from PIL import Image
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import review_face
from review_face import FACE_BOX, MOUTH_BOX, PHONE_BOX, STRIP_CROP, WIDE_BOX, YAW_BOX, find_wav, read_wav, strip_cell

LABEL_INK: tuple[int, int, int] = (255, 230, 120)


def sine(n: int, rate: int, amp: float = 0.5) -> list[float]:
    return [amp * math.sin(2 * math.pi * 220 * i / rate) for i in range(n)]


def write_pcm(path: Path, samples: list[float], rate: int, width: int, channels: int = 1) -> Path:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(width)
        w.setframerate(rate)
        frames = bytearray()
        for v in samples:
            for _ in range(channels):
                if width == 1:
                    frames += bytes([int(round(v * 127)) + 128])
                elif width == 2:
                    frames += struct.pack("<h", int(round(v * 32767)))
                elif width == 3:
                    frames += int(round(v * 8388607)).to_bytes(3, "little", signed=True)
                else:
                    frames += struct.pack("<i", int(round(v * 2147483647)))
        w.writeframes(bytes(frames))
    return path


def write_float(path: Path, samples: list[float], rate: int) -> Path:
    pcm = struct.pack(f"<{len(samples)}f", *samples)
    fmt = struct.pack("<HHIIHH", 3, 1, rate, rate * 4, 4, 32)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
    body += b"FLLR" + struct.pack("<I", 6) + b"\0" * 6  # an unknown chunk, as `say` writes
    body += b"data" + struct.pack("<I", len(pcm)) + pcm
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    return path


@pytest.mark.parametrize("rate", [16000, 22050, 24000, 48000])
@pytest.mark.parametrize("width", [1, 2, 3, 4])
def test_read_wav_any_rate_and_width(tmp_path: Path, rate: int, width: int) -> None:
    want = sine(rate // 10, rate)
    got, sr = read_wav(write_pcm(tmp_path / "a.wav", want, rate, width))
    assert sr == rate
    assert len(got) == len(want)
    tolerance = 1 / 100 if width == 1 else 1e-4
    assert max(abs(a - b) for a, b in zip(got, want)) < tolerance
    assert max(abs(v) for v in got) == pytest.approx(0.5, abs=tolerance)


def test_read_wav_stereo_is_averaged(tmp_path: Path) -> None:
    got, sr = read_wav(write_pcm(tmp_path / "s.wav", sine(1600, 16000), 16000, 2, channels=2))
    assert sr == 16000
    assert len(got) == 1600
    assert max(abs(v) for v in got) == pytest.approx(0.5, abs=1e-4)


def test_read_wav_float_with_unknown_chunk(tmp_path: Path) -> None:
    got, sr = read_wav(write_float(tmp_path / "f.wav", sine(2400, 24000, 0.25), 24000))
    assert sr == 24000
    assert len(got) == 2400
    assert max(abs(v) for v in got) == pytest.approx(0.25, abs=1e-6)


def test_read_wav_speech_fixture_is_16khz_and_loud() -> None:
    fixture = review_face.ROOT / "test" / "fixtures" / "speech" / "bonjour.wav"
    got, sr = read_wav(fixture)
    assert sr == 16000
    assert max(abs(v) for v in got) > 0.1


def test_find_wav_prefers_the_trace_path_then_data_then_fixtures(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(review_face, "DATA", tmp_path / "data")
    (tmp_path / "data").mkdir()
    recorded = write_pcm(tmp_path / "rec.wav", sine(160, 16000), 16000, 2)
    assert find_wav("x", {"wav": str(recorded)}) == recorded
    # a recorded path relative to the repo root
    assert find_wav("x", {"wav": "test/fixtures/speech/so_true.wav"}) == \
        review_face.ROOT / "test" / "fixtures" / "speech" / "so_true.wav"
    data = write_pcm(tmp_path / "data" / "boat.wav", sine(160, 16000), 16000, 2)
    assert find_wav("boat", {}) == data
    # old traces carry no path: the fixture of the same name
    assert find_wav("bonjour", {}) == review_face.ROOT / "test" / "fixtures" / "speech" / "bonjour.wav"
    assert find_wav("nothing", {}) is None


def test_strip_cell_is_labelled_after_the_crop() -> None:
    cell = Image.new("RGB", (396, 495), (20, 18, 26))
    out = strip_cell(cell, "1.23s  sp 0.73", "oh stress")
    a, b, x, y = STRIP_CROP
    assert out.size == (int(396 * x) - int(396 * a), int(495 * y) - int(495 * b))
    corner = out.crop((0, 0, 120, 30))
    # the label ink (antialiased text: near it, on the dark background)
    assert any(r > 200 and g > 170 and b < 160 for r, g, b in corner.get_flattened_data())
    assert LABEL_INK == (255, 230, 120)


def test_crops_reach_below_the_dropped_chin() -> None:
    # the chin drops ~15 artboard px at full jaw; the face crops end well under the open mouth
    assert FACE_BOX[3] >= 550
    assert YAW_BOX[3] >= 565
    assert PHONE_BOX[3] >= 545
    assert MOUTH_BOX[3] >= 535
    strip_bottom = WIDE_BOX[1] + STRIP_CROP[3] * (WIDE_BOX[3] - WIDE_BOX[1])
    assert strip_bottom >= 565
