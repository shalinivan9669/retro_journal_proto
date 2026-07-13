#!/usr/bin/env python3
"""Deterministically synthesize mono barrage SFX for the archive scene.

Uses only the Python standard library. Every output is 44.1 kHz, signed 16-bit
PCM mono. Signals are normalized below full scale and verified after writing.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path
from typing import Callable, Iterable


SAMPLE_RATE = 44_100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "generated" / "audio"


def envelope_attack_decay(t: float, attack: float, decay: float) -> float:
    return (1.0 - math.exp(-t / max(attack, 1e-5))) * math.exp(-t / decay)


def one_pole_lowpass(values: Iterable[float], cutoff_hz: float) -> list[float]:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SAMPLE_RATE)
    state = 0.0
    output: list[float] = []
    for value in values:
        state += alpha * (value - state)
        output.append(state)
    return output


def highpass_from(values: list[float], cutoff_hz: float) -> list[float]:
    low = one_pole_lowpass(values, cutoff_hz)
    return [value - low_value for value, low_value in zip(values, low)]


def noise_buffer(rng: random.Random, frame_count: int) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(frame_count)]


def synth_launch(variant: int) -> tuple[list[float], float]:
    rng = random.Random(11_700 + variant)
    duration = 1.05 + variant * 0.08
    frames = int(duration * SAMPLE_RATE)
    white = noise_buffer(rng, frames)
    roar = one_pole_lowpass(white, 720.0 + variant * 95.0)
    grit = highpass_from(white, 1_900.0 + variant * 160.0)
    output: list[float] = []
    phase = 0.0
    for index in range(frames):
        t = index / SAMPLE_RATE
        thump_frequency = 74.0 - 31.0 * min(t / 0.32, 1.0) + variant * 2.5
        phase += 2.0 * math.pi * thump_frequency / SAMPLE_RATE
        thump = math.sin(phase) * math.exp(-t / 0.24)
        ignition = grit[index] * math.exp(-t / 0.032)
        fire = roar[index] * envelope_attack_decay(t, 0.006, 0.42 + variant * 0.04)
        hiss = grit[index] * envelope_attack_decay(t, 0.012, 0.26) * 0.22
        output.append(0.42 * thump + 0.48 * fire + 0.18 * ignition + hiss)
    return output, 0.68


def synth_impact(variant: int) -> tuple[list[float], float]:
    rng = random.Random(23_900 + variant)
    duration = 3.65 + variant * 0.24
    frames = int(duration * SAMPLE_RATE)
    white = noise_buffer(rng, frames)
    body_noise = one_pole_lowpass(white, 950.0 - variant * 70.0)
    rumble_noise = one_pole_lowpass(white, 105.0 + variant * 8.0)
    crack_noise = highpass_from(white, 2_400.0 + variant * 180.0)
    output: list[float] = []
    phase = 0.0
    for index in range(frames):
        t = index / SAMPLE_RATE
        low_frequency = 68.0 - 35.0 * min(t / 1.15, 1.0) + variant * 1.7
        phase += 2.0 * math.pi * low_frequency / SAMPLE_RATE
        dry_crack = crack_noise[index] * math.exp(-t / (0.014 + variant * 0.002))
        pressure = math.sin(phase) * envelope_attack_decay(t, 0.003, 0.82 + variant * 0.08)
        body = body_noise[index] * envelope_attack_decay(t, 0.002, 0.31 + variant * 0.03)
        earth_tail = rumble_noise[index] * envelope_attack_decay(t, 0.035, 1.42 + variant * 0.16)
        debris_gate = math.exp(-max(t - 0.075, 0.0) / 0.55) if t >= 0.075 else 0.0
        debris = crack_noise[index] * debris_gate * 0.08
        output.append(
            0.36 * dry_crack
            + 0.38 * pressure
            + 0.40 * body
            + 0.72 * earth_tail
            + debris
        )
    return output, 0.78


def synth_distant(variant: int) -> tuple[list[float], float]:
    rng = random.Random(37_100 + variant)
    duration = 4.75 + variant * 0.31
    frames = int(duration * SAMPLE_RATE)
    white = noise_buffer(rng, frames)
    softened = one_pole_lowpass(white, 330.0 - variant * 22.0)
    deep = one_pole_lowpass(white, 72.0 + variant * 6.0)
    output: list[float] = []
    phase = 0.0
    for index in range(frames):
        t = index / SAMPLE_RATE
        low_frequency = 45.0 - 15.0 * min(t / 1.8, 1.0) + variant * 1.4
        phase += 2.0 * math.pi * low_frequency / SAMPLE_RATE
        arrival = envelope_attack_decay(t, 0.028 + variant * 0.006, 1.20 + variant * 0.13)
        tail = envelope_attack_decay(t, 0.09, 2.05 + variant * 0.18)
        pressure = math.sin(phase) * arrival
        output.append(0.34 * pressure + 0.42 * softened[index] * arrival + 0.92 * deep[index] * tail)
    return output, 0.70


def prepare_samples(samples: list[float], target_peak: float) -> list[int]:
    mean = sum(samples) / max(len(samples), 1)
    centered = [sample - mean for sample in samples]
    fade_frames = min(int(0.08 * SAMPLE_RATE), len(centered))
    for offset in range(fade_frames):
        centered[-fade_frames + offset] *= 1.0 - offset / max(fade_frames - 1, 1)
    peak = max((abs(sample) for sample in centered), default=1.0)
    gain = target_peak / max(peak, 1e-9)
    pcm = [int(round(max(-0.999, min(0.999, sample * gain)) * 32767.0)) for sample in centered]
    if max((abs(sample) for sample in pcm), default=0) >= 32767:
        raise RuntimeError("Generated signal reached digital full scale")
    return pcm


def write_wav(path: Path, samples: list[float], target_peak: float) -> None:
    pcm = prepare_samples(samples, target_peak)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))


def verify_wav(path: Path) -> tuple[float, float]:
    with wave.open(str(path), "rb") as source:
        if source.getnchannels() != 1:
            raise RuntimeError(f"{path.name}: expected mono")
        if source.getsampwidth() != 2 or source.getframerate() != SAMPLE_RATE:
            raise RuntimeError(f"{path.name}: expected 16-bit PCM at {SAMPLE_RATE} Hz")
        frame_count = source.getnframes()
        pcm = struct.unpack(f"<{frame_count}h", source.readframes(frame_count))
    peak = max((abs(sample) for sample in pcm), default=0) / 32767.0
    if peak >= 1.0:
        raise RuntimeError(f"{path.name}: clipped ({peak:.6f})")
    return frame_count / SAMPLE_RATE, peak


def generate() -> list[Path]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    groups: tuple[tuple[str, Callable[[int], tuple[list[float], float]]], ...] = (
        ("launch", synth_launch),
        ("impact", synth_impact),
        ("distant", synth_distant),
    )
    outputs: list[Path] = []
    for label, synthesizer in groups:
        for variant in range(3):
            samples, target_peak = synthesizer(variant)
            path = OUTPUT_DIR / f"barrage_{label}_{variant + 1:02d}.wav"
            write_wav(path, samples, target_peak)
            outputs.append(path)
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="verify existing generated WAV files without regenerating them",
    )
    args = parser.parse_args()
    paths = sorted(OUTPUT_DIR.glob("barrage_*.wav")) if args.verify_only else generate()
    if len(paths) != 9:
        raise RuntimeError(f"expected 9 WAV variants, found {len(paths)}")
    for path in paths:
        duration, peak = verify_wav(path)
        print(f"{path.name}: {duration:.2f}s, peak={peak:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
