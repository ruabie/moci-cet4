#!/usr/bin/env python3
"""Verify original CC0 humanoid GLB blobs, skins and joint names; Godot is tested separately."""
import hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SHAS={
'player_casual':'8de02ab8cc15be5d4375373675f886d347bef11e',
'worker_male':'f9c8aa373fe950dded61eab9b4a895e71d58ddb0',
'casual_female':'f64c3d48148aef1e431abec40ae0cf33c1db93d5',
'formal_female':'b53a2e76450e5b7636a44b2780f52aede5de950f',
'casual_male':'a74f94183952267a874c24ac73c4d2382fd0187d',
'suit_male':'7de8d95b6ad1cab6119e4bea4e08ae6f258604ca',
'worker_female':'6da19c9cdab1d749ca13f5ff93eae954e0aa1def',
}
for name, expected in SHAS.items():
 data=(ROOT/'art/characters/v18'/f'{name}.glb').read_bytes()
 assert hashlib.sha1(f'blob {len(data)}\0'.encode()+data).hexdigest()==expected,name
 assert data[:4]==b'glTF' and struct.unpack_from('<I',data,4)[0]==2
 assert struct.unpack_from('<I',data,8)[0]==len(data)
 length,kind=struct.unpack_from('<I4s',data,12)
 assert kind==b'JSON'
 doc=json.loads(data[20:20+length])
 assert len(doc.get('skins',[]))>=1 and doc.get('meshes') and doc.get('materials')
 names={doc['nodes'][i].get('name') for i in doc['skins'][0]['joints']}
 assert len(names)>=40
 for joint in ('Hips','Head','UpperLeg.L','UpperLeg.R','LowerLeg.L','LowerLeg.R','UpperArm.L','UpperArm.R'):
  assert joint in names,(name,joint)
 print('V18 CHARACTER PASS:',name,len(names),'bones',len(data),'bytes')
print('V18 CHARACTERS PASS: seven unmodified CC0 source blobs')
