#!/usr/bin/env python3
"""V0.7 structural mesh gate. Static data QA; visual review still separate."""
import pathlib,json,struct
p=pathlib.Path(__file__).resolve().parents[1]
spec={"mart":(21,10,17),"coffee":(20,13,17),"apartment":(21,18,18),"living":(20,12,19)}
for key,(depth,height,width) in spec.items():
 f=p/"art"/"architecture"/f"v07_{key}_integrated.glb"
 assert f.is_file(),f"missing {f}; run build_street_v07.py"
 raw=f.read_bytes()
 assert raw[:4]==b"glTF"
 assert struct.unpack_from("<I",raw,8)[0]==len(raw)
 jlen=struct.unpack_from("<I",raw,12)[0]
 doc=json.loads(raw[20:20+jlen])
 names={m["name"] for m in doc["materials"]}
 assert "continuous_masonry" in names and "recessed_glazing" in names
 assert len(names)<=16
 counts=sum(doc["accessors"][x["indices"]]["count"]//3 for m in doc["meshes"] for x in m["primitives"])
 assert counts<6500,(key,counts)
 assert any("continuous" in x for x in names)
 print("V0.7 GLB PASS",key,len(raw),"bytes",counts,"triangles")
code=(p/"scripts"/"city_builder.gd").read_text(encoding="utf8")
assert "_integrated_building(" in code and "_integrated_forecourts()" in code
assert "    _authored_facades()" not in code
assert "    _awning(-17.52" not in code
assert "res://art/architecture/v08_%s_integrated.glb" in code
print("V0.7 baseline GLBs validated; current V0.8 street path confirmed")
