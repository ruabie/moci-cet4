#!/usr/bin/env python3
"""Offline structural checks only, NOT a Godot engine runtime test."""
from pathlib import Path
import re
import sys
root = Path(__file__).resolve().parents[1]
checks = {
    'project config': root / 'project.godot',
    'main scene': root / 'scenes/main.tscn',
    'main controller': root / 'scripts/main.gd',
    'player controller': root / 'scripts/player.gd',
    'clock': root / 'scripts/world_clock.gd',
    'state': root / 'scripts/game_state.gd',
    'city builder': root / 'scripts/city_builder.gd',
    'headless QA': root / 'tests/qa_headless.gd',
}
failures = []
for name, path in checks.items():
    if not path.exists() or path.stat().st_size == 0:
        failures.append(f'Missing {name}: {path}')
scene = (root / 'scenes/main.tscn').read_text()
for path in re.findall(r'path="(res://[^"]+)"', scene):
    actual = root / path.removeprefix('res://')
    if not actual.exists():
        failures.append(f'Missing referenced resource: {path}')
project = (root / 'project.godot').read_text()
if '[application]' not in project or 'run/main_scene=' not in project:
    failures.append('Project entrypoint missing')
if project.count('[application]') != 1:
    failures.append('Duplicate application section')
source = '\n'.join(p.read_text() for p in (root / 'scripts').glob('*.gd'))
for snippet in ('Time.get_datetime_dict_from_system', 'Time.get_unix_time_from_system',
                'move_and_slide()', 'intersect_ray(', 'purchase(', 'pay_job_once(',
                'write_save(', 'read_save(', 'OmniLight3D', 'CollisionShape3D',
                'DirectionalLight3D', 'WorldEnvironment', 'get_vector('):
    if snippet not in source:
        failures.append(f'Missing required source feature: {snippet}')
for forbidden in ('cdn.jsdelivr', 'unpkg.com', 'http://', 'https://'):
    if forbidden in source:
        failures.append(f'Forbidden runtime network dependency {forbidden}')

print('V0.3 offline structural QA:')
for name in checks:
    print(' -', name, 'present' if checks[name].is_file() else 'MISSING')
if failures:
    for fail in failures:
        print('FAIL:', fail, file=sys.stderr)
    sys.exit(1)
print('PASS: all static structural checks (engine execution NOT tested)')
