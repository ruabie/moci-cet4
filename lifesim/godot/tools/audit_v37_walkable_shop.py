#!/usr/bin/env python3
"""Only measured Godot screenshots and actual physics test metrics count.

Art appearance is NOT accepted by this threshold; also unlike raycasts,
full production CityPlayer interaction and commerce are NOT claimed.
"""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "tests"
raw = ROOT / "v37_walkable_shop_metrics.json"
assert raw.is_file(), "Godot did not save its original physics measurements"
r = json.loads(raw.read_text(encoding="utf-8"))
assert r["version"] == "V0.37" and r["ok"]
assert r["v36_before_door_blocked"]
assert r["door_clear_path"] and r["side_wall_collision"] and r["back_wall_collision"]
assert r["public_ground_probes"] == 3
assert r["original_planned_lots"] == 11
assert r["shop_stats"]["verified_glb_instances"] == 17
assert r["shop_stats"]["poi_registered"] is False
assert r["shop_stats"]["economy_integrated"] is False
assert r["production_city_player_input_verified"] is False
walk = r["character_body_physics"]
assert walk["collision_events"] == 0 and walk["distance_metres"] > 8.85
assert walk["end"][0] < -22.7
assert len(r["screenshots"]) == 5

audit = []
sheet = Image.new("RGB",(1280,720 * 2),"#27313a")
for i, tag in enumerate(("street","door")):
    a = ROOT / f"v37_before_{tag}.png"
    b = ROOT / f"v37_after_{tag}.png"
    assert a.is_file() and b.is_file(), f"missing genuine {tag} 2-phase images"
    with Image.open(a) as ia, Image.open(b) as ib:
        old, new = ia.convert("RGB"), ib.convert("RGB")
        assert old.size == new.size and old.width >= 720 and old.height >= 400
        changed = sum(1 for rgb in ImageChops.difference(old,new).getdata()
                      if max(rgb) > 25)
        proportion = changed / (old.width * old.height)
        assert proportion > (.012 if tag == "street" else .04), (
            f"real scene does not visibly change at {tag}: {proportion:.3%}")
        audit.append({"camera":tag,"before":a.name,"after":b.name,
                      "pixels_changed_over_25":changed,
                      "pixel_fraction":round(proportion,5)})
        old.thumbnail((640,720))
        new.thumbnail((640,720))
        sheet.paste(old,(0,720*i))
        sheet.paste(new,(640,720*i))
inside = ROOT / "v37_inside_shop.png"
assert inside.is_file()
with Image.open(inside) as img:
    assert img.width >= 720 and img.height >= 400
sheet.save(ROOT / "v37_real_walkable_shop_ab.jpg", quality=88)
(ROOT / "v37_actual_render_pixel_gate.json").write_text(
    json.dumps({"version":"V0.37","render_verified":True,
                "physics_proven_for_proxy_only":True,
                "human_art_signoff":False,"production_integration":False,
                "real_images":audit},indent=2)+"\n",encoding="utf-8")
print("V37 TRUE GODOT SHOP ART/PHYSICS AUDIT PASS:",
      json.dumps({"comparisons":audit,
                  "walk_distance":walk["distance_metres"],
                  "separate_original_frames":5}))
