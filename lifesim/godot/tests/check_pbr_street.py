#!/usr/bin/env python3
"""Verify v0.8 glTF PBR structure; still requires visual and gameplay approval."""
import pathlib,json,struct
root=pathlib.Path(__file__).resolve().parents[1]
for kind in ("mart","coffee","apartment","living"):
    f=root / "art" / "architecture" / ("v08_%s_integrated.glb"%kind)
    raw=f.read_bytes()
    assert raw[:4]==b"glTF" and struct.unpack_from("<I",raw,8)[0]==len(raw), f
    n=struct.unpack_from("<I",raw,12)[0]
    obj=json.loads(raw[20:20+n])
    offset=20+n
    binlength=struct.unpack_from("<I",raw,offset)[0]
    assert raw[offset+4:offset+8]==b"BIN\x00"
    blob=raw[offset+8:offset+8+binlength]
    assert obj["buffers"][0]["byteLength"]<=len(blob)
    assert len(obj["images"])==5 and len(obj["textures"])==5
    for pic in obj["images"]:
        view=obj["bufferViews"][pic["bufferView"]]
        assert pic["mimeType"]=="image/png"
        assert blob[view["byteOffset"]:view["byteOffset"]+8]==b"\x89PNG\r\n\x1a\n"
    count=0
    for prim in obj["meshes"][0]["primitives"]:
        a=prim["attributes"]
        assert {"POSITION","NORMAL","TEXCOORD_0"}.issubset(a)
        assert obj["accessors"][a["POSITION"]]["count"]==obj["accessors"][a["TEXCOORD_0"]]["count"]
        count+=obj["accessors"][prim["indices"]]["count"]//3
    assert 1200<count<9000,(f,count)
    materials=obj["materials"]
    assert any("baseColorTexture" in x["pbrMetallicRoughness"] for x in materials)
    assert any(("interior_window" in x["name"] or "recessed_glazing" in x["name"]) and x.get("alphaMode")=="BLEND" and x["pbrMetallicRoughness"]["baseColorFactor"][3]<0.4 for x in materials)
    assert any("room_floor" in x["name"] for x in materials)
    print("V08 PBR PASS",kind,"triangles",count)
city=(root/"scripts/city_builder.gd").read_text()
assert "v08_%s_integrated.glb" in city
assert "V08TexturedEnvelopeAndInterior" in city
print("V08 ASSET PASS: four embedded PBR GLBs with interior volumes and UVs")
