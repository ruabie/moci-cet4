#!/usr/bin/env python3
"""Prove, from exact pinned Quaternius GLB bytes, whether Godot may omit
specific animation tracks without losing any motion. Do NOT assume all
missing tracks are constant. A nonconstant missing joint remains a hard fail.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/"art/animations/v21/ual1_inplace.glb"
DEST=ROOT/"tests/v27_source_constant_rest.json"
SOURCE_GIT_BLOB="473e59080288428d0b6da826ba19324d07b191f0"
CLIPS=("Idle_Loop","Walk_Loop","Jog_Fwd_Loop")
MOVING=("pelvis","spine_02","spine_03","clavicle_l","clavicle_r",
        "upperarm_l","upperarm_r","thigh_l","thigh_r","calf_l","calf_r")
REQUIRED_REST="spine_01"

def unit(q):
    norm=math.sqrt(sum(x*x for x in q))
    return tuple(x/norm for x in q)
def distance_degrees(q1,q2):
    a,b=unit(q1),unit(q2)
    dot=min(1.0,abs(sum(x*y for x,y in zip(a,b))))
    return 2*math.degrees(math.acos(dot))

def main():
    data=SRC.read_bytes()
    sha=hashlib.sha1(b"blob "+str(len(data)).encode("ascii")+b"\0"+data).hexdigest()
    if sha!=SOURCE_GIT_BLOB:raise ValueError("source changed or unpinned")
    if data[:4]!=b"glTF":raise ValueError("not a real GLB")
    length,kind=struct.unpack_from("<II",data,12)
    if kind!=0x4E4F534A:raise ValueError("invalid GLB json")
    obj=json.loads(data[20:20+length].decode("utf8").rstrip("\0 \n\r\t"))
    binary_start=20+length
    binlen,bintype=struct.unpack_from("<II",data,binary_start)
    if bintype!=0x004E4942:raise ValueError("expected binary GLB")
    binary=data[binary_start+8:binary_start+8+binlen]
    nodes=obj["nodes"]; names={n.get("name"):i for i,n in enumerate(nodes)}
    output={"source_git_blob":sha, "method":"full pinned GLB quaternion keys, not Godot-imported optimized tracks",
            "rest_unchanged_degrees_threshold":0.01,
            "constant_rotation_bones_by_clip":{}, "critical_dynamic_amplitude_degrees":{},
            "root_cause":"Original spine_01 has identical source rest rotation at every frame of all 3 clips; Godot may omit redundant track; target rest must remain."}
    for clip in CLIPS:
        anim=next((a for a in obj["animations"] if a.get("name")==clip),None)
        if anim is None: raise ValueError("missing expected source clip "+clip)
        source_tracks={}
        for ch in anim["channels"]:
            if ch["target"]["path"]!="rotation":continue
            node_id=ch["target"]["node"]
            node=nodes[node_id]
            sam=anim["samplers"][ch["sampler"]]
            ac=obj["accessors"][sam["output"]]
            bv=obj["bufferViews"][ac["bufferView"]]
            if ac["componentType"]!=5126 or ac["type"]!="VEC4":
                raise ValueError("unexpected compressed quaternion in "+clip)
            start=bv.get("byteOffset",0)+ac.get("byteOffset",0)
            stride=bv.get("byteStride",16)
            count=ac["count"]
            if count<2: raise ValueError("not real sampled clip: "+clip)
            keys=[struct.unpack_from("<ffff",binary,start+i*stride) for i in range(count)]
            rest=node.get("rotation",[0.0,0.0,0.0,1.0])
            extent=max(distance_degrees(keys[0],q) for q in keys)
            rest_error=max(distance_degrees(rest,q) for q in keys)
            source_tracks[node.get("name","")]={
                "key_count":count,
                "max_rotation_range_degrees":round(extent,6),
                "max_rest_delta_degrees":round(rest_error,6)}
        stable=sorted(k for k,x in source_tracks.items() if x["max_rest_delta_degrees"]<=0.01)
        output["constant_rotation_bones_by_clip"][clip]=stable
        if REQUIRED_REST not in stable: raise ValueError("spine_01 is NOT constant rest: "+clip)
        output["critical_dynamic_amplitude_degrees"][clip]={
            k:source_tracks[k]["max_rotation_range_degrees"] for k in MOVING}
        if clip in ("Walk_Loop","Jog_Fwd_Loop"):
            for side in ("upperarm_l","upperarm_r","thigh_l","thigh_r","calf_l","calf_r"):
                if source_tracks[side]["max_rotation_range_degrees"]<1.0:
                    raise ValueError("dynamic limb unexpectedly constant: "+clip+"/"+side)
    DEST.write_text(json.dumps(output,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print("V27 REAL GLB CONSTANT REST PASS:",
        json.dumps({k:{"rest_omission":REQUIRED_REST in output["constant_rotation_bones_by_clip"][k],
                       "static_bones":len(output["constant_rotation_bones_by_clip"][k]),
                       "upperarm_l_swing_deg":output["critical_dynamic_amplitude_degrees"][k]["upperarm_l"]}
                    for k in CLIPS}))
if __name__=="__main__":main()
