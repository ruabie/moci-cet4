#!/usr/bin/env python3
"""Audit 4 authentic same-camera V32/V33 Godot screenshot pairs.

Numerical evidence is limited to material visibility/exposure and changed
pixels. It does NOT substitute for human architectural/aesthetic acceptance.
"""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]/"tests"
e=json.loads((ROOT/"v33_actual_environment_metrics.json").read_text(encoding="utf8"))
assert e["ok"] and e["version"]=="V0.33" and len(e["same_camera_qa_pairs"])==4
sheet=Image.new("RGB",(1480,4*470),(30,31,34))
pen=ImageDraw.Draw(sheet)
results=[]
for i,pair in enumerate(e["same_camera_qa_pairs"]):
    a=Image.open(ROOT/pair["before"]).convert("RGB")
    b=Image.open(ROOT/pair["after"]).convert("RGB")
    assert a.size==b.size and a.width>=720
    down_a=a.resize((320,180),Image.Resampling.BILINEAR)
    down_b=b.resize((320,180),Image.Resampling.BILINEAR)
    # Focus on the ground/lots; a sky-only exposure change cannot
    # satisfy this gate without changes in the actual street scene.
    ap=list(down_a.crop((0,65,320,180)).getdata())
    bp=list(down_b.crop((0,65,320,180)).getdata())
    n=len(ap)
    changed=sum(1 for x,y in zip(ap,bp) if max(abs(xx-yy) for xx,yy in zip(x,y))>18)
    bright_a=sum(1 for x in ap if sum(x)/3>222)/n
    bright_b=sum(1 for x in bp if sum(x)/3>222)/n
    if changed<1700:
        raise AssertionError(f"{pair['camera']} actual visible street-level changes too small: {changed}")
    if bright_b>=bright_a-.015:
        raise AssertionError(f"{pair['camera']} overbright ground/lot area not materially improved: {bright_a:.3f} -> {bright_b:.3f}")
    result={"name":pair["camera"],"bottom_scene_changed_pixels":changed,
        "bottom_scene_bright_ratio_before":round(bright_a,4),
        "bottom_scene_bright_ratio_after":round(bright_b,4)}
    results.append(result)
    y=i*470
    sheet.paste(a.resize((740,416),Image.Resampling.LANCZOS),(0,y))
    sheet.paste(b.resize((740,416),Image.Resampling.LANCZOS),(740,y))
    pen.text((10,y+424),f"V32 baseline • {pair['camera']}",fill="white")
    pen.text((750,y+424),f"V33 same camera • changed={changed} • bright {bright_a:.2%} to {bright_b:.2%}",fill="white")
sheet_file=ROOT/"v33_8_frame_AB_streetscape_review.jpg"
sheet.save(sheet_file,quality=90)
assert sheet_file.stat().st_size>80000
report={"real_godot_pairs":results,"all_pairs_changed":True,
    "all_scene_overbrightness_reduced":True,
    "metrics_origin":"real Godot OpenGL3 render, not synthesized images",
    "scope":"Technical image+lighting delta only; not aesthetic/user acceptance or live GPU performance",
    "human_art_approved":False}
(ROOT/"v33_ab_pixel_gate.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
print("V33 SAME-CAMERA TRUE RENDER PIXEL GATE PASS:",json.dumps(results))
