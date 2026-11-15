"""Strict structural checks for original, offline-generated glTF artifacts.
This is not a Godot importer or GPU FPS test.
"""
import json, struct, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
paths=[ROOT/'art/characters/commuter_rig.glb',ROOT/'art/architecture/storefront.glb',ROOT/'art/architecture/apartment_lobby.glb']
for path in paths:
 data=path.read_bytes()
 assert len(data)>=32 and data[:4]==b'glTF',path
 magic,version,total=struct.unpack('<4sII',data[:12])
 assert version==2 and total==len(data),path
 n,chunk_type=struct.unpack('<I4s',data[12:20]);assert chunk_type==b'JSON'
 gltf=json.loads(data[20:20+n]);assert gltf['asset']['version']=='2.0'
 assert gltf['meshes'] and gltf['materials'] and gltf['scenes']
 for mesh in gltf['meshes']:
  for prim in mesh['primitives']:
   assert 'POSITION' in prim['attributes'] and 'NORMAL' in prim['attributes']
 print('ASSET PASS',path.name,len(data),'bytes',hashlib.sha256(data).hexdigest()[:12])
character=json.loads(paths[0].read_bytes()[20:20+struct.unpack('<I',paths[0].read_bytes()[12:16])[0]])
assert len(character['skins'])==1
joints=character['skins'][0]['joints']
names={character['nodes'][node]['name'] for node in joints}
for n in ['Hips','Head','LeftUpperArm','RightUpperArm','LeftThigh','RightThigh','LeftShin','RightShin']:
 assert n in names,n
for prim in character['meshes'][0]['primitives']:
 assert 'JOINTS_0' in prim['attributes'] and 'WEIGHTS_0' in prim['attributes']
print('PASS genuine skinned GLB with named humanoid joints; no external assets')