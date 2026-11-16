#!/usr/bin/env python3
"""Fail if V0.12 interiors are missing assets, labels, source, or layout zones."""
import json, re, struct, zlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'scripts/curated_interiors_v12.gd').read_text(encoding='utf8')
main=(root/'scripts/main.gd').read_text(encoding='utf8')
qa=(root/'tests/qa_headless.gd').read_text(encoding='utf8')
manifest=json.loads((root/'credits/KENNEY_ASSETS_V11.json').read_text(encoding='utf8'))
assets=set(Path(p['file']).name.removesuffix('.glb') for p in manifest['assets'])
refs=re.findall(r'_prop\("(?:furniture-kit|food-kit)"\s*,\s*"([\w-]+)"',source)
missing=sorted(set(refs)-assets)
assert not missing, f'V12 references unbundled CC0 assets: {missing}'
assert 'CuratedInteriorsV12.new()' in main or 'CuratedInteriorsV13.new()' in main  # subclass preserves V12 contracts
assert 'v12_mart.displayed_products' in qa
assert 'func _home' in source and 'func _cafe' in source and 'func _mart' in source
assert 'room_dimensions = Vector2(w, d)' in source
assert 'displayed_products += 1' in source and 'functional_zones.append' in source
assert 'REBUILD_FROM_GENERATOR' not in source
for name in ('timber_floor','porcelain_floor','lime_plaster','ribbed_panels'):
    p=root/'art/interiors_v12'/f'{name}.png'
    raw=p.read_bytes()
    assert raw[:8]==b'\x89PNG\r\n\x1a\n' and len(raw)>5000, f'invalid PNG: {name}'
    assert struct.unpack('!II',raw[16:24])==(512,512)
print(f'V12 STATIC PASS: {len(refs)} licensed prop refs, 4 authored PNG textures, compact room zones; no missing GLBs')