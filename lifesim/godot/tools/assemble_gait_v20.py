#!/usr/bin/env python3
"""Make review-only GIF and frame sheet from real Godot V0.20 PNG captures."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "tests"
metrics = json.loads((ROOT / "v20_gait_metrics.json").read_text(encoding="utf-8"))
frames = metrics["frames"]
assert len(frames) == 20 and len(set(frames)) == 20, "no 20 unique captures"
images = []
for filename in frames:
    original = Image.open(ROOT / filename)
    assert original.size[0] >= 720 and original.size[1] >= 400
    images.append(original.convert("RGB").resize((800, 450), Image.Resampling.LANCZOS))
gif_frames = [im.quantize(colors=96, method=Image.Quantize.MEDIANCUT) for im in images]
gif_frames[0].save(
    ROOT / "v20_gait_sequence.gif", save_all=True, append_images=gif_frames[1:],
    duration=100, loop=0, optimize=False, disposal=2,
)
canvas = Image.new("RGB", (5 * 320, 4 * 192), (30, 32, 35))
draw = ImageDraw.Draw(canvas)
for i, im in enumerate(images):
    x, y = (i % 5) * 320, (i // 5) * 192
    thumb = im.resize((320, 180), Image.Resampling.LANCZOS)
    canvas.paste(thumb, (x, y))
    draw.text((x + 7, y + 180), f"Actual physics frame {i + 1:02d}", fill=(235, 235, 235))
canvas.save(ROOT / "v20_gait_contact_sheet.png")
assert (ROOT / "v20_gait_sequence.gif").stat().st_size > 50_000
assert (ROOT / "v20_gait_contact_sheet.png").stat().st_size > 50_000
print("V20 GAIT MEDIA PASS: 20 real Godot frames, GIF + contact sheet")
