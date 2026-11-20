#!/usr/bin/env python3
"""Inspect original Godot 1280x720 skinned CC0 apparel against bare base.

Pixel difference proves visible cloth; garment intersections, fit and final
modern-city aesthetic are separate human-review blockers.
"""
from __future__ import annotations
from pathlib import Path
import json
from PIL import Image,ImageDraw
import numpy as np

ROOT=Path(__file__).resolve().parents[1]/"tests"
report=json.loads((ROOT/"v30_outfit_render.json").read_text(encoding="utf8"))
assert report["ok"] and len(report["pairs"])==5
sheet=Image.new("RGB",(1200,5*380),(30,30,34))
draw=ImageDraw.Draw(sheet)
rows=[]
for index,sample in enumerate(report["pairs"]):
    original=Image.open(ROOT/sample["base_png"]).convert("RGB")
    garment=Image.open(ROOT/sample["clothing_png"]).convert("RGB")
    assert original.size==garment.size and original.width>=720 and original.height>=400
    import numpy as np
    a=np.asarray(original,dtype=np.int16)
    b=np.asarray(garment,dtype=np.int16)
    changed=int((np.max(np.abs(a-b),axis=2)>20).sum())
    if changed<500:
        raise RuntimeError("Clothing loaded but did not alter actual rendered mesh: "+str(sample))
    y=index*380
    sheet.paste(original.resize((600,350),Image.Resampling.LANCZOS),(0,y))
    sheet.paste(garment.resize((600,350),Image.Resampling.LANCZOS),(600,y))
    draw.text((10,y+357),f"{sample['motion']} t={sample['fraction']} - original skinned base",fill="white")
    draw.text((610,y+357),f"same pose + 65-joint CC0 outfit; changed pixels={changed}",fill="white")
    rows.append({"motion":sample["motion"],"phase":sample["fraction"],"changed_pixels_gt20":changed})
path=ROOT/"v30_cc0_outfit_real_render_review.jpg"
sheet.save(path,quality=87)
assert path.stat().st_size>70000
(ROOT/"v30_outfit_pixel_gate.json").write_text(json.dumps({"verified_pair_count":len(rows),
    "rendered_cloth_changed_pixels":rows,
    "human_visual_approval":False,
    "note":"Pixel differences are not enough for realistic fitted urban apparel or collision/feet pass."},indent=2)+"\n",encoding="utf8")
print("V30 REAL SKINNED CLOTHING PIXEL GATE PASS:",json.dumps(rows))
