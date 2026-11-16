"""Independent admission test for Kenney CC0 glTF city + furnished interiors.
No network request; required assets are included in repository and Web export.
"""
from pathlib import Path
import json, struct, hashlib

root = Path(__file__).resolve().parents[1]
license_file = root / "credits" / "KENNEY_ASSETS_V11.json"
assert license_file.exists(), "third-party asset inventory missing"
manifest = json.loads(license_file.read_text(encoding="utf-8"))
assert manifest['license'] == 'CC0-1.0'
assert manifest['creator'] == 'Kenney'
assert len(manifest['assets']) >= 40
all_paths = set()
for a in manifest['assets']:
    rel = a['file']
    assert rel.startswith('art/third_party/kenney/') and rel.endswith('.glb')
    assert rel not in all_paths, f'duplicate {rel}'
    all_paths.add(rel)
    path = root / rel
    data = path.read_bytes()
    assert len(data) >= 512 and data[:4] == b'glTF'
    assert struct.unpack_from('<I', data, 4)[0] == 2
    assert struct.unpack_from('<I', data, 8)[0] == len(data)
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\x00'+data).hexdigest() == a['source_git_blob_sha1'], f'hash mismatch {rel}'
for script in ('scripts/curated_interiors_v11.gd','scripts/licensed_block_v11.gd'):
    assert (root/script).exists()
s = (root/'scripts/main.gd').read_text(encoding='utf8')
assert 'walkable_mart.build_shop("便利店")' in s and 'room.build_home(' in s
assert 'room.add_purchased_item(' in s
city=(root/'scripts/city_builder.gd').read_text(encoding='utf8')
assert 'LicensedBlockV11.new()' in city
print(f'V11 ASSET PASS: {len(all_paths)} bundled CC0 GLB scenes and upstream git-blob-SHA1 ledger')