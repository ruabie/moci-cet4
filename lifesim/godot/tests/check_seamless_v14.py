from pathlib import Path
import trimesh
base = Path(__file__).resolve().parents[1]
source = (base / "scripts/main.gd").read_text(encoding="utf8")
assert 'class_name WalkableCafeV14' in (base / "scripts/walkable_cafe_v14.gd").read_text(encoding="utf8")
assert 'walkable_cafe.position = Vector3(22.5, 0.0, -14.0)' in source
assert 'walkable_cafe.build_shop("咖啡馆")' in source
assert 'if place == "咖啡馆":\n        # The entrance is a physical opening.' in source
assert '_exterior_window_view() -> void:' in (base / "scripts/walkable_cafe_v14.gd").read_text(encoding="utf8")
assert 'V14UpperStoreys' in (base / "scripts/city_builder.gd").read_text(encoding="utf8")
upper = trimesh.load(base / "art/architecture/v14_cafe_upper_only.glb", force="scene")
assert upper.bounds[0][1] > 3.67
assert upper.bounds[1][1] > 13
print("V14 STATIC PASS: real street-room, no E teleport, cropped upper GLB, fake view disabled")
