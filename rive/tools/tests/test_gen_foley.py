"""Tests for the generated foley (moonshot M8 ruling 11): lengths, format, peaks, loop seams,
budget, determinism, and the checked-in files."""

from __future__ import annotations

from pathlib import Path
import sys
import wave

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_foley as gf  # noqa: E402

EXPECTED_MS = {
    **{f"step_{k}": gf.STEP_MS for k in range(4)},
    **{f"cloth_{k}": gf.CLOTH_MS for k in range(2)},
    "click_0": gf.CLICK_MS,
    **{f"paper_{k}": gf.PAPER_MS for k in range(2)},
    "bed_crackle": gf.BED_MS,
    "bed_rain": gf.BED_MS,
    "bell_0": gf.BELL_MS,
}
BEDS = ("bed_crackle", "bed_rain")


@pytest.fixture(scope="module")
def generated(tmp_path_factory: pytest.TempPathFactory) -> dict[str, Path]:
    return gf.generate(tmp_path_factory.mktemp("foley"), log=None)


def _read(path: Path) -> tuple[wave._wave_params, np.ndarray]:
    with wave.open(str(path), "rb") as w:
        params = w.getparams()
        data = np.frombuffer(w.readframes(params.nframes), dtype="<i2").astype(np.float64) / 32767.0
    return params, data


def test_the_set_is_complete(generated: dict[str, Path]) -> None:
    assert set(generated) == set(EXPECTED_MS) | {"bed_wind"}   # M11: the wind bed (its own rate, below)


@pytest.mark.parametrize("name", sorted(EXPECTED_MS))
def test_format_and_length(generated: dict[str, Path], name: str) -> None:
    params, data = _read(generated[name])
    assert (params.nchannels, params.sampwidth, params.framerate) == (1, 2, 22050)
    assert params.nframes == round(22050 * EXPECTED_MS[name] / 1000)
    assert len(data) == params.nframes


@pytest.mark.parametrize("name", sorted(EXPECTED_MS))
def test_peaks_stay_under_minus_one_dbfs(generated: dict[str, Path], name: str) -> None:
    _, data = _read(generated[name])
    peak = float(np.max(np.abs(data)))
    assert peak <= 10 ** (-1 / 20), f"{name} peak {20 * np.log10(peak):.2f} dBFS"
    # and is not silent
    assert peak > 10 ** (-12 / 20)


@pytest.mark.parametrize("name", sorted(set(EXPECTED_MS) - set(BEDS)))
def test_short_sounds_start_and_end_quietly(generated: dict[str, Path], name: str) -> None:
    _, data = _read(generated[name])
    assert abs(data[0]) < 0.02
    assert abs(data[-1]) < 0.02


@pytest.mark.parametrize("name", BEDS)
def test_beds_loop_seamlessly(generated: dict[str, Path], name: str) -> None:
    _, x = _read(generated[name])
    ten = round(22050 * 0.010)
    head, tail = x[:ten], x[-ten:]
    rms_head = float(np.sqrt(np.mean(head**2)))
    rms_tail = float(np.sqrt(np.mean(tail**2)))
    # the first and last 10 ms carry the same level (no fade, no gap)
    assert rms_head > 0 and rms_tail > 0
    assert 0.33 < rms_head / rms_tail < 3.0
    # and the wrap is no bigger a step than the signal's own steps
    steps = np.abs(np.diff(x))
    assert abs(x[0] - x[-1]) <= float(np.percentile(steps, 99.9))
    # no DC offset to thump at the wrap
    assert abs(float(np.mean(x))) < 0.01


def test_total_size_within_budget(generated: dict[str, Path]) -> None:
    total = sum(p.stat().st_size for p in generated.values())
    assert total <= 900 * 1024 == 921_600


# ---------------------------------------------------------------- the wind bed (M11 ruling 11)
def test_wind_bed_format_length_and_budget(generated: dict[str, Path]) -> None:
    params, data = _read(generated["bed_wind"])
    assert (params.nchannels, params.sampwidth, params.framerate) == (1, 2, 16000)
    assert params.nframes == round(16000 * gf.WIND_MS / 1000) == len(data)
    assert generated["bed_wind"].stat().st_size <= gf.MAX_WIND_BYTES == 88_000
    peak = float(np.max(np.abs(data)))
    assert 10 ** (-12 / 20) < peak <= 10 ** (-1 / 20)


def test_wind_bed_loops_seamlessly(generated: dict[str, Path]) -> None:
    _, x = _read(generated["bed_wind"])
    ms10 = 160
    rms = [float(np.sqrt(np.mean(x[i:i + ms10] ** 2))) for i in range(0, len(x) - ms10, ms10)]
    join = np.concatenate([x[-ms10 // 2:], x[:ms10 // 2]])
    rms_join = float(np.sqrt(np.mean(join ** 2)))
    # the join's 10 ms carry a level inside the loop's own range (no dip, no bump)
    assert min(rms) * 0.8 <= rms_join <= max(rms) * 1.2
    # and its step is no bigger than the signal's own steps; no DC to thump at the wrap
    assert abs(x[0] - x[-1]) <= float(np.percentile(np.abs(np.diff(x)), 99.9))
    assert abs(float(np.mean(x))) < 0.01


def test_wind_bed_gusts() -> None:
    level, sweep = gf.wind_gust(1000)
    # periodic over the loop (the crossfade never meets a level step) and it really gusts
    assert abs(level[0] - level[-1]) < 0.01 and abs(sweep[0] - sweep[-1]) < 0.01
    assert level.max() / level.min() > 1.8 and sweep.min() >= 0 and sweep.max() <= 1


def test_wind_bed_is_checked_in_and_fresh() -> None:
    path = gf.OUT_DIR / "bed_wind.wav"
    assert path.exists(), "run gen_foley.py"
    _, data = _read(path)
    assert np.array_equal(np.round(np.clip(gf.sounds()["bed_wind"], -1, 1) * 32767) / 32767.0, data)
    total = sum(p.stat().st_size for p in gf.OUT_DIR.glob("*.wav"))
    assert total <= 921_600


def test_bell_within_its_budget(generated: dict[str, Path]) -> None:
    # M9 ruling 9: the bell is at most 48 KB and keeps the set within 921,600 B
    assert generated["bell_0"].stat().st_size <= 48 * 1024
    assert gf.MAX_TOTAL_BYTES == 921_600


def test_bell_rings_and_decays(generated: dict[str, Path]) -> None:
    _, x = _read(generated["bell_0"])
    spectrum = np.abs(np.fft.rfft(x))
    freqs = np.fft.rfftfreq(len(x), 1 / 22050)
    # the strike note carries the most energy around it (a pitched bell, not noise)
    peak = float(freqs[int(np.argmax(spectrum))])
    assert any(abs(peak - gf.BELL_STRIKE_HZ * r) < 15 for r, _, _ in gf.BELL_PARTIALS), peak
    # the ring decays: the last 100 ms are far quieter than the first 100 ms
    tenth = round(22050 * 0.1)
    head = float(np.sqrt(np.mean(x[:tenth] ** 2)))
    tail = float(np.sqrt(np.mean(x[-tenth:] ** 2)))
    assert tail < head / 8


def test_m8_files_keep_their_bytes() -> None:
    # the bell is drawn after the M8 set from the same seed: the checked-in M8 files are unchanged
    fresh = gf.sounds()
    for name in EXPECTED_MS:
        if name == "bell_0":
            continue
        path = gf.OUT_DIR / f"{name}.wav"
        _, data = _read(path)
        assert np.array_equal(np.round(np.clip(fresh[name], -1, 1) * 32767) / 32767.0, data), name


def test_generation_is_deterministic(tmp_path: Path, generated: dict[str, Path]) -> None:
    again = gf.generate(tmp_path, log=None)
    for name, path in generated.items():
        assert path.read_bytes() == again[name].read_bytes(), name


def test_variants_differ(generated: dict[str, Path]) -> None:
    for group in (("step_0", "step_1", "step_2", "step_3"), ("cloth_0", "cloth_1"), ("paper_0", "paper_1")):
        datas = [generated[n].read_bytes() for n in group]
        assert len(set(datas)) == len(datas), group


def test_checked_in_assets_are_present_and_valid() -> None:
    for name, ms in EXPECTED_MS.items():
        path = gf.OUT_DIR / f"{name}.wav"
        assert path.exists(), f"missing {path}: run gen_foley.py"
        params, data = _read(path)
        assert params.framerate == 22050 and params.nchannels == 1
        assert params.nframes == round(22050 * ms / 1000)
        assert float(np.max(np.abs(data))) <= 10 ** (-1 / 20)
