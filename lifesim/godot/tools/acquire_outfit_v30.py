#!/usr/bin/env python3
"""Pin Quaternius CC0 modular garments on the compatible 65-bone rig.

Test-only art candidate. Original pack is fantasy/peasant, NOT approved
modern civilian clothing. Downloaded during CI only; no runtime requests.
"""
from __future__ import annotations
import hashlib,json,struct
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request,urlopen

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"art/characters/v30"
REPORT=ROOT/"tests/v30_outfit_audit.json"
REPO="agentkaerf/FreeModels"
COMMIT="db3df04d1e4714298a09510b26fb6de6645138a2"
BASE="Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/"
ITEMS={
 "Male_Peasant_Body.gltf":("e2b2c62a0e43a1a66610b0444a39023f903db291",23738),
 "Male_Peasant_Body.bin":("f8fa3a455f720b14aa14bbbd496084bf96ae2465",219680),
 "Male_Peasant_Legs.gltf":("2152efe6f524d7de14d7fce783d1402e9b9e8d0f",23721),
 "Male_Peasant_Legs.bin":("77358725c73dc2835ded8bc7839b770572bf0d98",52816),
 "Male_Peasant_Feet.gltf":("ce5d81d52a2e3eb058bb80b7c3fa4bb6fe96f087",23740),
 "Male_Peasant_Feet.bin":("dd5f381d37518d97189b663a70a3efd92081487f",139880),
 "T_Peasant_BaseColor.png":("8f1cb9966e9c4a7c1b84188897faa54d241eb9bb",5055760),
 "T_Peasant_Normal.png":("78498b58beb3335d34ff71b630d438f19a408638",14110336),
 "T_Peasant_ORM.png":("9ce2e1abd526a736ab3a16a3b83a0922e5dcf12e",9903835),
}

def blob_sha(data:bytes)->str:
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii")+data).hexdigest()

def download_exact(name:str,expected_sha:str,size:int)->None:
    path=OUT/name
    if path.is_file():
        raw=path.read_bytes()
    else:
        url=f"https://raw.githubusercontent.com/{REPO}/{COMMIT}/{quote(BASE+name,safe='/')}"
        req=Request(url,headers={"User-Agent":"LifeSim-CC0-garment-audit"})
        with urlopen(req,timeout=90) as f:
            raw=f.read(size+1)
    if len(raw)!=size or blob_sha(raw)!=expected_sha:
        raise ValueError(f"source digest mismatch {name}: size={len(raw)}, sha={blob_sha(raw)}")
    if not path.is_file():path.write_bytes(raw)

def glb_json(path:Path)->dict:
    b=path.read_bytes()
    if b[:4]!=b"glTF":raise ValueError("invalid GLB")
    length,kind=struct.unpack_from("<II",b,12)
    if kind!=0x4e4f534a:raise ValueError("GLB JSON chunk missing")
    return json.loads(b[20:20+length].decode("utf8").rstrip("\0\n\r\t "))

def rig_info(g:dict)->dict:
    nodes=g["nodes"];ps={}
    for i,n in enumerate(nodes):
        for child in n.get("children",[]):ps[child]=i
    result={}
    for idx in g["skins"][0]["joints"]:
        name=str(nodes[idx].get("name",""))
        parent=ps.get(idx)
        result[name]=str(nodes[parent].get("name","")) if parent is not None else ""
    return result

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    REPORT.parent.mkdir(parents=True,exist_ok=True)
    for name,(sha,size) in ITEMS.items():
        download_exact(name,sha,size)
    base=glb_json(ROOT/"art/characters/v26/base_character_compatible.glb")
    br=rig_info(base)
    if len(br)!=65: raise ValueError("base CC0 65-bone identity changed")
    metrics={}
    for part in ("Body","Legs","Feet"):
        name="Male_Peasant_"+part
        gltf=json.loads((OUT/(name+".gltf")).read_text(encoding="utf8"))
        sk=rig_info(gltf)
        if sk!=br:raise ValueError(
            f"{part} rig does not exactly match 65-bone base: "+
            json.dumps({"missing":sorted(set(br)-set(sk)),"different_parents":[x for x in br if sk.get(x)!=br[x]][:20]}))
        if len(gltf.get("meshes",[]))!=1 or len(gltf.get("skins",[]))!=1:
            raise ValueError("unrecognized glTF mesh/skin in "+name)
        if not gltf.get("materials") or not gltf.get("images"):
            raise ValueError("missing actual source textures in "+name)
        actual_bin=gltf["buffers"][0]["uri"]
        if actual_bin!=name+".bin":
            raise ValueError("unexpected unpinned bin asset reference")
        for im in gltf["images"]:
            if im.get("uri") not in ITEMS:
                raise ValueError("unexpected or missing texture "+str(im))
        metrics[part]={"rig_bones":len(sk),
                       "mesh_count":len(gltf["meshes"]),
                       "material_names":[x.get("name","") for x in gltf["materials"]],
                       "indexed_skin_parent_matches":65}
    report={"pass":True,"author":"Quaternius","license":"CC0-1.0",
        "source_repository":REPO,"source_commit":COMMIT,
        "official_url":"https://quaternius.com/packs/modularcharacteroutfitsfantasy.html",
        "license_source":"Modular Character Outfits - Fantasy[Standard]/License_Standard.txt",
        "files":{k:{"git_blob_sha":v[0],"bytes":v[1]} for k,v in ITEMS.items()},
        "garments":metrics,
        "scope":"Build-time-only source asset and matching skin rig evidence; actual clothing appearance and collision unapproved.",
        "runtime_network":False}
    REPORT.write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
    print("V30 CC0 CLOTHING RIG SOURCE PASS:",json.dumps({"parts":list(metrics),"joint_parent_matches":65,"files":len(ITEMS)}))
if __name__=="__main__":main()
