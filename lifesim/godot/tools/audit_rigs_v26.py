#!/usr/bin/env python3
"""Binary GLB audit: source UAL vs compatible base vs old legacy civilian.

Uses stdlib only, on actual pinned build assets. This is not a rendered
animation or a natural-motion quality assessment.
"""
from __future__ import annotations
from collections import Counter
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"art/animations/v21/ual1_inplace.glb"
CANDIDATE=ROOT/"art/characters/v26/base_character_compatible.glb"
LEGACY=ROOT/"art/characters/v18/player_casual.glb"
OUTPUT=ROOT/"tests/v26_rig_audit.json"
KEY=("root","pelvis","spine_01","spine_03","clavicle_l","upperarm_l",
     "lowerarm_l","thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r")

def load(path: Path) -> tuple[dict,bytes]:
    b=path.read_bytes()
    if b[:4]!=b"glTF": raise ValueError("not glb: "+str(path))
    jn,typ=struct.unpack_from("<II",b,12)
    if typ!=0x4E4F534A: raise ValueError("missing JSON GLB chunk")
    obj=json.loads(b[20:20+jn].decode("utf-8").rstrip("\0\r\n\t "))
    # For these exact pinned source versions, glb JSON chunk is followed by
    # standard single BIN chunk. Fail if format changes.
    offset=20+jn
    ln,kind=struct.unpack_from("<II",b,offset)
    if kind!=0x004E4942: raise ValueError("missing BIN GLB chunk")
    return obj,b[offset+8:offset+8+ln]

def joints(obj: dict) -> dict[str,int]:
    nodes=obj["nodes"]
    return {str(nodes[i].get("name","")):i for skin in obj["skins"]
            for i in skin["joints"]}

def parents(obj: dict) -> dict[int,int]:
    return {child:i for i,n in enumerate(obj["nodes"]) for child in n.get("children",[])}

def parent_name(obj:dict, index:int, ps:dict[int,int]) -> str:
    if index not in ps: return "NO_PARENT"
    return str(obj["nodes"][ps[index]].get("name","UNNAMED"))

def angular_deg(a:dict,b:dict) -> float:
    qa=a.get("rotation",[0,0,0,1])
    qb=b.get("rotation",[0,0,0,1])
    dot=sum(float(x)*float(y) for x,y in zip(qa,qb))
    la=math.sqrt(sum(float(x)**2 for x in qa))
    lb=math.sqrt(sum(float(x)**2 for x in qb))
    dot=max(-1.0,min(1.0,abs(dot/(la*lb))))
    return math.degrees(2*math.acos(dot))

def accessor_range(obj: dict, buffer: bytes, accessor_id:int) -> list[float]:
    ac=obj["accessors"][accessor_id]
    if ac["componentType"]!=5126 or ac["type"]!="VEC3":
        raise ValueError("unexpected vertex/animation accessor; exact file changed")
    bv=obj["bufferViews"][ac["bufferView"]]
    stride=bv.get("byteStride",12)
    start=bv.get("byteOffset",0)+ac.get("byteOffset",0)
    vals=[struct.unpack_from("<fff",buffer,start+i*stride) for i in range(ac["count"])]
    return [round(max(row[j] for row in vals)-min(row[j] for row in vals),5) for j in range(3)]

def translation(obj:dict, blob:bytes, clip:str, node:str) -> dict:
    target=next((i for i,n in enumerate(obj["nodes"]) if n.get("name")==node),None)
    anim=next((a for a in obj["animations"] if a.get("name")==clip),None)
    if target is None or anim is None: raise ValueError("missing "+clip+"/"+node)
    tr=next((ch for ch in anim["channels"] if ch["target"]["node"]==target
             and ch["target"]["path"]=="translation"),None)
    if tr is None: raise ValueError("real animated translation track missing")
    acc=anim["samplers"][tr["sampler"]]["output"]
    return {"channel":"translation","sample_count":obj["accessors"][acc]["count"],
            "local_xyz_motion_range_m":accessor_range(obj,blob,acc)}

def main():
    src,srcbin=load(SOURCE)
    base,_=load(CANDIDATE)
    old,_=load(LEGACY)
    sj,bj,oj=joints(src),joints(base),joints(old)
    ps,pb=parents(src),parents(base)
    shared=set(sj)&set(bj)
    hierarchy_matches=[n for n in shared if parent_name(src,sj[n],ps)==parent_name(base,bj[n],pb)]
    hierarchy_mismatch=sorted(shared-set(hierarchy_matches))
    angles={n:round(angular_deg(src["nodes"][sj[n]],base["nodes"][bj[n]]),2)
            for n in sorted(shared)}
    ranked=sorted(angles.values())
    median=round(ranked[len(ranked)//2],2)
    anim=src.get("animations",[])
    clips={}
    for name in ("Idle_Loop","Walk_Loop","Jog_Fwd_Loop"):
        a=next(x for x in anim if x["name"]==name)
        clips[name]={"channels":dict(Counter(c["target"]["path"] for c in a["channels"])),
                     "pelvis_translation":translation(src,srcbin,name,"pelvis")}
    report={
        "source":{"name":"Quaternius UAL1 Standard CC0 in-place mannequin",
                  "skinned_joints":len(sj),"mesh_count":len(src.get("meshes",[])),
                  "animation_clips":len(anim)},
        "candidate":{"name":"Quaternius Universal Base Character BaseCharacter.glb CC0",
                     "skinned_joints":len(bj),"mesh_count":len(base.get("meshes",[])),
                     "source_joint_names_shared":len(shared),
                     "matching_parent_names":len(hierarchy_matches),
                     "hierarchy_mismatch":hierarchy_mismatch,
                     "median_local_rest_rotation_diff_degrees":median,
                     "key_bone_rest_rotation_diff_degrees":{n:angles.get(n) for n in KEY},
                     "same_name_source_coverage":round(len(shared)/len(sj),3)},
        "old_avatar":{"name":"Quaternius V0.18 modular civilian (artistically rejected)",
                      "skinned_joints":len(oj),"meshes":len(old.get("meshes",[])),
                      "exact_source_names_shared":len(set(sj)&set(oj)),
                      "different_humanoid_names_and_hierarchy":True},
        "source_animation_clips":clips,
        "v21_v25_retarg_gap":"legacy animation_retarget_v22.gd copies only TYPE_ROTATION_3D; it drops pelvis translation, scale and other TRS channels, including substantial Jog pelvis movement",
        "scope":"Actual exact-pinned binary assets and GLB hierarchy, NOT a claim about visual quality",
        "artist_review_needed":"Source and Universal Base rig match alone not sufficient; must compare full-body native/rest-calibrated rendered animation and civilian aesthetic."
    }
    good=(len(sj)>=60 and len(bj)>=60 and len(shared)>=60
          and len(hierarchy_matches)>=59 and len(old.get("animations",[]))==0
          and len(anim)>=40 and len(set(sj)&set(oj))<10
          and median<=35
          and clips["Jog_Fwd_Loop"]["pelvis_translation"]["local_xyz_motion_range_m"][2]>=0.1)
    OUTPUT.write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    if not good:
        raise ValueError("V26 actual CC0 rigs failed compatibility / pelvis motion evidence gates: "
                         +json.dumps(report,ensure_ascii=False)[:3000])
    print("V26 REAL RIG AUDIT PASS:",json.dumps({
        "source_bones":len(sj),"candidate_bones":len(bj),
        "matching_names":len(shared),"matching_parents":len(hierarchy_matches),
        "median_rest_angle_deg":median,"old_exact_names":len(set(sj)&set(oj)),
        "jog_pelvis_z_range_m":clips["Jog_Fwd_Loop"]["pelvis_translation"]["local_xyz_motion_range_m"][2]
    }))

if __name__=="__main__":
    main()
