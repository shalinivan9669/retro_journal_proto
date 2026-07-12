from __future__ import annotations

import hashlib
import json
import shutil
import sys
import urllib.request
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


API_ROOT = "https://api.polyhaven.com/files"
OUTPUT_ROOT = Path("assets/polyhaven")
ASSETS = (
    "classic_laptop",
    "vintage_radio_transceiver",
    "security_camera_02",
    "industrial_storage_cart",
    "ceiling_fan",
)
HEADERS = {"User-Agent": "retro-journal-proto-asset-importer/1.0"}


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 200:
            raise RuntimeError(f"API error {response.status}: {url}")
        return json.loads(response.read().decode("utf-8"))


def walk_entries(value: Any, path: tuple[str, ...] = ()):
    if isinstance(value, dict):
        if isinstance(value.get("url"), str):
            yield path, value
        for key, child in value.items():
            if key != "include":
                yield from walk_entries(child, path + (str(key),))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_entries(child, path + (str(index),))


def candidate_score(path: tuple[str, ...], entry: dict[str, Any]) -> int:
    url = str(entry.get("url", "")).lower()
    metadata = (" ".join(path) + " " + url).lower()
    if not url.endswith((".gltf", ".glb", ".zip")):
        return -10_000
    if "gltf" not in metadata and not url.endswith((".gltf", ".glb")):
        return -10_000
    score = 500 if "4k" in metadata else 200 if "2k" in metadata else -500 if "1k" in metadata else 0
    score += 100 if url.endswith(".glb") else 90 if url.endswith(".gltf") else 20
    if "lod0" in metadata or "static" in metadata:
        score += 30
    return score


def choose_model(files_tree: dict[str, Any]) -> dict[str, Any]:
    candidates = list(walk_entries(files_tree))
    if not candidates:
        raise RuntimeError("API returned no downloadable files")
    path, entry = max(candidates, key=lambda item: candidate_score(item[0], item[1]))
    if candidate_score(path, entry) < 0:
        raise RuntimeError("No suitable 4K glTF/GLB model found")
    print(f"Selected: {'/'.join(path)}")
    return entry


def safe_relative_path(path: str) -> Path:
    normalized = Path(path.replace("\\", "/"))
    if normalized.is_absolute() or ".." in normalized.parts:
        raise RuntimeError(f"Unsafe include path: {path}")
    return normalized


def download_file(url: str, destination: Path, expected_md5: str | None = None) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            if response.status != 200:
                raise RuntimeError(f"Download error {response.status}: {url}")
            with temporary.open("wb") as output:
                shutil.copyfileobj(response, output)
        if expected_md5:
            actual = hashlib.md5(temporary.read_bytes(), usedforsecurity=False).hexdigest()
            if actual.lower() != expected_md5.lower():
                raise RuntimeError(f"Checksum mismatch for {destination.name}")
        temporary.replace(destination)
        print(f"Downloaded: {destination}")
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def filename_from_url(url: str) -> str:
    name = Path(urlparse(url).path).name
    if not name:
        raise RuntimeError(f"Cannot determine filename: {url}")
    return name


def download_includes(includes: Any, destination_root: Path) -> None:
    if not isinstance(includes, dict):
        return
    for relative_name, info in includes.items():
        if not isinstance(info, dict) or not isinstance(info.get("url"), str):
            continue
        download_file(
            info["url"],
            destination_root / safe_relative_path(str(relative_name)),
            info.get("md5"),
        )


def download_asset(slug: str) -> None:
    print(f"\nDownloading Poly Haven asset: {slug}")
    root = OUTPUT_ROOT / slug
    root.mkdir(parents=True, exist_ok=True)
    selected = choose_model(fetch_json(f"{API_ROOT}/{slug}"))
    model_path = root / filename_from_url(selected["url"])
    download_file(selected["url"], model_path, selected.get("md5"))
    download_includes(selected.get("include"), root)
    if model_path.suffix.lower() == ".zip":
        shutil.unpack_archive(model_path, root)
    if not list(root.rglob("*.gltf")) and not list(root.rglob("*.glb")):
        raise RuntimeError(f"{slug}: no glTF/GLB found after download")
    print(f"Asset ready: {slug}")


def main() -> int:
    failures: list[str] = []
    for slug in ASSETS:
        try:
            download_asset(slug)
        except Exception as error:
            failures.append(slug)
            print(f"ERROR [{slug}]: {error}", file=sys.stderr)
    if failures:
        print("Failed assets: " + ", ".join(failures), file=sys.stderr)
        return 1
    print("\nAll basement props downloaded successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
