#!/usr/bin/env python3
"""Quantify before/after differences in REAL Godot viewport images.

Off and On images are rendered at the same timeline phase with the same camera,
not composited fake IK illustrations. This tests actual observable skin changes,
NOT an assessment of knee shape / shoe-floor contact quality.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageChops

root=Path(__file__).resolve().parents[1]/"tests"
report=json.loads((root/"v25_ik_render_metrics.json").read_text(encoding="utf-8"))
assert report.get("ok") is True
measurements={}
pairs_changed=0
pairs_significant=0
for motion in ("walk","run"):
    sheet=Image.new("RGB",(1280,390*4),(31,31,34))
    drawer=ImageDraw.Draw(sheet)
    per_motion=[]
    for i in range(4):
        a=Image.open(root/f"v25_{motion}_{i:02d}_off.png").convert("RGB")
        b=Image.open(root/f"v25_{motion}_{i:02d}_on.png").convert("RGB")
        assert a.size==b.size and a.width>=720 and a.height>=400
        aa=np.asarray(a,dtype=np.int16)
        bb=np.asarray(b,dtype=np.int16)
        # Large enough to reject slight render jitter or compression noise.
        delta=np.max(np.abs(aa-bb),axis=2)
        visible=int(np.count_nonzero(delta>20))
        ratio=float(visible/delta.size)
        pairs_changed+=int(visible>0)
        pairs_significant+=int(visible>600)
        t=report["samples"][i if motion=="walk" else i+4]["t_seconds"]
        per_motion.append({"phase":i,"t":t,"changed_pixels_gt20":visible,
                           "fraction_changed":round(ratio,5)})
        before=a.resize((640,360),Image.Resampling.LANCZOS)
        after=b.resize((640,360),Image.Resampling.LANCZOS)
        y=i*390
        sheet.paste(before,(0,y))
        sheet.paste(after,(640,y))
        drawer.text((10,y+364),f"{motion.upper()} {i+1}: BEFORE IK / t={t:.3f}s",fill="white")
        drawer.text((650,y+364),f"AFTER native IK / changed={visible} pixels",fill="white")
    sheet.save(root/f"v25_{motion}_real_render_pairs.jpg",quality=88)
    measurements[motion]=per_motion
report["render_pixel_comparison"]={
    "difference_threshold_channel_value":20,
    "changed_pairs":pairs_changed,
    "significant_pairs":pairs_significant,
    "samples":measurements,
    "method":"Godot viewport raw off/on RGB pixel delta >20; same camera/phase",
    "not_proven":"pixel change may be in limbs or elsewhere; subjective leg and skin art requires actual image review"
}
(root/"v25_ik_render_comparison.json").write_text(
    json.dumps(report["render_pixel_comparison"],indent=2)+"\n",encoding="utf8")
assert pairs_significant>=2, (
    f"TwoBoneIK3D affected the modifier signal but no observable skinned render difference: {measurements}")
print("V25 SKINNED RENDER PAIRS PASS:",pairs_significant,"of 8 pairs had >600 visible changed pixels")
print("V25 ALL PAIRS:",json.dumps(measurements))
