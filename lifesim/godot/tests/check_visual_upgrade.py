#!/usr/bin/env python3
"""V0.4 source contract, supplement to actual Godot engine tests."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
player = (root / 'scripts' / 'player.gd').read_text(encoding='utf-8')
city = (root / 'scripts' / 'city_builder.gd').read_text(encoding='utf-8')
main = (root / 'scripts' / 'main.gd').read_text(encoding='utf-8')
checks = {
 'articulated knees': all(x in player for x in ['LeftHip','RightHip','LeftKnee','RightKnee','anim_weight']),
 'camera occlusion': 'intersect_ray(query)' in player,
 'storefront awnings and planters': '_awning(' in city and '_planter(' in city,
 'local paving textures': all((root / 'art' / 'textures' / name).stat().st_size > 500 for name in ['asphalt.png','concrete.png','stucco.png']),
 'ambient residents': 'AmbientResidents' in city and 'npc.rotation.y = atan2(' in city,
 'skyline and street furniture': '_parked_bicycle(' in city and 'Distant skyline' in city,
 'UI styles': 'StyleBoxFlat.new()' in main,
 'real time preserved': 'WorldClock.snapshot()' in main,
}
for name, ok in checks.items():
 print(('PASS' if ok else 'FAIL')+': '+name)
if not all(checks.values()): sys.exit(1)
print('PASS: visual upgrade source contract (not an image-quality assessment)')