const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT_DIR = path.join(
  process.cwd(),
  "art",
  "backdrops",
  "mountains",
  "megawall",
  "textures",
  "production"
);

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

function clamp01(v) {
  return clamp(v, 0, 1);
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function smoothstep(edge0, edge1, x) {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

function gauss(x, center, width) {
  const n = (x - center) / width;
  return Math.exp(-n * n);
}

function fract(v) {
  return v - Math.floor(v);
}

function hash2(x, y, seed) {
  return fract(Math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453123);
}

function valueNoise(x, y, scale, seed) {
  const sx = x / scale;
  const sy = y / scale;
  const ix = Math.floor(sx);
  const iy = Math.floor(sy);
  const fx = sx - ix;
  const fy = sy - iy;
  const ux = fx * fx * (3 - 2 * fx);
  const uy = fy * fy * (3 - 2 * fy);
  const a = hash2(ix, iy, seed);
  const b = hash2(ix + 1, iy, seed);
  const c = hash2(ix, iy + 1, seed);
  const d = hash2(ix + 1, iy + 1, seed);
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uy);
}

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i += 1) {
    c = (c >>> 8) ^ CRC_TABLE[(c ^ buf[i]) & 0xff];
  }
  return (c ^ -1) >>> 0;
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function chunk(type, payload) {
  const typeBuf = Buffer.from(type, "ascii");
  const len = Buffer.alloc(4);
  len.writeUInt32BE(payload.length, 0);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, payload])), 0);
  return Buffer.concat([len, typeBuf, payload, crc]);
}

function writePng(file, width, height, colorType, bytesPerPixel, pixelFn) {
  const rowBytes = width * bytesPerPixel + 1;
  const raw = Buffer.allocUnsafe(rowBytes * height);
  let offset = 0;
  for (let y = 0; y < height; y += 1) {
    raw[offset] = 0;
    offset += 1;
    for (let x = 0; x < width; x += 1) {
      const px = pixelFn(x, y, width, height);
      if (bytesPerPixel === 1) {
        raw[offset] = px;
        offset += 1;
      } else if (bytesPerPixel === 3) {
        raw[offset] = px[0];
        raw[offset + 1] = px[1];
        raw[offset + 2] = px[2];
        offset += 3;
      } else {
        raw[offset] = px[0];
        raw[offset + 1] = px[1];
        raw[offset + 2] = px[2];
        raw[offset + 3] = px[3];
        offset += 4;
      }
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = colorType;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 7 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.writeFileSync(file, png);
  console.log(`${path.basename(file)} ${width}x${height}`);
}

function makeRidge(width, height, cfg) {
  const ridge = new Float32Array(width);
  for (let x = 0; x < width; x += 1) {
    const nx = x / Math.max(1, width - 1);
    let y = height * cfg.base;
    for (let k = 0; k < cfg.waves.length; k += 1) {
      const wave = cfg.waves[k];
      y += Math.sin(nx * Math.PI * 2 * wave.freq + wave.phase) * height * wave.amp;
    }
    for (const peak of cfg.peaks) {
      y -= height * peak.height * gauss(nx, peak.center, peak.width);
    }
    const chipped = (valueNoise(x, 3, width / 96, cfg.seed + 17) - 0.5) * height * cfg.chip;
    ridge[x] = clamp(y + chipped, height * cfg.min, height * cfg.max);
  }
  return ridge;
}

function makeLayer(width, height, cfg) {
  const ridge = makeRidge(width, height, cfg);
  return {
    cfg,
    ridge,
    sample(x, y) {
      const r = ridge[x];
      const alpha = smoothstep(r - height * 0.012, r + height * 0.018, y);
      const body = clamp01((y - r) / Math.max(1, height - r));
      const gradient = Math.abs(ridge[Math.min(width - 1, x + 1)] - ridge[Math.max(0, x - 1)]) / height;
      const nx = x / Math.max(1, width - 1);
      const ny = y / Math.max(1, height - 1);
      const macro = valueNoise(x, y, width / 18, cfg.seed + 31);
      const mid = valueNoise(x, y, width / 72, cfg.seed + 43);
      const fine = valueNoise(x, y, width / 230, cfg.seed + 59);
      const verticalCuts = Math.pow(0.5 + 0.5 * Math.sin(nx * Math.PI * 72 + mid * 6.0), 4.0);
      const diagonalStrata = 0.5 + 0.5 * Math.sin((nx * cfg.strataX + ny * cfg.strataY + macro * 0.75) * Math.PI * 2);
      const shadow = clamp01(0.26 + gradient * 12.0 + verticalCuts * 0.28 + (1.0 - macro) * 0.22);
      const snowLine = cfg.snowLine + (macro - 0.5) * 0.17 + gradient * 1.15;
      const summit = 1.0 - body;
      const snow = clamp01(smoothstep(snowLine, 0.98, summit) * (0.55 + gradient * 5.0) + (fine - 0.56) * 1.3);
      const hazeDepth = clamp01(alpha * (0.22 + body * 0.78));
      return {
        alpha,
        body,
        gradient,
        macro,
        mid,
        fine,
        verticalCuts,
        diagonalStrata,
        shadow,
        snow,
        hazeDepth,
      };
    },
  };
}

function toByte(v) {
  return clamp(Math.round(v), 0, 255);
}

function rgb(r, g, b) {
  return [toByte(r), toByte(g), toByte(b)];
}

function mountainColor(layer, x, y, width, height, night, tint, snowBoost) {
  const s = layer.sample(x, y);
  if (s.alpha <= 0.003) {
    return [0, 0, 0];
  }
  const cold = tint.cold;
  const lowerDust = tint.dust;
  const exposed = 1.0 - s.body;
  const rockMix = clamp01(0.36 + s.macro * 0.44 + s.diagonalStrata * 0.22 - s.shadow * 0.20);
  let r = lerp(cold[0], lowerDust[0], s.body * 0.72) * rockMix;
  let g = lerp(cold[1], lowerDust[1], s.body * 0.72) * (rockMix + 0.04);
  let b = lerp(cold[2], lowerDust[2], s.body * 0.65) * (rockMix + 0.08);

  const crevasse = s.verticalCuts * smoothstep(0.08, 0.7, s.body);
  r *= 1.0 - crevasse * 0.34;
  g *= 1.0 - crevasse * 0.35;
  b *= 1.0 - crevasse * 0.32;

  const snow = clamp01(s.snow * snowBoost);
  const dirtySnow = 0.68 + s.fine * 0.14 - s.shadow * 0.10;
  r = lerp(r, 169 * dirtySnow, snow * 0.82);
  g = lerp(g, 184 * dirtySnow, snow * 0.86);
  b = lerp(b, 191 * dirtySnow, snow * 0.9);

  const upperMist = smoothstep(0.72, 1.0, exposed) * 0.10;
  r = lerp(r, 124, upperMist);
  g = lerp(g, 139, upperMist);
  b = lerp(b, 144, upperMist);

  if (night) {
    const moon = snow * 0.46 + smoothstep(0.58, 1.0, exposed) * 0.15;
    r = lerp(r * 0.15, 40 + 58 * moon, 0.72);
    g = lerp(g * 0.15, 55 + 78 * moon, 0.72);
    b = lerp(b * 0.18, 84 + 106 * moon, 0.72);
  }

  return rgb(r * s.alpha, g * s.alpha, b * s.alpha);
}

function alphaByte(layer, x, y) {
  return toByte(layer.sample(x, y).alpha * 255);
}

function depthByte(layer, x, y) {
  const s = layer.sample(x, y);
  return toByte((0.18 + s.hazeDepth * 0.74) * s.alpha * 255);
}

function snowByte(layer, x, y) {
  const s = layer.sample(x, y);
  return toByte(s.snow * s.alpha * 255);
}

function hazePixel(x, y, width, height, mid) {
  const nx = x / Math.max(1, width - 1);
  const ny = y / Math.max(1, height - 1);
  const bandCenter = mid ? 0.48 : 0.62;
  const bandWidth = mid ? 0.34 : 0.22;
  const band = gauss(ny, bandCenter + Math.sin(nx * Math.PI * 2.0) * 0.035, bandWidth);
  const n = valueNoise(x, y, width / 54, mid ? 500 : 420);
  const streak = 0.5 + 0.5 * Math.sin(nx * Math.PI * (mid ? 21 : 16) + n * 2.3);
  const a = clamp01(band * (mid ? 0.42 : 0.58) * (0.78 + streak * 0.28));
  const r = mid ? 135 : 151;
  const g = mid ? 143 : 148;
  const b = mid ? 139 : 127;
  return [toByte(r + n * 12), toByte(g + n * 10), toByte(b + n * 8), toByte(a * 255)];
}

function cloudPixel(x, y, width, height) {
  const nx = x / Math.max(1, width - 1);
  const ny = y / Math.max(1, height - 1);
  const n1 = valueNoise(x, y, width / 34, 840);
  const n2 = valueNoise(x, y, width / 100, 841);
  const shelf = gauss(ny, 0.45 + Math.sin(nx * Math.PI * 3.1) * 0.05, 0.23);
  const torn = smoothstep(0.36, 0.82, n1 * 0.72 + n2 * 0.42);
  const a = clamp01(shelf * torn * 0.58);
  const shade = 0.72 + n1 * 0.22 - ny * 0.20;
  return [toByte(116 * shade), toByte(127 * shade), toByte(133 * shade), toByte(a * 255)];
}

function shadowNoiseByte(x, y, width, height) {
  const n = valueNoise(x, y, width / 30, 980) * 0.62 + valueNoise(x, y, width / 7, 981) * 0.38;
  return toByte(smoothstep(0.32, 0.86, n) * 255);
}

function lightsPixel(x, y, width, height) {
  const nx = x / Math.max(1, width - 1);
  const ny = y / Math.max(1, height - 1);
  let v = 0;
  const lights = [
    [0.18, 0.72, 0.004, 0.012, 0.70],
    [0.31, 0.67, 0.003, 0.010, 0.58],
    [0.63, 0.76, 0.004, 0.012, 0.52],
    [0.79, 0.70, 0.003, 0.009, 0.48],
  ];
  for (const light of lights) {
    v += gauss(nx, light[0], light[2]) * gauss(ny, light[1], light[3]) * light[4];
  }
  const cool = clamp01(v);
  return [toByte(cool * 180), toByte(cool * 205), toByte(cool * 255)];
}

function writeLayerTextures(prefix, width, height, cfg, tint, snowBoost) {
  const layer = makeLayer(width, height, cfg);
  writePng(path.join(OUT_DIR, `${prefix}_day_${width >= 8192 ? "8k" : "4k"}.png`), width, height, 2, 3, (x, y, w, h) =>
    mountainColor(layer, x, y, w, h, false, tint, snowBoost)
  );
  writePng(path.join(OUT_DIR, `${prefix}_night_${width >= 8192 ? "8k" : "4k"}.png`), width, height, 2, 3, (x, y, w, h) =>
    mountainColor(layer, x, y, w, h, true, tint, snowBoost)
  );
  writePng(path.join(OUT_DIR, `${prefix}_alpha_${width >= 8192 ? "8k" : "4k"}.png`), width, height, 0, 1, (x, y) =>
    alphaByte(layer, x, y)
  );
  return layer;
}

function main() {
  ensureDir(OUT_DIR);

  const mainCfg = {
    seed: 1201,
    base: 0.28,
    min: 0.06,
    max: 0.53,
    chip: 0.030,
    snowLine: 0.50,
    strataX: 15,
    strataY: 8,
    waves: [
      { freq: 1.1, amp: 0.045, phase: 0.3 },
      { freq: 2.6, amp: 0.032, phase: 1.6 },
      { freq: 5.2, amp: 0.017, phase: 2.2 },
    ],
    peaks: [
      { center: 0.18, width: 0.055, height: 0.12 },
      { center: 0.40, width: 0.075, height: 0.16 },
      { center: 0.61, width: 0.050, height: 0.24 },
      { center: 0.78, width: 0.067, height: 0.13 },
    ],
  };

  const rearCfg = {
    seed: 2219,
    base: 0.22,
    min: 0.04,
    max: 0.48,
    chip: 0.022,
    snowLine: 0.42,
    strataX: 11,
    strataY: 5,
    waves: [
      { freq: 0.9, amp: 0.040, phase: 1.0 },
      { freq: 2.1, amp: 0.024, phase: 2.8 },
      { freq: 4.8, amp: 0.012, phase: 0.7 },
    ],
    peaks: [
      { center: 0.30, width: 0.085, height: 0.14 },
      { center: 0.56, width: 0.060, height: 0.19 },
      { center: 0.86, width: 0.090, height: 0.12 },
    ],
  };

  const foothillCfg = {
    seed: 3044,
    base: 0.50,
    min: 0.30,
    max: 0.72,
    chip: 0.018,
    snowLine: 0.92,
    strataX: 9,
    strataY: 4,
    waves: [
      { freq: 1.4, amp: 0.035, phase: 0.7 },
      { freq: 3.3, amp: 0.020, phase: 2.1 },
      { freq: 7.1, amp: 0.010, phase: 1.5 },
    ],
    peaks: [
      { center: 0.22, width: 0.12, height: 0.06 },
      { center: 0.52, width: 0.18, height: 0.07 },
      { center: 0.82, width: 0.13, height: 0.05 },
    ],
  };

  const coldTint = {
    cold: [70, 83, 88],
    dust: [82, 76, 66],
  };
  const rearTint = {
    cold: [78, 90, 96],
    dust: [86, 82, 74],
  };
  const foothillTint = {
    cold: [53, 56, 54],
    dust: [74, 66, 54],
  };

  const mainLayer = makeLayer(8192, 2048, mainCfg);
  writePng(path.join(OUT_DIR, "mountain_wall_day_8k.png"), 8192, 2048, 2, 3, (x, y, w, h) =>
    mountainColor(mainLayer, x, y, w, h, false, coldTint, 1.0)
  );
  writePng(path.join(OUT_DIR, "mountain_wall_night_8k.png"), 8192, 2048, 2, 3, (x, y, w, h) =>
    mountainColor(mainLayer, x, y, w, h, true, coldTint, 1.0)
  );
  writePng(path.join(OUT_DIR, "mountain_wall_alpha_8k.png"), 8192, 2048, 0, 1, (x, y) =>
    alphaByte(mainLayer, x, y)
  );
  writePng(path.join(OUT_DIR, "mountain_wall_depth_8k.png"), 8192, 2048, 0, 1, (x, y) =>
    depthByte(mainLayer, x, y)
  );
  writePng(path.join(OUT_DIR, "mountain_wall_snow_mask_8k.png"), 8192, 2048, 0, 1, (x, y) =>
    snowByte(mainLayer, x, y)
  );

  writeLayerTextures("rear_peaks", 8192, 2048, rearCfg, rearTint, 1.18);
  writeLayerTextures("foothills", 4096, 1024, foothillCfg, foothillTint, 0.1);

  const snowOverlay = makeLayer(8192, 2048, mainCfg);
  writePng(path.join(OUT_DIR, "snow_peaks_day_8k.png"), 8192, 2048, 2, 3, (x, y, w, h) => {
    const s = snowOverlay.sample(x, y);
    const snow = clamp01(s.snow * s.alpha * 1.35);
    return rgb(160 * snow, 176 * snow, 184 * snow);
  });
  writePng(path.join(OUT_DIR, "snow_peaks_night_8k.png"), 8192, 2048, 2, 3, (x, y, w, h) => {
    const s = snowOverlay.sample(x, y);
    const snow = clamp01(s.snow * s.alpha * 1.35);
    return rgb(42 * snow, 64 * snow, 98 * snow);
  });
  writePng(path.join(OUT_DIR, "snow_peaks_alpha_8k.png"), 8192, 2048, 0, 1, (x, y) => {
    const s = snowOverlay.sample(x, y);
    return toByte(clamp01(s.snow * s.alpha * 1.22) * 255);
  });

  writePng(path.join(OUT_DIR, "low_haze_4k.png"), 4096, 1024, 6, 4, (x, y, w, h) => hazePixel(x, y, w, h, false));
  writePng(path.join(OUT_DIR, "mid_haze_4k.png"), 4096, 1024, 6, 4, (x, y, w, h) => hazePixel(x, y, w, h, true));
  writePng(path.join(OUT_DIR, "low_clouds_4k.png"), 4096, 1024, 6, 4, cloudPixel);
  writePng(path.join(OUT_DIR, "cloud_shadow_noise_2k.png"), 2048, 1024, 0, 1, shadowNoiseByte);
  writePng(path.join(OUT_DIR, "night_lights_emission_mask_2k.png"), 2048, 512, 2, 3, lightsPixel);
}

main();
