"""Render a seamless, pixel-sized stereographic projection of a 4D torus.

Run: python3 -m pip install -r scripts/requirements.txt
     python3 scripts/render_banner.py
"""

from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "profile" / "assets"
W, H, SCALE, FRAMES = 480, 288, 2, 96
FONT = ImageFont.load_default()
GLYPHS = {
    "t": ["010", "111", "010", "010", "011"],
    "r": ["000", "110", "101", "100", "100"],
    "o": ["000", "010", "101", "101", "010"],
    "e": ["000", "010", "111", "100", "011"],
    "i": ["010", "000", "010", "010", "010"],
    "z": ["000", "111", "001", "010", "111"],
    "a": ["000", "011", "101", "101", "011"],
    "n": ["000", "110", "101", "101", "101"],
}


def wordmark(draw, x, y):
    for letter in "trotterization":
        for row, line in enumerate(GLYPHS[letter]):
            for col, bit in enumerate(line):
                if bit == "1":
                    draw.rectangle((x + col * 3, y + row * 3,
                                    x + col * 3 + 2, y + row * 3 + 2),
                                   fill=(234, 237, 243))
        x += 12


def render():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(47)
    # A Clifford torus: (cos u, sin u, cos v, sin v) / sqrt(2) in S^3.
    # A dense winding and a diffuse surface produce luminous particle filaments.
    count = 28000
    u = rng.uniform(0, math.tau, count)
    v = (3 * u + rng.normal(0, 0.085, count)) % math.tau
    v[:10000] = rng.uniform(0, math.tau, 10000)
    torus = np.array([np.cos(u), np.sin(u), np.cos(v), np.sin(v)]).T / np.sqrt(2)
    hue = ((u + v) / math.tau * 3).astype(int) % 3
    colors = np.array([[255, 55, 186], [84, 230, 250], [207, 255, 92]], dtype=float)
    weights = rng.uniform(0.25, 0.9, count)
    stars = rng.integers([28, 60], [W - 28, H - 42], (90, 2))

    # One shared palette avoids color flicker and preserves black exactly.
    palette = Image.new("P", (1, 1))
    values = [0, 14, 30, 54, 88, 134, 194, 255]
    palette.putpalette([c for r in values for g in values for b in [0, 54, 134, 255]
                        for c in (r, g, b)])
    frames = []
    for frame in range(FRAMES):
        theta = math.tau * frame / FRAMES
        points = torus.copy()
        for a, b, angle in [(0, 3, theta), (1, 2, theta), (0, 2, 0.6), (1, 3, 0.34)]:
            ca, sa = math.cos(angle), math.sin(angle)
            pa, pb = points[:, a].copy(), points[:, b].copy()
            points[:, a], points[:, b] = ca * pa - sa * pb, sa * pa + ca * pb
        xyz = points[:, :3] / (1.65 - points[:, 3:4])
        # A fixed camera tilt gives the projection a little depth.
        x = xyz[:, 0]
        y = xyz[:, 1] * 0.85 - xyz[:, 2] * 0.53
        z = xyz[:, 1] * 0.53 + xyz[:, 2] * 0.85
        screen = np.column_stack([W / 2 + x * 151, 153 + y * 106]).astype(int)
        valid = ((screen[:, 0] >= 24) & (screen[:, 0] < W - 24)
                 & (screen[:, 1] >= 59) & (screen[:, 1] < H - 40))
        cloud = np.zeros((H, W, 3), dtype=np.float32)
        intensity = weights * np.clip((z + 1.3) / 2, 0.18, 1)
        for channel in range(3):
            np.add.at(cloud[:, :, channel], (screen[valid, 1], screen[valid, 0]),
                      colors[hue[valid], channel] * intensity[valid] * 0.65)
        cloud = np.clip(cloud, 0, 255).astype(np.uint8)
        im = Image.fromarray(cloud)
        draw = ImageDraw.Draw(im)
        for sx, sy in stars:
            if not np.any(cloud[sy, sx]):
                draw.point((int(sx), int(sy)), fill=(21, 25, 34))
        wordmark(draw, 24, 21)
        draw.text((W - 112, 23), "4D / PROJECTION", fill=(123, 136, 151), font=FONT)
        draw.line((24, 49, W - 24, 49), fill=(26, 31, 40))
        for cx, cy, dx, dy in [(24, 66, 1, 1), (W - 25, 66, -1, 1),
                               (24, H - 44, 1, -1), (W - 25, H - 44, -1, -1)]:
            draw.line((cx, cy, cx + dx * 6, cy), fill=(64, 76, 87))
            draw.line((cx, cy, cx, cy + dy * 6), fill=(64, 76, 87))
        draw.text((24, H - 25), "SMALL STEPS. STRANGE DIMENSIONS.", fill=(156, 166, 180), font=FONT)
        draw.text((W - 112, H - 25), "S^3 -> R^3", fill=(124, 170, 162), font=FONT)
        im = im.quantize(palette=palette, dither=Image.Dither.NONE)
        im = im.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
        if frame == 0:
            im.save(OUT / "trotterization-poster.png")
        frames.append(im)
    frames[0].save(OUT / "trotterization.gif", save_all=True, append_images=frames[1:],
                   duration=[80, 80, 90] * (FRAMES // 3), loop=0,
                   optimize=False, disposal=1)
    print(f"Rendered {FRAMES} frames, 8-second loop: {OUT / 'trotterization.gif'}")


if __name__ == "__main__":
    render()
