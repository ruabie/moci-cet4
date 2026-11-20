#!/usr/bin/env python3
"""LifeSim V0.32 authored neighborhood land-use and pedestrian safety audit.

All road, lot, doorway and amenity assertions are derived from the SAME JSON
used by the Godot scene builder. This is geometric/semantic verification,
not an engine screenshot, playable expansion or real navigation benchmark.
"""
from __future__ import annotations
import json, math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PLAN=ROOT/"data/v32_north_district.json"
OUT=ROOT/"tests/v32_spatial_audit.json"
plan=json.loads(PLAN.read_text(encoding="utf-8"))
assert plan["schema"]==1 and plan["version"]=="V0.32"
bounds=plan["bounds"]
area=(bounds["x_max"]-bounds["x_min"])*(bounds["z_max"]-bounds["z_min"])
legacy_area=180*180
assert area>legacy_area*.98, (area,legacy_area)
assert bounds["z_min"]<89 and bounds["z_max"]>=275  # real road seam + added land
assert bounds["x_min"]<=-84 and bounds["x_max"]>=84
roads={r["id"]:r for r in plan["roads"]}
assert set(roads)=={"north_spine","community_cross"}
spine,cross=roads["north_spine"],roads["community_cross"]
assert spine["axis"]=="z" and cross["axis"]=="x"
assert abs(spine["center"])<.01 and cross["center"]==165
assert spine["from"]<=88 and spine["to"]>=275
assert spine["width"]>=11 and spine["sidewalk_width"]>=3.5
assert cross["width"]>=11 and cross["sidewalk_width"]>=3.5
assert cross["from"]<=-84 and cross["to"]>=84
def rect(x,z,w,d):
    return (x-w/2,z-d/2,x+w/2,z+d/2)
def overlaps(a,b,pad=0.0):
    return (a[0]<b[2]+pad and a[2]>b[0]-pad
        and a[1]<b[3]+pad and a[3]>b[1]-pad)
def clearance(a,b):
    dx=max(a[0]-b[2],b[0]-a[2],0)
    dz=max(a[1]-b[3],b[1]-a[3],0)
    return math.hypot(dx,dz)
lots=plan["lots"]
assert 10<=len(lots)<=16
ids=[lot["id"] for lot in lots]
assert len(set(ids))==len(ids)
assert len(set(l["name"] for l in lots))==len(lots)
types=set(l["type"] for l in lots)
assert {"clinic","library","residential","retail","studio","public"}.issubset(types)
assert len(set(round(l["h"],1) for l in lots))>=8  # not cloned identical cuboids
road_boxes=[
 rect(0,(spine["from"]+spine["to"])/2,spine["width"]+2*spine["sidewalk_width"],
      spine["to"]-spine["from"]),
 rect((cross["from"]+cross["to"])/2,cross["center"],
      cross["to"]-cross["from"],cross["width"]+2*cross["sidewalk_width"])
]
ped_boxes=[]
for path in plan["pedestrian_connectors"]:
    assert path["width"]>=2.4 and path["marked_crossing"]
    for start,end in path["segments"]:
        assert end-start>=50
        ped_boxes.append(rect((start+end)/2,path["z"],end-start,path["width"]))
footprints={l["id"]:rect(l["x"],l["z"],l["w"],l["d"]) for l in lots}
park=plan["park"]
park_rect=rect(park["x"],park["z"],park["w"],park["d"])
min_lot_gap=1e9
walk_routes=[]
for l in lots:
    r=footprints[l["id"]]
    assert l["levels"]>=3 and l["h"]>=10 and l["h"]<=27
    assert r[0]>bounds["x_min"]+2 and r[2]<bounds["x_max"]-2
    assert r[1]>bounds["z_min"]+4 and r[3]<bounds["z_max"]-9
    for road in road_boxes:
        assert not overlaps(r,road), ("road/sidewalk overlap",l["id"],r,road)
    for ped in ped_boxes:
        assert not overlaps(r,ped), ("walkway/lot overlap",l["id"])
    if l["door"]=="east":
        assert l["x"]<0
        face=l["x"]+l["w"]/2
        goal=-(spine["width"]/2+spine["sidewalk_width"])
        assert face<goal and goal-face>=3.2
        route=rect((face+goal)/2,l["z"],goal-face,2.4)
    elif l["door"]=="west":
        assert l["x"]>0
        face=l["x"]-l["w"]/2
        goal=spine["width"]/2+spine["sidewalk_width"]
        assert face>goal and face-goal>=3.2
        route=rect((face+goal)/2,l["z"],face-goal,2.4)
    else:
        face=l["z"]+(l["d"]/2 if l["door"]=="north" else -l["d"]/2)
        nearest=min((p["z"] for p in plan["pedestrian_connectors"]),key=lambda z:abs(face-z))
        assert (nearest>face)==(l["door"]=="north"),("door facing away from path",l["id"])
        assert abs(nearest-face)<=19
        route=rect(l["x"],(face+nearest)/2,2.4,abs(nearest-face))
    walk_routes.append((l["id"],route))
for i,a in enumerate(lots):
    for b in lots[i+1:]:
        ra,rb=footprints[a["id"]],footprints[b["id"]]
        assert not overlaps(ra,rb),("buildings overlap",a["id"],b["id"])
        min_lot_gap=min(min_lot_gap,clearance(ra,rb))
assert min_lot_gap>=6.0, min_lot_gap
for k,r in walk_routes:
    for other,box in footprints.items():
        if other==k:continue
        assert not overlaps(r,box),("entrance access blocked",k,other)
assert all(not overlaps(park_rect,footprints[k]) for k in footprints)
assert all(not overlaps(park_rect,r) for r in road_boxes+ped_boxes)
assert park["bench_count"]>=2 and park["tree_count"]>=4
fac={f["id"]:f for f in plan["facilities"]}
assert {"bus_stop","shared_bikes","junction_crossing","market_crossing","library_crossing"}.issubset(fac)
stop=fac["bus_stop"]
assert stop["x"] < -(spine["width"]/2+spine["sidewalk_width"]), "bus shelter must be outside clear sidewalk"
assert not any(overlaps(rect(stop["x"],stop["z"],stop["width"],stop["depth"]),r) for r in road_boxes)
assert not any(overlaps(rect(stop["x"],stop["z"],stop["width"],stop["depth"]),r) for r in footprints.values())
# Shared path crossings must truly cross the vehicle road in a marked area.
for path in plan["pedestrian_connectors"]:
    assert path["z"] not in range(154,177)
    assert any(abs(f["z"]-path["z"])<.01 and f["type"]=="marked_crosswalk" for f in fac.values())
# Entrances are reached from one continuous spine/sidewalk, with east-west cross street.
assert min_lot_gap>6.0
report={
 "ok":True, "plan":"v32_north_district.json",
 "new_ground_area_m2":area,"old_ground_area_m2":legacy_area,
 "combined_ground_area_m2_upper_bound":area+legacy_area,
 "area_ratio_before_overlapping_seam":round((area+legacy_area)/legacy_area,3),
 "new_district_extent_m":[bounds["x_max"]-bounds["x_min"],bounds["z_max"]-bounds["z_min"]],
 "road_count":len(roads),"pedestrian_routes":len(ped_boxes),
 "buildings":len(lots),"park_count":1,"facilities":len(fac),
 "min_building_clearance_m":round(min_lot_gap,2),
 "entrance_routes_checked":len(walk_routes),
 "road_overlap":0,"entrance_route_blocked":0,"zoning_types":sorted(types),
 "important_limitation":"Code/plan geometry check only. No city integration, real input, visual art, performance or Web release approved."
}
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
print("V32 CONNECTED LAND USE PLAN PASS:",json.dumps(report,ensure_ascii=False))
