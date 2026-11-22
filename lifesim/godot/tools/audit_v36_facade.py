#!/usr/bin/env python3
"""Review four genuine Godot 1280x720 PNGs without hallucinated frames."""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parents[1] / "tests"
names = ["street", "oblique"]
audit = []
sheet = Image.new("RGB", (1280, 720 * 2), "#111820")
for i, name in enumerate(names):
    before = root / f"v36_before_{name}.png"
    after = root / f"v36_after_{name}.png"
    assert before.is_file() and after.is_file(), name
    with Image.open(before) as b, Image.open(after) as a:
        b = b.convert("RGB")
        a = a.convert("RGB")
        assert b.size == a.size and b.size[0] >= 720 and b.size[1] >= 400
        # Compare actual pixel data before scaling thumbnails.
        diff = ImageChops.difference(b,a)
        changed = sum(1 for px in diff.getdata() if max(px) > 25)
        ratio = changed / (b.width * b.height)
        assert ratio > 0.04, f"V36 CC0 meshes not visibly rendered: {name} {ratio:.2%}"
        audit.append({"camera":name,"before":before.name,"after":after.name,
                     "changed_rgb_pixels_gt25":changed,"fraction":round(ratio,5)})
        b.thumbnail((640, 720))
        a.thumbnail((640, 720))
        sheet.paste(b,(0,i*720))
        sheet.paste(a,(640,i*720))
sheet.save(root / "v36_actual_source_façade_comparison.jpg",quality=90)
(root / "v36_same_camera_pixel_audit.json").write_text(
    json.dumps({"ok":True,"art_approved":False,"web_released":False,
    "comparison":audit},indent=2)+"\n",encoding="utf-8")
print("V36 REAL GLB PIXEL GATE PASS:",json.dumps(audit))
