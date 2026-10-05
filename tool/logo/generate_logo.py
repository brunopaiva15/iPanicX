"""Procedural iPanicX app icon (Codenotch family, 3D).

    pip install numpy scipy pillow
    python3 tool/logo/generate_logo.py [out_dir] [--install]

Writes icon_1024.png (transparent) and smaller sizes to out_dir; --install
also replaces the macOS AppIcon set, windows/runner/resources/app_icon.ico and
assets/logo/iPanicX.png. The output is deterministic (fixed seed).
Everything is generated: fluid paint texture (line-integral convolution of
noise along a burst flow field), squircle tile with thickness, bevel and gloss,
a recessed notch on the right (as in Codenotch) holding a raised gauge ring
whose arc heats up to the app's "critical" orange, and a "!" mark.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

S = 2048  # working size (downsampled at the end)
RNG = np.random.default_rng(7)

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)


# --------------------------------------------------------------------------
# helpers

def smooth_noise(shape, sigma, rng=RNG):
    n = ndi.gaussian_filter(rng.standard_normal(shape).astype(np.float32), sigma)
    n -= n.min()
    n /= n.max() + 1e-9
    return n


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def sd_round_box(px, py, cx, cy, hw, hh, r):
    qx = np.abs(px - cx) - (hw - r)
    qy = np.abs(py - cy) - (hh - r)
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def smooth_max(a, b, k):
    h = np.clip(0.5 - 0.5 * (b - a) / k, 0, 1)
    return a * h + b * (1 - h) + k * h * (1 - h)


def palette(t, stops):
    t = np.clip(t, 0, 1)
    pos = np.array([s[0] for s in stops], np.float32)
    cols = np.array([s[1] for s in stops], np.float32) / 255.0
    out = np.empty(t.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(t, pos, cols[:, c])
    return out


def cover(alpha):
    return np.clip(alpha, 0, 1)[..., None]


# --------------------------------------------------------------------------
# geometry (in working pixels)

C = S / 2
TILE_HALF = S * 0.405           # tile half size
TILE_R = S * 0.185              # corner radius (squircle-like)
DEPTH = S * 0.024               # extrusion thickness
TILE_CY = C - DEPTH * 0.5       # lift the face so face+side stay centred

tile = sd_round_box(xx, yy, C, TILE_CY, TILE_HALF, TILE_HALF, TILE_R)

# Notch: rounded slot opening on the right edge, concave fillets.
SLOT_CX = C + TILE_HALF * 0.62
SLOT_CY = TILE_CY
SLOT_HW = TILE_HALF * 0.62
SLOT_HH = TILE_HALF * 0.30
slot = sd_round_box(xx, yy, SLOT_CX, SLOT_CY, SLOT_HW, SLOT_HH, SLOT_HH * 0.78)
face_sd = smooth_max(tile, -slot, S * 0.03)   # face = tile minus slot
notch_sd = np.maximum(tile, slot)             # recessed well inside tile

RING_CX = C + TILE_HALF * 0.535
RING_CY = TILE_CY
RING_R = SLOT_HH * 0.60
RING_W = SLOT_HH * 0.17


# --------------------------------------------------------------------------
# fluid paint texture

def paint_texture():
    n = 1024
    gy, gx = np.mgrid[0:n, 0:n].astype(np.float32)
    # Burst from the lower-left corner, bent by low-frequency noise.
    ox, oy = -0.15 * n, 1.12 * n
    base = np.arctan2(gy - oy, gx - ox)
    warp = (smooth_noise((n, n), 60) - 0.5) * 1.3 + (smooth_noise((n, n), 18) - 0.5) * 0.5
    ang = base + warp
    dx, dy = np.cos(ang), np.sin(ang)

    # Mostly soft clumps of pigment, a little fine grain.
    seed = 0.25 * RNG.random((n, n)).astype(np.float32) \
        + 0.75 * smooth_noise((n, n), 2.6)
    acc = np.zeros((n, n), np.float32)
    wsum = 0.0
    steps, h = 40, 3.0
    for k in range(-steps, steps + 1):
        w = np.exp(-(k / steps) ** 2 * 2.2)
        sx = gx + dx * k * h
        sy = gy + dy * k * h
        acc += w * ndi.map_coordinates(seed, [sy, sx], order=1, mode='reflect')
        wsum += w
    lic = ndi.gaussian_filter(acc / wsum, 0.9)
    lic = (lic - lic.mean()) / (lic.std() + 1e-6)
    # Large soft clouds so the paint reads as powder, not hair.
    cloud = smooth_noise((n, n), 34)

    r = np.hypot(gx - ox, gy - oy) / (1.55 * n)
    t = r + 0.035 * lic + (smooth_noise((n, n), 40) - 0.5) * 0.35
    hot = [
        (0.00, (8, 6, 22)),
        (0.30, (40, 18, 92)),
        (0.40, (112, 36, 196)),
        (0.48, (214, 40, 150)),
        (0.56, (255, 46, 84)),
        (0.64, (255, 63, 0)),      # Notch.critical
        (0.73, (255, 138, 28)),
        (0.82, (255, 196, 88)),
        (0.92, (255, 232, 206)),
        (1.00, (255, 246, 240)),
    ]
    col = palette(t, hot)
    # Streak relief: brighten/darken along the strokes.
    col *= (1.0 + 0.09 * np.tanh(lic) + 0.12 * (cloud - 0.5))[..., None]
    # Glow: a blurred copy lifts the bright areas like backlit pigment.
    glow = ndi.gaussian_filter(col, (14, 14, 0))
    col = 1 - (1 - col) * (1 - 0.35 * glow)

    # Dark, jagged left side (like Codenotch's black paint).
    edge = (gx + gy * 0.55) / n - 0.58 + (smooth_noise((n, n), 26) - 0.5) * 0.42 \
        + 0.05 * lic
    dark = 1 - smoothstep(-0.02, 0.05, edge)
    dark_col = np.stack([0.035 + 0.03 * smooth_noise((n, n), 8)] * 3, -1)
    dark_col *= (1.0 + 0.25 * np.clip(lic, -1, 2))[..., None] * 0.9
    col = col * (1 - dark[..., None]) + dark_col * dark[..., None]

    # Speckles near the boundary and in the dark.
    sp = (RNG.random((n, n)) > 0.9965).astype(np.float32)
    sp = ndi.gaussian_filter(sp, 0.7) * 6
    near = np.exp(-(edge / 0.12) ** 2) * 0.9 + dark * 0.35
    col += (sp * near)[..., None] * np.array([1.0, 0.9, 0.95], np.float32)
    col = np.clip(col, 0, 1)

    img = Image.fromarray((col * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
    grain = (RNG.standard_normal((S, S)).astype(np.float32) * 0.018)[..., None]
    return np.clip(np.asarray(img, np.float32) / 255 + grain, 0, 1)


# --------------------------------------------------------------------------
# composition

def lit_bevel(sd, width, light=(-0.55, -0.7, 0.45)):
    """Lambert shading of a rounded bevel along the inside of a shape."""
    hgt = smoothstep(0, width, -sd)
    gy_, gx_ = np.gradient(hgt)
    nz = np.full_like(hgt, 1.0 / width)
    nrm = np.sqrt(gx_ ** 2 + gy_ ** 2 + nz ** 2)
    lx, ly, lz = light
    ln = np.sqrt(lx * lx + ly * ly + lz * lz)
    return (-gx_ * lx - gy_ * ly + nz * lz) / nrm / ln  # ~[-1, 1]


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    aa = 1.5  # anti-aliasing width (working px)
    rgb = np.zeros((S, S, 3), np.float32)
    alpha = np.zeros((S, S), np.float32)

    def over(col, a):
        nonlocal rgb, alpha
        a = np.clip(a, 0, 1)
        rgb = col * a[..., None] + rgb * (1 - a[..., None])
        alpha = a + alpha * (1 - a)

    # 1. Soft drop shadow.
    sh = cover(-tile)[..., 0]
    sh = ndi.shift(sh, (DEPTH * 2.2, 0), order=1)
    sh = ndi.gaussian_filter(sh, S * 0.022) * 0.55
    over(np.zeros((S, S, 3), np.float32), sh)

    # 2. Extruded side: stacked copies of the tile, darker going down.
    steps = int(DEPTH)
    for i in range(steps, 0, -1):
        sd_i = ndi.shift(tile, (i, 0), order=1, mode='nearest')
        a_i = smoothstep(aa, -aa, sd_i)
        k = i / steps
        side = np.array([0.30, 0.07, 0.04]) * (1 - k) + np.array([0.08, 0.02, 0.03]) * k
        # Brighter rim on the left-lit edge.
        shade = 0.75 + 0.25 * smoothstep(C + TILE_HALF, C - TILE_HALF, xx)
        over(side[None, None, :] * shade[..., None], a_i)

    # 3. Face: paint texture with bevel lighting and gloss.
    tex = paint_texture()
    shade = lit_bevel(face_sd, S * 0.022)
    face = tex * (0.86 + 0.32 * shade)[..., None]
    # Specular rim highlight on the bevel.
    rim = np.clip(shade - 0.55, 0, 1) * smoothstep(0, S * 0.02, -face_sd) \
        * (1 - smoothstep(S * 0.02, S * 0.035, -face_sd))
    face += rim[..., None] * 0.35
    # Glossy sheen across the upper half.
    gloss_mask = smoothstep(TILE_CY + TILE_HALF * 0.15, TILE_CY - TILE_HALF, yy) \
        * smoothstep(S * 0.01, S * 0.06, -face_sd)
    face = face + (1 - face) * (gloss_mask * 0.22)[..., None]
    over(np.clip(face, 0, 1), smoothstep(aa, -aa, face_sd))

    # 4. Recessed notch: black well with inner shadow and a lit lower lip.
    well_a = smoothstep(aa, -aa, notch_sd)
    depth = smoothstep(0, S * 0.05, -notch_sd)
    inner = ndi.gaussian_filter(np.clip(-ndi.shift(notch_sd, (S * 0.012, S * 0.006), order=1), 0, None), 1)
    occl = 1 - smoothstep(0, S * 0.045, inner)
    well = np.full((S, S, 3), 0.018, np.float32)
    well *= (1 - 0.6 * occl)[..., None]
    lip = (1 - smoothstep(0, S * 0.012, -notch_sd)) * smoothstep(SLOT_CY, SLOT_CY + SLOT_HH, yy)
    well += (lip * 0.16)[..., None] * np.array([1.0, 0.55, 0.4], np.float32)
    well += (depth * 0.0)[..., None]
    over(well, well_a)

    # 5. Gauge ring (track + hot arc) raised from the well.
    dx_, dy_ = xx - RING_CX, yy - RING_CY
    dist = np.hypot(dx_, dy_)
    cross = (dist - RING_R) / RING_W            # -1..1 across the ring
    ring_a = smoothstep(1 + aa / RING_W, 1 - aa / RING_W, np.abs(cross))
    nz = np.sqrt(np.clip(1 - cross ** 2, 0, 1))
    nx, ny = cross * dx_ / (dist + 1e-6), cross * dy_ / (dist + 1e-6)
    lam = np.clip(-0.5 * nx - 0.65 * ny + 0.58 * nz, 0, 1)
    spec = lam ** 18

    # Ring shadow on the well floor.
    rs = ndi.gaussian_filter(ndi.shift(ring_a, (S * 0.008, S * 0.004), order=1), S * 0.006)
    over(np.zeros((S, S, 3), np.float32), rs * 0.7)

    track = np.array([0.20, 0.20, 0.22], np.float32)
    over(track * (0.45 + 0.75 * lam)[..., None] + spec[..., None] * 0.25, ring_a)

    # Arc: clockwise from 12 o'clock, gap at the top-right, white -> orange.
    theta = (np.degrees(np.arctan2(dx_, -dy_)) + 360) % 360   # 0 at top, cw
    start, sweep = 42.0, 300.0
    u = ((theta - start) % 360) / sweep                         # 0..1 on arc
    on_arc = (u <= 1).astype(np.float32)
    # Round caps.
    def cap(deg):
        a = np.radians(deg)
        cx_, cy_ = RING_CX + RING_R * np.sin(a), RING_CY - RING_R * np.cos(a)
        return smoothstep(RING_W + aa, RING_W - aa, np.hypot(xx - cx_, yy - cy_))
    arc_a = np.maximum(ring_a * on_arc, np.maximum(cap(start), cap(start + sweep)))
    # In the gap, the caps take the colour of the nearest arc end.
    past = (theta - start) % 360 - sweep
    u = np.where(u > 1, np.where(past > (360 - sweep) / 2, 0.0, 1.0), u)
    arc_col = palette(np.clip(u, 0, 1), [
        (0.0, (255, 255, 255)), (0.55, (255, 236, 220)), (0.82, (255, 140, 60)),
        (1.0, (255, 63, 0)),
    ])
    end_glow = ndi.gaussian_filter(cap(start + sweep), S * 0.02) * 1.6
    over(np.array([1.0, 0.25, 0.0], np.float32)[None, None, :] * 1.0,
         np.clip(end_glow, 0, 0.55) * well_a)
    over(np.clip(arc_col * (0.55 + 0.6 * lam)[..., None] + spec[..., None] * 0.6, 0, 1), arc_a)

    # 6. "!" in the centre of the ring.
    bar = sd_round_box(xx, yy, RING_CX, RING_CY - RING_R * 0.16, RING_W * 0.42,
                       RING_R * 0.36, RING_W * 0.42)
    dot = np.hypot(xx - RING_CX, yy - (RING_CY + RING_R * 0.40)) - RING_W * 0.5
    ex = np.minimum(bar, dot)
    ex_a = smoothstep(aa, -aa, ex)
    ex_shade = lit_bevel(ex, RING_W * 0.35)
    over(np.zeros((S, S, 3), np.float32),
         ndi.gaussian_filter(ndi.shift(ex_a, (S * 0.006, S * 0.003), order=1), S * 0.004) * 0.6)
    over(np.clip(np.ones(3, np.float32)[None, None, :] * (0.78 + 0.3 * ex_shade)[..., None], 0, 1), ex_a)

    out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    img = Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA')
    big = img.resize((1024, 1024), Image.LANCZOS)
    big.save(os.path.join(out_dir, 'icon_1024.png'))
    for s in (16, 32, 48, 64, 128, 256, 512):
        big.resize((s, s), Image.LANCZOS).save(os.path.join(out_dir, f'icon_{s}.png'))
    print('written to', out_dir)
    return big


def install(big, root):
    """Writes the macOS app icon set, the Windows .ico and the README logo."""
    mac = os.path.join(root, 'macos/Runner/Assets.xcassets/AppIcon.appiconset')
    for s in (16, 32, 64, 128, 256, 512, 1024):
        big.resize((s, s), Image.LANCZOS).save(os.path.join(mac, f'app_icon_{s}.png'))
    big.save(os.path.join(root, 'windows/runner/resources/app_icon.ico'),
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    os.makedirs(os.path.join(root, 'assets/logo'), exist_ok=True)
    big.save(os.path.join(root, 'assets/logo/iPanicX.png'))
    print('installed into', root)


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--install']
    icon = main(args[0] if args else 'build/logo')
    if '--install' in sys.argv:
        install(icon, os.path.join(os.path.dirname(__file__), '..', '..'))
