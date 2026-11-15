#!/usr/bin/env python3
"""Only source/asset structural checks. Does not claim visual acceptance."""
import json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=['zelkova_full','katsura_warm','zelkova_narrow','street_shrub']
for name in files:
 p=ROOT/'art'/'vegetation'/f'{name}.glb'
 assert p.is_file(), f'missing V10 vegetation {p}'
 raw=p.read_bytes()
 magic,version,total=struct.unpack_from('<4sII',raw)
 assert magic==b'glTF' and version==2 and total==len(raw), name
 size,tag=struct.unpack_from('<I4s',raw,12)
 assert tag==b'JSON'
 doc=json.loads(raw[20:20+size])
 assert len(doc.get('materials',[]))>=5, name
 assert any(('leaf' in m.get('name','') or 'leaves' in m.get('name','')) for m in doc['materials']), name
 total_faces=sum(doc['accessors'][p['indices']]['count']//3
                 for mesh in doc['meshes'] for p in mesh['primitives'])
 assert 900 < total_faces < 22000, (name,total_faces)
 print(f'V10 GLB PASS: {name}, {total_faces} triangles, materials={len(doc["materials"])}')
city=(ROOT/'scripts'/'city_builder.gd').read_text(encoding='utf8')
backdrop=(ROOT/'scripts'/'district_backdrop_v10.gd').read_text(encoding='utf8')
assert 'V10DistantUrbanBackdrop' in city
assert 'DistrictBackdropV10.new()' in city
assert 'street_shrub.glb' in city
assert 'zelkova_full' in city
assert '_sphere(root, Vector3(0, height' not in city
assert 'MultiMeshInstance3D.new()' in backdrop
assert '_row_housing' in backdrop and '_side_building' in backdrop
print('V10 STATIC PASS: vegetation, sky backdrop, window instancing and source integration')