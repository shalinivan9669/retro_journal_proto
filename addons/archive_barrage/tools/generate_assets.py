#!/usr/bin/env python3
"""Generate deterministic PBR/support textures for the Godot 4.7 barrage scene."""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated"
RNG = np.random.default_rng(667)


def ensure_dirs() -> None:
    for name in (
        "steppe_ground",
        "concrete",
        "metal",
        "decals",
        "fx",
        "backgrounds",
        "terrain",
        "preview",
    ):
        (OUT / name).mkdir(parents=True, exist_ok=True)


def normalize(a: np.ndarray, low: float = 0.0, high: float = 1.0) -> np.ndarray:
    lo = float(np.percentile(a, 1.0))
    hi = float(np.percentile(a, 99.0))
    if hi <= lo:
        return np.full_like(a, low, dtype=np.float32)
    a = np.clip((a - lo) / (hi - lo), 0.0, 1.0)
    return (low + a * (high - low)).astype(np.float32)


def spectral_noise(size: int, beta: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    source = rng.normal(0.0, 1.0, (size, size)).astype(np.float32)
    spectrum = np.fft.rfft2(source)
    fy = np.fft.fftfreq(size).astype(np.float32)[:, None]
    fx = np.fft.rfftfreq(size).astype(np.float32)[None, :]
    radius = np.sqrt(fx * fx + fy * fy)
    radius[0, 0] = 1.0
    filt = np.power(radius, -beta * 0.5).astype(np.float32)
    filt[0, 0] = 0.0
    result = np.fft.irfft2(spectrum * filt, s=(size, size)).real
    return normalize(result)


def resize_float(a: np.ndarray, size: int) -> np.ndarray:
    img = Image.fromarray(np.uint8(np.clip(a, 0.0, 1.0) * 255), "L")
    img = img.resize((size, size), Image.Resampling.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def save_gray(path: Path, a: np.ndarray, bits: int = 8) -> None:
    a = np.clip(a, 0.0, 1.0)
    if bits == 16:
        Image.fromarray(np.uint16(a * 65535), "I;16").save(path, optimize=True)
    else:
        Image.fromarray(np.uint8(a * 255), "L").save(path, optimize=True)


def save_rgb(path: Path, a: np.ndarray) -> None:
    a = np.clip(a, 0.0, 1.0)
    Image.fromarray(np.uint8(a * 255), "RGB").save(path, optimize=True)


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return normal * 0.5 + 0.5


def generate_steppe_ground() -> None:
    size = 4096
    broad = resize_float(spectral_noise(1024, 2.7, 667), size)
    medium = resize_float(spectral_noise(2048, 1.6, 668), size)
    fine = RNG.random((size, size), dtype=np.float32)

    height = normalize(broad * 0.58 + medium * 0.34 + fine * 0.08)
    compacted = np.power(height, 1.18)

    wet_noise = resize_float(spectral_noise(1024, 3.2, 669), size)
    low_areas = 1.0 - broad
    wet = normalize(low_areas * 0.72 + wet_noise * 0.28)
    wet = np.clip((wet - 0.57) / 0.24, 0.0, 1.0)
    wet = wet * wet * (3.0 - 2.0 * wet)

    # sRGB grayscale values 18..47; lighting, not albedo, reveals the surface.
    albedo_value = 0.071 + compacted * 0.105
    albedo_value *= 1.0 - wet * 0.32
    tint = np.stack(
        (albedo_value * 0.96, albedo_value * 0.98, albedo_value), axis=-1
    )

    roughness = np.clip(0.91 - wet * 0.77 + medium * 0.055, 0.10, 0.98)
    ao = np.clip(0.62 + height * 0.40 - (1.0 - medium) * 0.10, 0.42, 1.0)
    normal = normal_from_height(height, 13.5)

    folder = OUT / "steppe_ground"
    save_rgb(folder / "steppe_ground_albedo_4k.png", tint)
    save_gray(folder / "steppe_ground_roughness_4k.png", roughness)
    save_gray(folder / "steppe_ground_height_4k.png", height, bits=16)
    save_gray(folder / "steppe_ground_ao_4k.png", ao)
    save_gray(folder / "steppe_ground_wet_mask_4k.png", wet)
    save_rgb(folder / "steppe_ground_normal_gl_4k.png", normal)


def generate_concrete() -> None:
    size = 2048
    broad = resize_float(spectral_noise(768, 2.8, 677), size)
    fine = resize_float(spectral_noise(1024, 1.2, 678), size)
    pits = np.clip((0.36 - fine) * 3.2, 0.0, 1.0)
    height = normalize(broad * 0.58 + fine * 0.30 - pits * 0.12)

    dirt = resize_float(spectral_noise(512, 3.4, 679), size)
    value = np.clip(0.18 + height * 0.19 - dirt * 0.08, 0.09, 0.38)
    rgb = np.stack((value * 0.97, value * 0.98, value), axis=-1)
    rough = np.clip(0.72 + fine * 0.24 + pits * 0.08, 0.68, 0.99)
    normal = normal_from_height(height, 18.0)

    folder = OUT / "concrete"
    save_rgb(folder / "aged_concrete_albedo_2k.png", rgb)
    save_gray(folder / "aged_concrete_roughness_2k.png", rough)
    save_gray(folder / "aged_concrete_height_2k.png", height, bits=16)
    save_rgb(folder / "aged_concrete_normal_gl_2k.png", normal)


def generate_metal() -> None:
    size = 1024
    fine = resize_float(spectral_noise(512, 1.25, 687), size)
    streak = np.tile(np.linspace(0.0, 1.0, size, dtype=np.float32)[:, None], (1, size))
    streak = 0.5 + 0.5 * np.sin(streak * math.tau * 31.0 + fine * 2.0)
    rust = np.clip((fine * 0.75 + streak * 0.25 - 0.52) * 2.8, 0.0, 1.0)
    value = np.clip(0.075 + fine * 0.055 + rust * 0.06, 0.04, 0.21)
    rgb = np.stack((value * 1.05, value * 0.92, value * 0.84), axis=-1)
    rough = np.clip(0.53 + rust * 0.41 + fine * 0.08, 0.45, 0.98)
    metallic = np.clip(0.92 - rust * 0.82, 0.05, 0.95)

    folder = OUT / "metal"
    save_rgb(folder / "old_wire_albedo_1k.png", rgb)
    save_gray(folder / "old_wire_roughness_1k.png", rough)
    save_gray(folder / "old_wire_metallic_1k.png", metallic)


def irregular_blob(size: int, seed: int, softness: float = 24.0) -> Image.Image:
    rng = np.random.default_rng(seed)
    points = []
    count = 36
    cx = cy = size * 0.5
    for i in range(count):
        a = i / count * math.tau
        radius = size * (0.27 + rng.uniform(-0.075, 0.08))
        radius *= 1.0 + 0.11 * math.sin(a * 3.0 + seed)
        points.append((cx + math.cos(a) * radius * 1.42, cy + math.sin(a) * radius))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(softness))
    noise = np.asarray(mask, dtype=np.float32) / 255.0
    texture = resize_float(spectral_noise(256, 2.0, seed + 1000), size)
    noise *= np.clip(0.72 + texture * 0.48, 0.0, 1.0)
    return Image.fromarray(np.uint8(noise * 255), "L")


def generate_decals() -> None:
    folder = OUT / "decals"
    for i in range(8):
        mask = irregular_blob(1024, 700 + i, 20.0 + i)
        value = np.asarray(mask, dtype=np.uint8)
        rgba = np.zeros((1024, 1024, 4), dtype=np.uint8)
        rgba[..., :3] = 20 + i
        rgba[..., 3] = value
        Image.fromarray(rgba, "RGBA").save(folder / f"puddle_mask_{i + 1:02d}_1k.png")

    for i in range(6):
        mask = irregular_blob(1024, 760 + i, 34.0)
        value = np.asarray(mask, dtype=np.float32) / 255.0
        grit = resize_float(spectral_noise(256, 1.3, 800 + i), 1024)
        alpha = np.uint8(np.clip(value * grit * 1.35, 0.0, 1.0) * 255)
        rgba = np.zeros((1024, 1024, 4), dtype=np.uint8)
        rgba[..., :3] = np.uint8(10 + grit[..., None] * 18)
        rgba[..., 3] = alpha
        Image.fromarray(rgba, "RGBA").save(folder / f"mud_patch_{i + 1:02d}_1k.png")


def generate_fx() -> None:
    folder = OUT / "fx"
    size = 1024
    y, x = np.ogrid[-1.0:1.0:size * 1j, -1.0:1.0:size * 1j]
    radius = np.sqrt(x * x + y * y)
    alpha = np.exp(-radius * radius * 7.0)
    core = np.exp(-radius * radius * 80.0)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[..., :3] = np.uint8(np.clip(0.42 * alpha + core, 0.0, 1.0)[..., None] * 255)
    rgba[..., 3] = np.uint8(np.clip(alpha, 0.0, 1.0) * 255)
    Image.fromarray(rgba, "RGBA").save(folder / "flash_radial_1k.png")

    atlas_size = 2048
    tile = 512
    atlas = np.zeros((atlas_size, atlas_size, 4), dtype=np.uint8)
    yy, xx = np.ogrid[-1.0:1.0:tile * 1j, -1.0:1.0:tile * 1j]
    rr = np.sqrt(xx * xx + yy * yy)
    for index in range(16):
        noise = resize_float(spectral_noise(256, 2.0, 900 + index), tile)
        cloud = np.clip((noise - 0.34) * 2.4, 0.0, 1.0)
        cloud *= np.clip(1.0 - np.power(rr, 1.8), 0.0, 1.0)
        cloud = np.power(cloud, 1.15)
        r0 = (index // 4) * tile
        c0 = (index % 4) * tile
        atlas[r0:r0 + tile, c0:c0 + tile, :3] = np.uint8(cloud[..., None] * 190)
        atlas[r0:r0 + tile, c0:c0 + tile, 3] = np.uint8(cloud * 255)
    Image.fromarray(atlas, "RGBA").save(folder / "smoke_atlas_4x4_2k.png")

    noise = resize_float(spectral_noise(1024, 2.15, 950), 2048)
    save_gray(folder / "smoke_noise_2k.png", noise)


def generate_backgrounds() -> None:
    folder = OUT / "backgrounds"
    width, height = 8192, 1024
    rng = np.random.default_rng(1001)

    horizon = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(horizon)
    points = [(0, height)]
    baseline = 738
    for x in range(0, width + 64, 64):
        wave = 34 * math.sin(x / 530.0) + 18 * math.sin(x / 119.0)
        bump = rng.uniform(-12.0, 12.0)
        points.append((x, baseline + wave + bump))
    points.append((width, height))
    draw.polygon(points, fill=(9, 10, 11, 255))
    horizon.save(folder / "far_berms_8k.png")

    fences = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(fences)
    for x in range(120, width, 180):
        top = int(675 + 14 * math.sin(x / 170.0) + rng.uniform(-18, 18))
        draw.line((x, 820, x + rng.uniform(-7, 7), top), fill=(16, 17, 18, 230), width=5)
    for row in range(3):
        y = 710 + row * 34
        wire = []
        for x in range(0, width + 40, 40):
            wire.append((x, y + 6 * math.sin(x / 48.0 + row)))
        draw.line(wire, fill=(18, 19, 20, 210), width=2)
    fences.save(folder / "far_fence_8k.png")

    fog = np.zeros((height, width, 4), dtype=np.uint8)
    yy = np.arange(height, dtype=np.float32)[:, None]
    band = np.exp(-np.square((yy - 725.0) / 82.0))
    horizontal = resize_float(spectral_noise(1024, 3.0, 1010), 1024)
    horizontal = np.asarray(
        Image.fromarray(np.uint8(horizontal * 255), "L").resize((width, height), Image.Resampling.BICUBIC),
        dtype=np.float32,
    ) / 255.0
    fog_value = np.clip(band * (0.32 + horizontal * 0.48), 0.0, 1.0)
    fog[..., :3] = np.uint8(fog_value[..., None] * 126)
    fog[..., 3] = np.uint8(fog_value * 158)
    Image.fromarray(fog, "RGBA").save(folder / "far_fog_band_8k.png")

    sky_w, sky_h = 8192, 4096
    y = np.linspace(0.0, 1.0, sky_h, dtype=np.float32)[:, None]
    gradient = 0.030 + 0.034 * np.power(y, 2.4)
    sky_noise_small = spectral_noise(1024, 3.4, 1020)
    sky_noise = np.asarray(
        Image.fromarray(np.uint8(sky_noise_small * 255), "L").resize(
            (sky_w, sky_h), Image.Resampling.BICUBIC
        ),
        dtype=np.float32,
    ) / 255.0
    sky = np.clip(gradient + (sky_noise - 0.5) * 0.022, 0.012, 0.085)
    sky_rgb = np.stack((sky * 0.96, sky * 0.985, sky * 1.015), axis=-1)
    save_rgb(folder / "visible_archive_night_sky_8k.png", sky_rgb)


def generate_terrain_heightmap() -> None:
    size = 2048
    z, x = np.mgrid[0:size, 0:size].astype(np.float32)
    xn = x / (size - 1) * 2.0 - 1.0
    zn = z / (size - 1)

    base = resize_float(spectral_noise(1024, 3.2, 1100), size)
    detail = resize_float(spectral_noise(1024, 1.8, 1101), size)

    # The player starts on the high near ridge (bottom of the map).
    hill = np.clip((zn - 0.66) / 0.34, 0.0, 1.0)
    hill = hill * hill * (3.0 - 2.0 * hill)
    central_cut = np.exp(-np.square(xn / 0.34)) * np.exp(-np.square((zn - 0.46) / 0.18))
    trench_a = np.exp(-np.square((zn - 0.42 - 0.025 * np.sin(xn * 9.0)) / 0.012))
    trench_b = np.exp(-np.square((zn - 0.57 + 0.018 * np.sin(xn * 13.0)) / 0.010))

    height = 0.20 + base * 0.11 + detail * 0.018
    height += hill * 0.43
    height -= central_cut * 0.035
    height -= (trench_a + trench_b) * 0.045
    height = normalize(height)

    save_gray(OUT / "terrain" / "barrage_hill_height_2k.png", height, bits=16)


def generate_contact_sheet() -> None:
    files = [
        OUT / "steppe_ground" / "steppe_ground_albedo_4k.png",
        OUT / "steppe_ground" / "steppe_ground_normal_gl_4k.png",
        OUT / "steppe_ground" / "steppe_ground_roughness_4k.png",
        OUT / "concrete" / "aged_concrete_albedo_2k.png",
        OUT / "backgrounds" / "visible_archive_night_sky_8k.png",
        OUT / "backgrounds" / "far_berms_8k.png",
        OUT / "backgrounds" / "far_fence_8k.png",
        OUT / "backgrounds" / "far_fog_band_8k.png",
        OUT / "fx" / "smoke_atlas_4x4_2k.png",
        OUT / "fx" / "flash_radial_1k.png",
        OUT / "decals" / "puddle_mask_01_1k.png",
        OUT / "terrain" / "barrage_hill_height_2k.png",
    ]
    sheet = Image.new("RGB", (1536, 1024), (18, 18, 18))
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(files):
        image = Image.open(path).convert("RGB")
        image.thumbnail((360, 260), Image.Resampling.LANCZOS)
        col = index % 4
        row = index // 4
        x = col * 384 + 12
        y = row * 336 + 12
        sheet.paste(image, (x, y))
        draw.text((x, y + 265), path.stem[:43], fill=(210, 210, 210))
    sheet.save(OUT / "preview" / "generated_assets_contact_sheet.jpg", quality=92)


def generate_target_composition_preview() -> None:
    width, height = 2560, 1440
    horizon_y = int(height * 0.415)
    canvas = Image.new("RGB", (width, height), (5, 6, 7))

    sky = Image.open(OUT / "backgrounds" / "visible_archive_night_sky_8k.png").convert("RGB")
    sky = sky.resize((width, horizon_y + 160), Image.Resampling.LANCZOS)
    canvas.paste(sky, (0, 0))

    ground_texture = Image.open(OUT / "steppe_ground" / "steppe_ground_albedo_4k.png").convert("RGB")
    ground_texture = ground_texture.resize((width, height - horizon_y), Image.Resampling.BICUBIC)
    ground_arr = np.asarray(ground_texture, dtype=np.float32) / 255.0
    vertical = np.linspace(0.66, 0.34, height - horizon_y, dtype=np.float32)[:, None, None]
    ground_arr = np.clip(ground_arr * vertical, 0.0, 1.0)
    canvas.paste(Image.fromarray(np.uint8(ground_arr * 255), "RGB"), (0, horizon_y))

    for file_name, y, opacity in (
        ("far_fog_band_8k.png", horizon_y - 270, 0.65),
        ("far_berms_8k.png", horizon_y - 250, 0.95),
        ("far_fence_8k.png", horizon_y - 238, 0.78),
    ):
        layer = Image.open(OUT / "backgrounds" / file_name).convert("RGBA")
        layer = layer.resize((width, 360), Image.Resampling.LANCZOS)
        if opacity < 1.0:
            alpha = layer.getchannel("A").point(lambda value: int(value * opacity))
            layer.putalpha(alpha)
        canvas.paste(layer, (0, y), layer)

    glow_wide = Image.new("L", (width, height), 0)
    glow_mid = Image.new("L", (width, height), 0)
    core = Image.new("L", (width, height), 0)
    draw_wide = ImageDraw.Draw(glow_wide)
    draw_mid = ImageDraw.Draw(glow_mid)
    draw_core = ImageDraw.Draw(core)

    hero = [
        ((0.12, 0.43), (0.21, -0.10), (0.44, 0.08), 1.0),
        ((0.27, 0.43), (0.33, -0.12), (0.48, 0.02), 1.0),
        ((0.43, 0.44), (0.61, 0.12), (0.78, 0.29), 0.86),
        ((0.92, 0.43), (0.84, -0.12), (0.64, 0.08), 1.0),
        ((-0.04, 0.04), (0.29, -0.10), (0.70, 0.16), 0.72),
        ((0.18, 0.29), (0.34, -0.05), (0.63, 0.09), 0.70),
        ((0.33, 0.27), (0.52, -0.06), (0.82, 0.06), 0.64),
        ((0.56, 0.12), (0.77, -0.08), (1.05, 0.16), 0.76),
    ]
    rng = np.random.default_rng(667)
    curves = list(hero)
    for _ in range(34):
        sx = rng.uniform(-0.08, 1.08)
        sy = rng.uniform(0.35, 0.46)
        ex = rng.uniform(-0.12, 1.12)
        ey = rng.uniform(0.02, 0.38)
        apex_x = (sx + ex) * 0.5 + rng.uniform(-0.12, 0.12)
        apex_y = rng.uniform(-0.14, 0.22)
        curves.append(((sx, sy), (apex_x, apex_y), (ex, ey), rng.uniform(0.26, 0.62)))

    for start, control, end, energy in curves:
        points = []
        for i in range(180):
            t = i / 179.0
            omt = 1.0 - t
            x = omt * omt * start[0] + 2.0 * omt * t * control[0] + t * t * end[0]
            y = omt * omt * start[1] + 2.0 * omt * t * control[1] + t * t * end[1]
            points.append((int(x * width), int(y * height)))
        draw_wide.line(points, fill=int(90 * energy), width=max(8, int(26 * energy)))
        draw_mid.line(points, fill=int(150 * energy), width=max(3, int(9 * energy)))
        draw_core.line(points, fill=int(255 * energy), width=max(1, int(3.2 * energy)))

    for x_norm, energy in ((0.12, 1.0), (0.27, 1.0), (0.43, 0.9), (0.92, 1.0), (0.67, 0.65)):
        x = int(x_norm * width)
        y = horizon_y + 24
        for radius, alpha in ((105, 48), (48, 115), (14, 255)):
            draw_wide.ellipse((x - radius, y - radius, x + radius, y + radius), fill=int(alpha * energy))

    glow_wide = glow_wide.filter(ImageFilter.GaussianBlur(18.0))
    glow_mid = glow_mid.filter(ImageFilter.GaussianBlur(5.0))
    base = np.asarray(canvas, dtype=np.float32) / 255.0
    light = np.asarray(glow_wide, dtype=np.float32) / 255.0 * 0.82
    light += np.asarray(glow_mid, dtype=np.float32) / 255.0 * 0.92
    light += np.asarray(core, dtype=np.float32) / 255.0 * 1.65
    base += light[..., None]

    # Wet, broken reflections below the launch line.
    yy, xx = np.mgrid[0:height, 0:width]
    for x_norm, energy in ((0.12, 1.0), (0.27, 1.0), (0.43, 0.85), (0.92, 0.9)):
        x0 = x_norm * width
        reflection = np.exp(-np.square((xx - x0) / 95.0))
        reflection *= np.exp(-np.square((yy - (horizon_y + 210)) / 220.0))
        breakup = 0.45 + 0.55 * np.sin(yy * 0.21 + xx * 0.017) ** 2
        base += (reflection * breakup * energy * 0.09)[..., None]

    grain = rng.normal(0.0, 0.021, (height, width, 1)).astype(np.float32)
    base += grain * (1.0 - np.clip(base.mean(axis=2, keepdims=True), 0.0, 1.0) * 0.72)
    base = np.clip(base, 0.0, 1.0)
    luminance = base[..., 0] * 0.22 + base[..., 1] * 0.70 + base[..., 2] * 0.08
    silver = np.stack((luminance * 0.965, luminance * 0.985, luminance * 1.015), axis=-1)
    Image.fromarray(np.uint8(np.clip(silver, 0.0, 1.0) * 255), "RGB").save(
        OUT / "preview" / "target_composition_preview_2560x1440.jpg", quality=94
    )


def main() -> None:
    ensure_dirs()
    generate_steppe_ground()
    generate_concrete()
    generate_metal()
    generate_decals()
    generate_fx()
    generate_backgrounds()
    generate_terrain_heightmap()
    generate_contact_sheet()
    generate_target_composition_preview()
    print(f"Generated assets in {OUT}")


if __name__ == "__main__":
    main()
