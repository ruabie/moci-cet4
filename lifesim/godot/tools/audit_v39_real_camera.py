#!/usr/bin/env python3
"""Read measured real CityPlayer camera geometry + unmodified Godot PNGs.

A positive sphere-sweep response is only this artificial rear-shop-wall
orientation. It is NOT universal camera certification, mouse hardware QA,
professional art approval, browser, or GPU performance.
"""
from pathlib import Path
import json
from PIL import Image, ImageChops

root=Path(__file__).resolve().parents[1]/"tests"
data=json.loads((root/"v39_real_camera_occlusion_metrics.json").read_text(encoding="utf-8"))
assert data["version"]=="V0.39" and data["ok"] is True
assert data["real_original_cityplayer"] is True
assert data["actual_game_scene"] is True
assert data["player_teleport_after_qa_spawn"] is False
assert data["camera_orientations_test_setup_only"] is True
assert data["shop_collision_unmodified"] is True
assert data["real_W_forward_ticks"]>80
assert data["rear_obstacle_name"] in ("Solid_rear_retail_wall","Solid_west_ground_solid")
assert data["forced_occlusion_count"]>=4
assert data["peak_camera_shape_overlaps"]==0
assert 0.35<data["wall_distance_m"]<3.5
snap={x["stage"]:x for x in data["stages"]}
blocked=snap["inside_camera_behind_rear_wall"]
open_view=snap["inside_camera_recovered"]
assert blocked["camera_distance_actual_m"]<data["wall_distance_m"]-.04
assert open_view["camera_distance_actual_m"]>data["wall_distance_m"]+1.2
assert blocked["camera_overlap_objects"]==0 and open_view["camera_overlap_objects"]==0
assert data["real_human_mouse_verified"] is False
assert data["windows_or_browser_performance_verified"] is False
assert data["font_or_art_gate_approved"] is False
names=("street","inside_open","inside_occluded","inside_recovered","street_exit")
assert data["screenshots"]==[f"v39_{name}.png" for name in names]
images=[]
for name in names:
    f=root/f"v39_{name}.png"
    assert f.exists() and f.stat().st_size>7000
    with Image.open(f) as img:
        assert img.width>=720 and img.height>=400
        images.append(img.convert("RGB"))
a=images[1]
b=images[2]
assert a.size==b.size
changed=sum(1 for c in ImageChops.difference(a,b).getdata() if max(c)>25)
fraction=changed/(a.width*a.height)
assert fraction>.05, f"real camera view did not change behind wall {fraction:.3f}"
sheet=Image.new("RGB",(1280,720*3),(26,33,39))
for i,(l,r) in enumerate(((0,1),(2,3),(4,4))):
    for j,index in enumerate((l,r)):
        thumb=images[index].copy()
        thumb.thumbnail((640,720))
        sheet.paste(thumb,(640*j,720*i))
sheet.save(root/"v39_real_camera_wall_ab.jpg",quality=88)
report={
    "real_source_frames":len(images),"original_cityplayer_camera":True,
    "occluding_wall":data["rear_obstacle_name"],
    "obstacle_distance_m":data["wall_distance_m"],
    "actual_camera_retracted_distance_m":blocked["camera_distance_actual_m"],
    "actual_camera_recovered_distance_m":open_view["camera_distance_actual_m"],
    "collision_activations":data["forced_occlusion_count"],
    "camera_overlap_max":data["peak_camera_shape_overlaps"],
    "real_diff_fraction":round(fraction,6),
    "source_font_cjk_not_approved":True,
    "human_art_signoff":False,"window_gl_hardware_verified":False
}
(root/"v39_real_camera_audit.json").write_text(
    json.dumps(report,indent=2)+"\n",encoding="utf-8")
print("V39 REAL CITYPLAYER CAMERA SPHERE-SWEEP AUDIT PASS:",json.dumps(report))
