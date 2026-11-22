#!/usr/bin/env python3
"""Inspect four actual Godot-rendered PNGs; never fabricate frames.
The pixel gate proves that two different architecture assets are visible,
not that either passes professional art direction or production FPS.
"""
from pathlib import Path
import json

from PIL import Image, ImageChops, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "tests"
pairs = ("residence", "library")
audit = []
sheet = Image.new("RGB", (1280, 720 * len(pairs)), "white")
for i, name in enumerate(pairs):
    before = ROOT / f"v35_before_{name}.png"
    after = ROOT / f"v35_after_{name}.png"
    assert before.is_file() and after.is_file(), f"missing genuine screenshot for {name}"
    with Image.open(before) as b, Image.open(after) as a:
        b = b.convert("RGB")
        a = a.convert("RGB")
        assert b.size == a.size and b.width >= 720 and b.height >= 400
        b.thumbnail((640, 720))
        a.thumbnail((640, 720))
        # Compare original equivalent-size images, not an invented Photoshop diff.
        original_b = Image.open(before).convert("RGB")
        original_a = Image.open(after).convert("RGB")
        diff = ImageChops.difference(original_b, original_a).convert("RGB")
        hist = diff.histogram()
        px = list(diff.getdata())
        visible = sum(1 for r,g,bl in px if max(r,g,bl) > 25)
        proportion = visible / len(px)
        assert proportion >= .012, f"{name}: v35 not visibly different ({proportion:.3%})"
        audit.append({"lot": name, "before": before.name, "after": after.name,
                      "pixels_changed_over_25": visible,
                      "pixel_fraction_changed": round(proportion, 5)})
        sheet.paste(b, (0, 720*i))
        sheet.paste(a, (640, 720*i))
sheet_path = ROOT / "v35_same_camera_architecture_comparison.jpg"
sheet.save(sheet_path, quality=89)
(ROOT / "v35_architecture_pixel_audit.json").write_text(
    json.dumps({"version": "V0.35", "real_render_diffs": audit,
                "art_certification": False, "production_release": False},
               indent=2) + "\n", encoding="utf-8")
print("V35 ACTUAL GODOT ARCHITECTURE PIXEL GATE PASS:", json.dumps(audit))
