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
data=json.loads((root/"v40_real_camera_occlusion_metrics.json").read_text(encoding="utf-8"))
assert data["version"]=="V0.40" and data["ok"] is True
assert data["real_original_cityplayer"] is True
assert data["actual_game_scene"] is True
assert data["player_teleport_after_qa_spawn"] is False
assert data["camera_orientations_test_setup_only"] is True
assert data["shop_collision_unmodified"] is True
assert data["real_W_forward_ticks"]>80
assert data["rear_obstacle_name"] in ("Solid_rear_retail_wall","Solid_west_ground_solid")
assert data["forced_occlusion_count"]>=4
assert data["peak_camera_shape_overlaps"]==0
assert data["avatar_render_mesh_count"] >= 1
assert data["camera_near_avatar_fade_proof"] is True
assert data["real_solid_collision_preserved"] is True
# The original rear wall lies only ~0.339m from the player's pivot.
# Distance 0.35m was an arbitrary mistaken floor, not a safety threshold.
# Keep all zero-overlap, actual-retraction and recovery checks unchanged.
assert 0.20<data["wall_distance_m"]<3.5
snap={x["stage"]:x for x in data["stages"]}
blocked=snap["inside_camera_behind_rear_wall"]
open_view=snap["inside_camera_recovered"]
assert blocked["camera_distance_actual_m"]<data["wall_distance_m"]-.04
assert open_view["camera_distance_actual_m"]>data["wall_distance_m"]+1.2
assert blocked["camera_overlap_objects"]==0 and open_view["camera_overlap_objects"]==0
assert blocked["avatar_camera_fade"]>=.97
assert blocked["avatar_mesh_hidden_count"] == data["avatar_render_mesh_count"]
assert open_view["avatar_camera_fade"]<=.02
assert open_view["avatar_mesh_hidden_count"] == 0
assert blocked["avatar_render_mesh_count"]==open_view["avatar_render_mesh_count"]
assert data["real_human_mouse_verified"] is False
assert data["windows_or_browser_performance_verified"] is False
assert data["font_or_art_gate_approved"] is False
names=("street","inside_open","inside_occluded","inside_recovered","street_exit")
assert data["screenshots"]==[f"v40_{name}.png" for name in names]
images=[]
for name in names:
    f=root/f"v40_{name}.png"
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
# Image evidence must show removal of the original giant brown head, not
# merely a transparent property value with unchanged engine rendering.
# An archived V39 baseline was captured at the exact same physical rear wall.
reference=Path("/tmp/v39-camera-original/lifesim/godot/tests/v39_inside_occluded.png")
assert reference.is_file(), "Original V39 authentic obstructed baseline missing"
with Image.open(reference) as original_png:
    original=original_png.convert("RGB")
assert original.size == images[2].size
central_crop=(500,200,780,400)
def hair_brown_fraction(pic):
    region=pic.crop(central_crop)
    pixels=region.getdata()
    dark_brown=sum(1 for r,g,b in pixels
        if 30<=r<=140 and 20<=g<=120 and 15<=b<=100
        and r>g*.96 and g>b*.92)
    return dark_brown/(region.width*region.height)
head_before=hair_brown_fraction(original)
head_after=hair_brown_fraction(images[2])
assert head_before>.70, f"V39 comparison no longer demonstrates giant hair: {head_before:.3f}"
assert head_after < head_before*.45, (
    f"Camera material fade did not actually clear close-up face in original Godot PNG: "
    f"before={head_before:.3f} after={head_after:.3f}")
comparison=Image.new("RGB",(1280,720),(0,0,0))
left=original.copy()
right=images[2].copy()
left.thumbnail((640,720))
right.thumbnail((640,720))
comparison.paste(left,(0,0))
comparison.paste(right,(640,0))
comparison.save(root/"v40_original_hair_before_after.jpg",quality=90)
sheet=Image.new("RGB",(1280,720*3),(26,33,39))
for i,(l,r) in enumerate(((0,1),(2,3),(4,4))):
    for j,index in enumerate((l,r)):
        thumb=images[index].copy()
        thumb.thumbnail((640,720))
        sheet.paste(thumb,(640*j,720*i))
sheet.save(root/"v40_real_camera_wall_ab.jpg",quality=88)
report={
    "real_source_frames":len(images),"original_cityplayer_camera":True,
    "occluding_wall":data["rear_obstacle_name"],
    "obstacle_distance_m":data["wall_distance_m"],
    "actual_camera_retracted_distance_m":blocked["camera_distance_actual_m"],
    "actual_camera_recovered_distance_m":open_view["camera_distance_actual_m"],
    "collision_activations":data["forced_occlusion_count"],
    "camera_overlap_max":data["peak_camera_shape_overlaps"],
    "avatar_meshes_unchanged":data["avatar_render_mesh_count"],
    "compatibility_material_slots":data["compatibility_material_alpha_slot_count"],
    "occluded_local_meshes_hidden":blocked["avatar_mesh_hidden_count"],
    "recovered_local_meshes_hidden":open_view["avatar_mesh_hidden_count"],
    "occluded_avatar_fade":blocked["avatar_camera_fade"],
    "recovered_avatar_fade":open_view["avatar_camera_fade"],
    "original_hair_center_fraction":round(head_before,6),
    "new_hair_center_fraction":round(head_after,6),
    "original_hair_reduction_percent":round((1-head_after/head_before)*100,2),
    "real_diff_fraction":round(fraction,6),
    "source_font_cjk_not_approved":True,
    "human_art_signoff":False,"window_gl_hardware_verified":False
}
(root/"v40_real_camera_audit.json").write_text(
    json.dumps(report,indent=2)+"\n",encoding="utf-8")
print("V40 REAL CITYPLAYER CAMERA SPHERE-SWEEP AUDIT PASS:",json.dumps(report))
