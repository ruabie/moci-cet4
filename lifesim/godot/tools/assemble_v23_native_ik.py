#!/usr/bin/env python3
"""V0.23: visual-only timeline contact sheets and GIFs, not real-time FPS."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]/"tests"
metrics=json.loads((root/"v23_native_ik_metrics.json").read_text(encoding="utf-8"))
for name in ("walk","run"):
    frames=[]
    times=[]
    for row in metrics["clips"][name]["samples"]:
        i=row["frame"]
        im=Image.open(root/f"v23_{name}_ik_{i:02d}.png").convert("RGB")
        assert im.width>=720 and im.height>=400
        frames.append(im.resize((640,360),Image.Resampling.LANCZOS))
        times.append(row["clip_second"])
    assert len(frames)==8
    duration=max(70,min(350,round(metrics["clips"][name]["clip_duration_seconds"]*1000/8)))
    pal=[f.quantize(colors=96,method=Image.Quantize.MEDIANCUT) for f in frames]
    pal[0].save(root/f"v23_{name}_ik.gif",save_all=True,append_images=pal[1:],
                duration=duration,loop=0,optimize=False,disposal=2)
    sheet=Image.new("RGB",(640*4,386*2),(31,31,33))
    draw=ImageDraw.Draw(sheet)
    for i,f in enumerate(frames):
        x,y=(i%4)*640,(i//4)*386
        sheet.paste(f,(x,y))
        draw.text((x+8,y+361),f"Actual clip {name} | t={times[i]:.3f}s",fill=(230,230,230))
    sheet.save(root/f"v23_{name}_ik_sheet.jpg",quality=86)
    assert (root/f"v23_{name}_ik.gif").stat().st_size>60_000
    assert (root/f"v23_{name}_ik_sheet.jpg").stat().st_size>40_000
print("V23 NATIVE IK MEDIA PASS: 16 real Godot timeline frames, NOT gameplay footage")
