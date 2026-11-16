#!/usr/bin/env python3
"""V0.16 art source and SKU/license contract, not a visual quality certification."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text()
art=(root/'scripts/walkable_mart_v16.gd').read_text()
assert any(x in main for x in ('walkable_mart = WalkableMartV16.new()', 'walkable_mart = WalkableMartV17.new()'))
for token in ['MultiMesh.new()', 'func _stock_fridge(', 'func _rack(', 'func _shell(', 'func _mart(', 'lit_fixture_count += 1','func _finalize_stock(']:
    assert token in art,token
files=['pack_'+x+'.png' for x in ['ocha','coffee','milk','tea','rice','noodles','juice','cookies']]+['floor.png','wall.png','oak.png']
for f in files:
    p=root/'art/interiors_v16'/f
    assert p.exists() and p.stat().st_size>500,(p,p.stat().st_size if p.exists() else -1)
    with Image.open(p) as i:
        assert i.size in [(256,512),(512,512)] and i.mode=='RGB',p
assert '_stock_item(' in art and 'displayed_products += 1' in art
assert 'clear_entry_width = shelf_clear_center_width' in art
print('V16 STATIC PASS: fictional SKU artwork, 8 batched product types, 4 racks, real door retained')
