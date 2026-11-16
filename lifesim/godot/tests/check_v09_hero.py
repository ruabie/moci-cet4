#!/usr/bin/env python3
"""V0.9 asset and preservation contract. Art approval requires actual images."""
import json, pathlib, struct
ROOT=pathlib.Path(__file__).resolve().parents[1]
def load(name):
    data=(ROOT/'art'/'architecture'/name).read_bytes()
    assert data[:4]==b'glTF' and struct.unpack_from('<I',data,8)[0]==len(data)
    n=struct.unpack_from('<I',data,12)[0]
    obj=json.loads(data[20:20+n])
    size=struct.unpack_from('<I',data,20+n)[0]
    binary=data[28+n:28+n+size]
    assert len(binary)==size
    return obj,binary
old,_=load('v08_coffee_integrated.glb')
hero,bin=load('v09_coffee_integrated.glb')
assert len(old['images'])==5 and len(hero['images'])==6
material={m['name']:m for m in hero['materials']}
for name in ['v09_satin_timber_louvers','v09_matte_anodized_black','v09_woven_awnings',
             'v09_handmade_ceramic','v09_pastry_display_glass','v09_espresso_machine']:
    assert name in material,name
mat=material['continuous_masonry']
assert mat['normalTexture']['scale']>.1
idx=mat['normalTexture']['index']
img=hero['images'][hero['textures'][idx]['source']]
assert 'masonry_normal' in img['name']
view=hero['bufferViews'][img['bufferView']]
assert bin[view['byteOffset']:view['byteOffset']+8]==b'\x89PNG\r\n\x1a\n'
def triangles(o):
    return sum(o['accessors'][p['indices']]['count']//3 for p in o['meshes'][0]['primitives'])
assert triangles(old)+2500<triangles(hero)<18000
for mesh in hero['meshes'][0]['primitives']:
    attr=mesh['attributes']
    assert {'POSITION','NORMAL','TEXCOORD_0'}.issubset(attr)
    assert hero['accessors'][attr['POSITION']]['count']==hero['accessors'][attr['TEXCOORD_0']]['count']
scene=(ROOT/'scripts/city_builder.gd').read_text(encoding='utf-8')
assert 'v14_cafe_upper_only.glb' in scene and 'v08_%s_integrated.glb' in scene
qa=(ROOT/'tests/qa_headless.gd').read_text(encoding='utf-8')
assert 'Authored_KAWA_COFFEE/V14UpperStoreys' in qa
print('V09 ASSET PASS:', triangles(hero),'hero triangles, embedded original PBR textures and normals, non-cafe V08 preserved')
print('QUALITY GATE: still requires real Godot viewport image and human review')
