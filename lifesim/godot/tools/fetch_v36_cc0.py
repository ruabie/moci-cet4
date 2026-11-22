#!/usr/bin/env python3
"""Fail-closed acquisition of three exact CC0 urban facade GLBs (build-time only).

Do not substitute bytes on download failure. The source site is an external
supply-chain dependency and no unverified fallback may be silently used.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "credits" / "TEVY_V36_SOURCE.json"
TARGET = ROOT / "art" / "third_party" / "tevy_v36"

def check_glb(data: bytes, record: dict) -> dict:
    assert len(data) == record["bytes"], "unexpected byte size: " + record["slug"]
    assert hashlib.sha256(data).hexdigest() == record["sha256"], "SHA256 mismatch: " + record["slug"]
    assert data[:4] == b"glTF", "not a glb: " + record["slug"]
    version, file_size = struct.unpack_from("<II", data, 4)
    assert version == 2 and file_size == len(data), "invalid GLB header/length"
    json_len, json_type = struct.unpack_from("<II", data, 12)
    assert json_type == 0x4E4F534A and json_len > 128, "missing glTF JSON chunk"
    gltf = json.loads(data[20:20+json_len].decode("utf-8"))
    assert gltf.get("asset", {}).get("version") == "2.0"
    assert gltf.get("meshes"), "empty mesh list"
    assert gltf.get("materials"), "unshaded/unmaterialed GLB"
    assert gltf.get("accessors"), "missing mesh geometry"
    return {"model":record["slug"],"size":len(data),
            "sha256":record["sha256"],"meshes":len(gltf["meshes"]),
            "materials":len(gltf["materials"]),
            "triangles_catalogued":record["triangles"]}

def main() -> None:
    metadata = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert metadata["license"] == "CC0-1.0" and len(metadata["models"]) == 3
    TARGET.mkdir(parents=True, exist_ok=True)
    outcome = []
    for model in metadata["models"]:
        slug = model["slug"]
        assert slug.startswith("housing-facade-")
        assert model["source"].startswith("https://tevy.dev/models/" + slug + "/v1/")
        path = TARGET / (slug + ".glb")
        good = None
        if path.is_file():
            try:
                good = check_glb(path.read_bytes(), model)
            except (AssertionError, ValueError, struct.error, json.JSONDecodeError):
                path.unlink()
        if good is None:
            last_error = None
            for attempt in range(3):
                try:
                    request = Request(model["source"], headers={"User-Agent":"LifeSim-CC0-verified-art-intake/0.36"})
                    with urlopen(request, timeout=35) as response:
                        data = response.read(8_000_001)
                    good = check_glb(data, model)
                    temp = path.with_suffix(".tmp")
                    temp.write_bytes(data)
                    temp.replace(path)
                    break
                except (OSError, ValueError, AssertionError, struct.error, json.JSONDecodeError) as exc:
                    last_error = str(exc)
                    time.sleep(attempt + 1)
            if good is None:
                raise RuntimeError("PINNED CC0 INTAKE FAIL " + slug + ": " + str(last_error))
        outcome.append(good)
        print("PINNED MODEL PASS", slug, good["sha256"], good["size"], flush=True)
    report = {"ok":True,"version":"V0.36","license":"CC0-1.0",
              "models":outcome,"total_bytes":sum(x["size"] for x in outcome),
              "strict_sha_verified":True,"game_runtime_network_needed":False}
    out = ROOT / "tests" / "v36_asset_source_audit.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("V36 PINNED CC0 SOURCE AUDIT PASS:",json.dumps(report))

if __name__ == "__main__":
    main()
