"""Render the dimensional fractal banner on macOS using Metal; encode a GIF.

python3 -m pip install -r scripts/requirements.txt
python3 scripts/render_banner.py
"""
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "profile" / "assets"
WIDTH, HEIGHT, FRAMES, DURATION = 480, 375, 112, 100


def title(image):
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 17)
    text = "trotterization"
    spacing = 4
    width = sum(draw.textlength(c, font=font) for c in text) + spacing*(len(text)-1)
    x = (image.width-width)/2
    for char in text:
        draw.text((round(x), 17), char, font=font, fill=(207, 219, 235))
        x += draw.textlength(char, font=font)+spacing
    return image


def render():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="trotterization-") as temp:
        temp = Path(temp)
        renderer = temp / "renderer"
        subprocess.run(["swiftc", "-O", "scripts/render_fractal.swift", "-o", str(renderer)],
                       check=True, cwd=ROOT)
        subprocess.run([str(renderer), str(WIDTH), str(HEIGHT), str(FRAMES), str(temp)],
                       check=True, cwd=ROOT)
        # Sample the entire loop for a stable palette across all frames.
        samples = [np.array(title(Image.open(temp / f"{i:04}.png").convert("RGB")))[::3, ::3]
                   for i in range(0, FRAMES, 8)]
        strip = Image.fromarray(np.concatenate(samples, axis=0))
        palette = strip.quantize(colors=96, method=Image.Quantize.MEDIANCUT)
        frames = []
        for i in range(FRAMES):
            rgb = title(Image.open(temp / f"{i:04}.png").convert("RGB"))
            frame = rgb.quantize(palette=palette, dither=Image.Dither.NONE)
            frame = frame.resize((640, 500), Image.Resampling.NEAREST)
            if i == 0:
                frame.save(OUT / "dimensional-fractal-poster.png")
            frames.append(frame)
        frames[0].save(OUT / "dimensional-fractal.gif", save_all=True,
                       append_images=frames[1:], duration=DURATION, loop=0,
                       optimize=True, disposal=1)
    print(f"Saved {FRAMES} frames / {FRAMES*DURATION/1000:g}s / "
          f"{(OUT / 'dimensional-fractal.gif').stat().st_size/1e6:.2f} MB")


if __name__ == "__main__":
    render()
