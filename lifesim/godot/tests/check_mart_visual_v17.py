#!/usr/bin/env python3
"""Static art asset contracts, not a replacement for Godot runtime QA."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=(root/'scripts/walkable_mart_v17.gd').read_text(encoding='utf-8')
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
assert 'walkable_mart = WalkableMartV17.new()' in main
for marker in ('extends WalkableMartV16','func _stock_fridge(', 'open_refrigerator_bays += 1',
               'refrigerated_skus += 1','cold_led_strips += 1','func _art_finish('):
    assert marker in source,marker
assert 'Vector3(center_x,1.16,-5.93)' in source
assert 'Vector3(center_x-.78+float(k)*.312,tier+.030+height*.5,-5.37)' in source
assert 'Vector3(center_x+side*.535,1.23,-5.009)' in source
assert 'Vector3(2.22,2.20,.77),casing,true' not in source, 'obsolete solid opaque cabinet'
for name in ('ivory_tile','warm_plaster','ash_wood'):
    for kind in ('base','normal'):
        p=root/'art'/'interiors_v17'/f'{name}_{kind}.png'
        assert p.exists() and p.stat().st_size>500,p
        with Image.open(p) as im:
            assert im.size==(512,512) and im.mode=='RGB',p
print('V17 STATIC PASS: 3 recessed refrigerators, 3 original textured finishes and no old solid cabinets')
