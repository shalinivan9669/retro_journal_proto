#!/usr/bin/env python3
"""Static integrity checks that do not require a Godot binary."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXT_EXTENSIONS = {".gd", ".gdshader", ".tscn", ".tres", ".godot", ".md", ".sh"}
RESOURCE_REFERENCE_EXTENSIONS = {".gd", ".gdshader", ".tscn", ".tres", ".godot"}


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    files = [path for path in ROOT.rglob("*") if path.is_file()]

    for path in files:
        if path.stat().st_size == 0:
            errors.append(f"empty file: {path.relative_to(ROOT)}")

    resource_pattern = re.compile(r'res://[^\s"\)]+')
    for path in files:
        if path.suffix not in TEXT_EXTENSIONS:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if path.suffix in RESOURCE_REFERENCE_EXTENSIONS or path.name == "project.godot":
            for value in resource_pattern.findall(text):
                clean = value.rstrip("'`,")
                if clean.endswith("/") or "%" in clean or "+" in clean:
                    continue
                target = ROOT / clean.removeprefix("res://")
                if not target.exists():
                    errors.append(f"missing resource referenced by {path.relative_to(ROOT)}: {clean}")

        pairs = (("(", ")"), ("[", "]"), ("{", "}"))
        if path.suffix in {".gd", ".gdshader"}:
            stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
            stripped = re.sub(r"#.*", "", stripped)
            for opening, closing in pairs:
                if stripped.count(opening) != stripped.count(closing):
                    warnings.append(f"unbalanced {opening}{closing}: {path.relative_to(ROOT)}")

    expected_images = {
        "assets/generated/steppe_ground/steppe_ground_albedo_4k.png": (4096, 4096),
        "assets/runtime/steppe_ground/steppe_ground_normal_gl_4k.webp": (4096, 4096),
        "assets/generated/backgrounds/visible_archive_night_sky_8k.png": (8192, 4096),
        "assets/generated/backgrounds/far_berms_8k.png": (8192, 1024),
        "assets/generated/fx/smoke_atlas_4x4_2k.png": (2048, 2048),
        "assets/generated/terrain/barrage_hill_height_2k.png": (2048, 2048),
    }
    for relative, expected_size in expected_images.items():
        path = ROOT / relative
        if not path.exists():
            errors.append(f"missing expected image: {relative}")
            continue
        with Image.open(path) as image:
            if image.size != expected_size:
                errors.append(f"unexpected size for {relative}: {image.size}, expected {expected_size}")

    required = [
        "project.godot",
        "scenes/BarrageDemo.tscn",
        "scripts/barrage_director.gd",
        "scripts/ballistic_trail_3d.gd",
        "shaders/tracer_trail.gdshader",
        "README_RU.md",
        "CODEX_IMPLEMENTATION_PROMPT_RU.md",
    ]
    for relative in required:
        if not (ROOT / relative).exists():
            errors.append(f"missing required file: {relative}")

    print(f"files: {len(files)}")
    print(f"bytes: {sum(path.stat().st_size for path in files)}")
    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        return 1
    print("Static pack validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
