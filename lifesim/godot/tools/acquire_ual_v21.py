#!/usr/bin/env python3
"""Acquire immutable CC0 Quaternius UAL1 in-place GLB for the V0.21 build only.

No remote asset request occurs when a player starts the game. The pinned archive
is downloaded at build time, checked before it enters Godot, and packaged with
the CI-generated project artifact. Never treat a mirror as the original author.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import urllib.request

PROJECT = Path(__file__).resolve().parents[1]
DEST = PROJECT / "art" / "animations" / "v21" / "ual1_inplace.glb"
MANIFEST = PROJECT / "tests" / "v21_ual_manifest.json"

# Exact third-party mirror commit and Git blob. License independently verified
# against Quaternius official pack: https://quaternius.itch.io/universal-animation-library
SOURCE_COMMIT = "bb2ce469f0ab2ccfc487faef55550ba07fae2483"
SOURCE_BLOB = "473e59080288428d0b6da826ba19324d07b191f0"
SOURCE_SIZE = 7618436
SOURCE_URL = (
    "https://raw.githubusercontent.com/Barbatos6669/elderforge/"
    f"{SOURCE_COMMIT}/assets/animations/universal_animation_library_1/UAL1_Standard.glb"
)

def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()

def validate(data: bytes) -> dict:
    if len(data) != SOURCE_SIZE:
        raise ValueError(f"CC0 source asset byte size mismatch: {len(data)} != {SOURCE_SIZE}")
    actual = git_blob_sha(data)
    if actual != SOURCE_BLOB:
        raise ValueError(f"CC0 source Git blob mismatch: {actual} != {SOURCE_BLOB}")
    if data[:4] != b"glTF":
        raise ValueError("not a glTF binary")
    version, total = struct.unpack_from("<II", data, 4)
    if version != 2 or total != len(data):
        raise ValueError("unsupported GLB version/length")
    json_len, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A or json_len < 100:
        raise ValueError("missing glTF JSON chunk")
    obj = json.loads(data[20:20 + json_len].decode("utf-8").rstrip(" \t\r\n\0"))
    animations = obj.get("animations", [])
    skins = obj.get("skins", [])
    if len(animations) < 10 or not skins:
        raise ValueError("animation package missing actual humanoid clips/skin")
    clip_names = [str(a.get("name", f"unnamed_{i}")) for i, a in enumerate(animations)]
    lower_names = [s.lower() for s in clip_names]
    if not any("walk" in s or "jog" in s for s in lower_names):
        raise ValueError("locomotion clip not found")
    if not any("idle" in s for s in lower_names):
        raise ValueError("idle clip not found")
    nodes = obj.get("nodes", [])
    skin_nodes = [
        [str(nodes[idx].get("name", str(idx))) for idx in skin.get("joints", [])]
        for skin in skins
    ]
    if max(map(len, skin_nodes)) < 35:
        raise ValueError("insufficient skeleton nodes")
    return {
        "license": "CC0-1.0",
        "author": "Quaternius",
        "upstream_official": "https://quaternius.itch.io/universal-animation-library",
        "source_mirror_commit": SOURCE_COMMIT,
        "source_git_blob": SOURCE_BLOB,
        "sha256": hashlib.sha256(data).hexdigest(),
        "size_bytes": len(data),
        "clip_count": len(animations),
        "clip_names": clip_names,
        "skin_joint_names": skin_nodes,
        "build_time_only": True,
        "runtime_cdn_dependency": False,
    }

def main() -> int:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    if DEST.exists():
        candidate = DEST.read_bytes()
        if git_blob_sha(candidate) == SOURCE_BLOB:
            info = validate(candidate)
        else:
            raise ValueError("existing UAL GLB wrong hash; refuse overwrite")
    else:
        request = urllib.request.Request(SOURCE_URL, headers={"User-Agent":"LifeSim-CC0-provenance-v21"})
        with urllib.request.urlopen(request, timeout=60) as stream:
            candidate = stream.read(SOURCE_SIZE + 1)
        info = validate(candidate)
        DEST.write_bytes(candidate)
    MANIFEST.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("V21 UAL SOURCE PASS:", info["clip_count"], "clips, SHA256", info["sha256"])
    print("V21 UAL CLIP NAMES:", ", ".join(info["clip_names"][:80]))
    print("V21 UAL SKELETON:", json.dumps(info["skin_joint_names"][0][:75]))
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print("V21 UAL SOURCE FAIL:", exc, file=sys.stderr)
        raise SystemExit(1)
