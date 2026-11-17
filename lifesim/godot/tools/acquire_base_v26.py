#!/usr/bin/env python3
"""Acquire pinned CC0 Universal Base Character for a nonproduction V0.26 trial.

Quaternius authors both the UAL in-place animations and Universal Base Characters.
The project must never resolve a moving branch or download assets in gameplay.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import struct
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "art" / "characters" / "v26" / "base_character_compatible.glb"
MANIFEST = ROOT / "tests" / "v26_base_provenance.json"
COMMIT = "bb2ce469f0ab2ccfc487faef55550ba07fae2483"
BLOB = "59c4044d5146146170f1c6d5e765985a73bc7875"
SIZE = 1085752
URL = ("https://raw.githubusercontent.com/Barbatos6669/elderforge/"
       + COMMIT + "/assets/characters/base/BaseCharacter.glb")
ORIGINAL = "https://quaternius.itch.io/universal-base-characters"

def gitblob(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\\0".encode().replace(b"\\0",b"\0")+data).hexdigest()

def inspect(data: bytes) -> dict:
    if len(data)!=SIZE: raise ValueError(f"expected {SIZE} bytes, got {len(data)}")
    actual=gitblob(data)
    if actual!=BLOB: raise ValueError(f"pinned git blob mismatch: {actual}")
    if data[:4]!=b"glTF": raise ValueError("not a GLB")
    version,total=struct.unpack_from("<II",data,4)
    length,typ=struct.unpack_from("<II",data,12)
    if version!=2 or total!=len(data) or typ!=0x4E4F534A: raise ValueError("invalid GLB envelope")
    obj=json.loads(data[20:20+length].decode("utf-8").strip("\0 \n\t\r"))
    nodes=obj.get("nodes",[])
    skins=obj.get("skins",[])
    if not obj.get("meshes") or not skins or len(skins[0].get("joints",[]))<55:
        raise ValueError("no usable skinned humanoid mesh")
    names={str(nodes[i].get("name","")) for i in skins[0]["joints"]}
    expected={"root","pelvis","spine_01","spine_03","thigh_l","calf_l","foot_l",
              "thigh_r","calf_r","foot_r","clavicle_l","upperarm_l","lowerarm_l",
              "clavicle_r","upperarm_r","Head"}
    if not expected.issubset(names):
        raise ValueError(f"unexpected Universal Base Character skeleton: {sorted(expected-names)}")
    return {"creator":"Quaternius", "license":"CC0-1.0 Universal",
      "official_pack":ORIGINAL, "mirror_repository":"Barbatos6669/elderforge",
      "mirror_commit":COMMIT,"mirror_path":"assets/characters/base/BaseCharacter.glb",
      "git_blob_sha1":BLOB,"sha256":hashlib.sha256(data).hexdigest(),
      "size_bytes":SIZE,"mesh_count":len(obj["meshes"]),"bone_count":len(names),
      "key_bones_checked":sorted(expected),"animations_bundled":len(obj.get("animations",[])),
      "build_time_download_only":True,"runtime_download":False}

def main():
    DEST.parent.mkdir(parents=True,exist_ok=True)
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    if DEST.exists():
        data=DEST.read_bytes()
    else:
        request=urllib.request.Request(URL,headers={"User-Agent":"LifeSim-CC0-art-audit"})
        with urllib.request.urlopen(request, timeout=60) as f:
            data=f.read(SIZE+1)
    info=inspect(data)
    if not DEST.exists(): DEST.write_bytes(data)
    MANIFEST.write_text(json.dumps(info,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print("V26 PINNED CC0 BASE CHARACTER PASS:",json.dumps(info,ensure_ascii=False))

if __name__=="__main__":
    try: main()
    except Exception as exc:
        print("V26 BASE ASSET FAIL:",str(exc),file=sys.stderr)
        raise SystemExit(1)
