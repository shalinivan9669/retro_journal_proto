"""Generate deterministic CC0-style procedural ambience loops for Lost Signal."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "lost_signal" / "audio" / "generated"
RATE = 22_050
DURATION = 4.0


def render(kind: str) -> list[int]:
    random.seed(8911 + sum(map(ord, kind)))
    filtered = 0.0
    result: list[int] = []
    for index in range(int(RATE * DURATION)):
        time = index / RATE
        noise = random.uniform(-1.0, 1.0)
        if kind == "engine":
            filtered += (noise - filtered) * 0.025
            sample = math.sin(math.tau * 43.0 * time) * 0.30
            sample += math.sin(math.tau * 86.0 * time) * 0.14 + filtered * 0.16
        elif kind == "road":
            filtered += (noise - filtered) * 0.12
            sample = filtered * 0.36 + math.sin(math.tau * 18.0 * time) * 0.06
        elif kind == "diner":
            filtered += (noise - filtered) * 0.018
            sample = math.sin(math.tau * 50.0 * time) * 0.11
            sample += math.sin(math.tau * 100.0 * time) * 0.035 + filtered * 0.11
        elif kind == "forest":
            filtered += (noise - filtered) * 0.008
            gate = max(0.0, math.sin(math.tau * 1.75 * time)) ** 18
            cricket = math.sin(math.tau * 3650.0 * time) * gate * 0.07
            sample = filtered * 0.28 + cricket
        else:
            filtered += (noise - filtered) * 0.22
            sample = filtered * 0.31 + math.sin(math.tau * 291.0 * time) * 0.025
        result.append(max(-32767, min(32767, int(sample * 14_000))))
    return result


def write_loop(kind: str) -> None:
    path = ROOT / f"lost_signal_{kind}_loop.wav"
    samples = render(kind)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(sample.to_bytes(2, "little", signed=True) for sample in samples))


def write_oneshot(name: str, duration: float) -> None:
    random.seed(14_211 + sum(map(ord, name)))
    count = int(RATE * duration)
    samples: list[int] = []
    filtered = 0.0
    for index in range(count):
        time = index / RATE
        ratio = index / max(1, count - 1)
        if name == "register":
            envelope = math.exp(-ratio * 5.2)
            sample = math.sin(math.tau * (920.0 - ratio * 220.0) * time) * envelope * 0.42
        elif name == "cutlery":
            impulse = max(0.0, math.sin(math.tau * 7.0 * time)) ** 22
            sample = (random.uniform(-1.0, 1.0) * 0.16 + math.sin(math.tau * 2480.0 * time) * 0.12) * impulse
        else:
            noise = random.uniform(-1.0, 1.0)
            filtered += (noise - filtered) * 0.28
            envelope = math.sin(math.pi * ratio) ** 0.7
            sample = filtered * envelope * 0.34
        samples.append(max(-32767, min(32767, int(sample * 14_000))))
    path = ROOT / f"lost_signal_{name}_oneshot.wav"
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(sample.to_bytes(2, "little", signed=True) for sample in samples))


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    for kind in ("engine", "road", "diner", "forest", "water"):
        write_loop(kind)
    write_oneshot("register", 0.28)
    write_oneshot("cutlery", 0.72)
    write_oneshot("rustle", 0.58)


if __name__ == "__main__":
    main()
