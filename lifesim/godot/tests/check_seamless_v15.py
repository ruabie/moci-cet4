#!/usr/bin/env python3
"""V0.15 structural contract. Not a replacement for Godot physics QA."""
from pathlib import Path
import trimesh
r = Path(__file__).resolve().parents[1]
main = (r/'scripts/main.gd').read_text(encoding='utf8')
city = (r/'scripts/city_builder.gd').read_text(encoding='utf8')
player = (r/'scripts/player.gd').read_text(encoding='utf8')
assert any(n in main for n in ('walkable_mart = WalkableMartV15.new()', 'walkable_mart = WalkableMartV16.new()'))
assert 'walkable_mart.build_shop("便利店")' in main
assert 'walkable_mart.position = Vector3(-22.35, 0.0, -14.0)' in main
assert '_sync_walkable_mart()' in main
assert 'player.position = Vector3(0, 0.2, 192.5' not in main
assert 'if player != null and not in_home:' in main, 'save must persist real-world positions inside mart'
assert 'V15UpperStoreys' in city
assert 'camera_collision_activations' in player and 'cast_motion(camera_sweep_query)' in player
m = trimesh.load(r/'art/architecture/v15_mart_upper_only.glb',force='scene')
assert m.bounds[0][1] >= 4.29, m.bounds
assert m.bounds[1][1] >= 10.0, m.bounds
print('V15 STATIC PASS: traversable mart, savable shared coordinates, physical upper-only model, sphere-swept camera')
