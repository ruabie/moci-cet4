#!/usr/bin/env python3
"""Assemble ACTUAL Godot imported UAL Mannequin / base character / old civilian
comparison captures. No AI-generated asset or fake animation data.
"""
from pathlib import Path
import json
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]/"tests"
p=root/"v26_visual_metrics.json"
j=json.loads(p.read_text(encoding="utf8"))
assert j.get("ok") and j["total_raw_godot_frames"]==15
samples=[(motion,s) for motion in ("idle","walk","jog")
         for s in j["source_clip_phases"][motion]]
assert len(samples)==5
tile_w,tile_h=600,338
sheet=Image.new("RGB",(tile_w*3,(tile_h+28)*5),(28,30,35))
label=ImageDraw.Draw(sheet)
for row,(motion,entry) in enumerate(samples):
    for col,role in enumerate(("native","compatible","legacy")):
        filename=entry["frames"][role]
        raw=Image.open(root/filename).convert("RGB")
        assert raw.width>=720 and raw.height>=400
        # Guard against absent GLB content or accidentally fully blank captures
        colors=raw.resize((128,72)).getcolors(128*72)
        assert colors is not None and len(colors)>150, (filename,len(colors or []))
        image=raw.resize((tile_w,tile_h),Image.Resampling.LANCZOS)
        x=col*tile_w;y=row*(tile_h+28)
        sheet.paste(image,(x,y))
        label.text((x+10,y+tile_h+5),
                   f"{motion.upper()} phase={entry['phase']:.2f} | {role} (Godot actual)",
                   fill=(238,240,244))
sheet.save(root/"v26_three_rig_same_phase_review.jpg",quality=88)
assert (root/"v26_three_rig_same_phase_review.jpg").stat().st_size>150000
print("V26 THREE RIG ARTIFACT PASS: 15 actual Godot frames, 5 phase comparison rows")
