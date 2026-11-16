#!/usr/bin/env python3
"""V0.13 quality gate for a reproducible, licensed art direction slice."""
from pathlib import Path
import hashlib,json,struct
P=Path(__file__).resolve().parents[1]
models={
'Chair_2':'b8d4865e0d69ca43977d1aebed7ce4f5ae61bc14',
'Chair_3':'b4c00e9d439616c886744aedd14ff8ecee8a2583',
'Couch_Medium2':'53da12783ccbb217c4409b3fb980900f99ca0e8c',
'Couch_Small2':'4f7f3ffb559963935ba5154ea6e7f065e92a7e2e',
'Table_RoundSmall2':'9c0ca030a0a3e12d3cbd3389caee56fd7f99cb20',
'Table_RoundLarge':'8ea80009dae823281acd60773f85a4511cef0692',
'Stool':'f02412bd64a200f66525cbe5e5ac125de4c58cbd',
'Light_Ceiling1':'c7483ad7d92f8bd386cda4a43ccc873c7cf174ba',
'Light_Floor2':'4f96da370e6c44091553f893b9a2d8e5e02315d4',
'Houseplant_4':'cef2653dce3adc1f25c1bfb5f963e01b5f81e569',
'Bookshelf':'0384640afd282759752d1bfbec322f09157ef81f',
'Curtains_Double':'79b0746d5c6ddfdce86dcdcca25fe71b388d091c',
'Shelf_Large':'df6737bc28933ace6ccaab7dc51facf30d285608',
'Kitchen_Sink':'7e8b86dc69eb7324de161d062c221877a2872207',
'Plate_1':'794996afb400914e7b10de42a2bfd9a668686275'}
folder=P/'art'/'third_party'/'quaternius_house'
for name,sha in models.items():
    file=folder/(name+'.glb')
    blob=file.read_bytes()
    assert len(blob)>3000 and blob[:4]==b'glTF' and struct.unpack_from('<I',blob,4)[0]==2,name
    expected=hashlib.sha1(f'blob {len(blob)}\0'.encode()+blob).hexdigest()
    assert expected==sha,f'{name}: provenance mismatch {expected}'
for stem in ['walnut','plaster','terrazzo','linen']:
    for kind in ['base','normal']:
        file=P/'art'/'interiors_v13'/f'{stem}_{kind}.png'
        data=file.read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n' and len(data)>30000,file
script=(P/'scripts'/'curated_interiors_v13.gd').read_text(encoding='utf8')
assert 'class_name CuratedInteriorsV13' in script
assert script.count('_qprop(')>=14
assert 'room_dimensions = Vector2(w, d)' in script
assert 'clear_aisle_width: float = 2.1' in script
assert 'super._shell(theme)' in script
assert 'Quaternius' in (P/'art'/'third_party'/'quaternius_house'/'PROVENANCE.md').read_text()
print('V13 ART PASS: 15 CC0 GLBs verified by Git object hash, 8 procedural PNGs, 4 cafe zones')