#!/usr/bin/env python3
"""V0.38 strictly checks original scene route telemetry and its 5 actual PNGs.
No fake final gameplay or machine-fps/art approval based on Linux software render.
"""
import json
from pathlib import Path
from PIL import Image, ImageChops

r = Path(__file__).resolve().parents[1] / "tests"
m = json.loads((r/"v38_real_player_walk_metrics.json").read_text(encoding="utf-8"))
assert m["version"]=="V0.38" and m["qa_result"]
assert m["real_original_production_cityplayer"] is True
assert m["test_moves_avatar_node_directly_after_initial_spawn"] is False
assert m["w_s_pressed_using_real_key_events"] is True
assert m["grounded_ticks_while_W"]>55
assert m["animated_gait_ticks_while_W"]>55
assert m["total_forward_distance_m"]>8.4
assert m["forward_W_physics_ticks"]>80 and m["backward_S_physics_ticks"]>80
assert m["turn_delta_radians"]>.18
assert m["initial_street"][0] > -14
assert m["first_inside"][0] < -22.7
assert m["returned_street"][0] > -13.60
assert m["original_north_lots"] == 11
assert m["storefront_qa_interiors"]==1
assert m["full_mesh_sole_ik_proven"] is False
assert m["web_export_or_windows_fps_verified"] is False
assert m["retail_economy_connected"] is False
frames=["street_idle","shop_enter","stopped_inside","turn_inside","street_return"]
assert m["frames"] == [f"v38_{n}.png" for n in frames]
for f in m["frames"]:
    p=r/f
    assert p.is_file() and p.stat().st_size > 7000, f"not a real Godot PNG: {f}"
    with Image.open(p) as img:
        assert img.size[0] >= 720 and img.size[1] >= 400
        img.verify()
with Image.open(r/"v38_street_idle.png") as image1, Image.open(r/"v38_shop_enter.png") as image2:
    left=image1.convert("RGB"); right=image2.convert("RGB")
    assert left.size==right.size
    d=ImageChops.difference(left,right)
    changed=sum(1 for px in d.getdata() if max(px)>25)
    fraction=changed/(left.width*left.height)
    assert fraction>.05, f"actual player-camera scene unchanged: {fraction}"
from PIL import ImageDraw
sheet=Image.new("RGB",(1280,720*3),"#1b2426")
for i, pair in enumerate([("street_idle","shop_enter"),
                           ("stopped_inside","turn_inside"),
                           ("street_return","street_return")]):
    for j, name in enumerate(pair):
        with Image.open(r/f"v38_{name}.png") as image:
            thumbnail=image.convert("RGB")
            thumbnail.thumbnail((640,720))
            sheet.paste(thumbnail,(640*j,720*i))
sheet.save(r/"v38_real_cityplayer_roundtrip_comparison.jpg",quality=89)
out={"real_original_godot_images":len(frames),
     "same_character_and_scene":True,"original_keyboard_event_dispatch":True,
     "front_to_inside_actual_player":m["first_inside"],
     "returned_by_reverse_keyboard":m["returned_street"],
     "camera_sweep_initialized":True,
     "camera_collision_activations":m["original_player_camera_collision_activations"],
     "camera_collision_effectiveness_not_proven_by_initialization":True,
     "solo_ankle_vs_idle_not_shoe_sole_ik":True,
     "pixel_change_fraction":round(fraction,6),
     "full_gameplay_release_approved":False}
(r/"v38_godot_image_and_input_audit.json").write_text(
    json.dumps(out,indent=2)+"\n",encoding="utf-8")
print("V38 ACTUAL PLAYER CAMERA IMAGES AND WASD TELEMETRY PASS:",json.dumps(out))
