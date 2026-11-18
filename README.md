# Trotterization profile

The public organization README lives in [`profile/README.md`](profile/README.md).

The banner is an original, ray-marched animation of changing 3D slices through a 4D hyperspherical fractal. Its recursive surface, dimensional slice, lighting, and orbital dust are rendered on the GPU. Regenerate it on macOS with Xcode command-line tools and a Metal-capable GPU:

```sh
python3 -m pip install -r scripts/requirements.txt
python3 scripts/render_banner.py
```

`profile/assets/dimensional-fractal.gif` is the 11.2-second looping banner. The PNG alongside it is a static preview. The Metal shader and Swift rendering harness live in `scripts/`; Python builds the shared palette and assembles the GIF.
