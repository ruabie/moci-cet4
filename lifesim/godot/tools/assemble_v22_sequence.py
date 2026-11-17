#!/usr/bin/env python3
"""Review-only timeline GIFs. Do not mistake deterministic samples for real FPS."""
from pathlib import Path
import json
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]/"tests"
obj=json.loads((ROOT/"v22_sequence_metrics.json").read_text(encoding="utf-8"))
for motion in ("walk","run"):
    details=obj["motion"][motion]
    samples=details["samples"]
    assert len(samples)==18, (motion,len(samples))
    duration=max(60,min(200,round(details["clip_duration_s"]*1000/18)))
    images=[]
    for idx in range(18):
        path=ROOT/f"v22_{motion}_seq_{idx:02d}.png"
        im=Image.open(path).convert("RGB").resize((640,360),Image.Resampling.LANCZOS)
        images.append(im)
    pal=[im.quantize(colors=96,method=Image.Quantize.MEDIANCUT) for im in images]
    pal[0].save(ROOT/f"v22_{motion}_timeline.gif",save_all=True,append_images=pal[1:],
                duration=duration,loop=0,optimize=False,disposal=2)
    sheet=Image.new("RGB",(640*3,385*6),(32,32,33))
    pen=ImageDraw.Draw(sheet)
    for i,im in enumerate(images):
        x,y=(i%3)*640,(i//3)*385
        sheet.paste(im,(x,y))
        pen.text((x+9,y+361),
           f"{motion}: {samples[i]['sample_t_seconds']:.2f}s, root {samples[i]['root_height_offset_m']:+.3f}m",
           fill=(230,230,230))
    sheet.save(ROOT/f"v22_{motion}_contact_sheet.jpg",quality=85)
    assert (ROOT/f"v22_{motion}_timeline.gif").stat().st_size>70_000
    assert (ROOT/f"v22_{motion}_contact_sheet.jpg").stat().st_size>70_000
    print("V22 TIMELINE MEDIA PASS:",motion,"18 real Godot timeline frames, not realtime video",
        "root height range:",details["root_offset_range_m"])
