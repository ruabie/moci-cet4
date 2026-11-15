extends Node3D
class_name DistrictBackdropV10

# Visual-only low-detail urban layers. The previous prototype spawned 36
# identical solid cubes; this uses deliberately nonrepeating silhouettes,
# changing floor counts, roof setbacks, and one MultiMesh per window treatment.
# Geometry has no collisions: the actual walkable town is unchanged.
var _materials: Dictionary = {}
var _windows_dark: Array[Transform3D] = []
var _windows_warm: Array[Transform3D] = []
var _windows_side: Array[Transform3D] = []

func _mat(color_hex: String, roughness: float = 0.91) -> StandardMaterial3D:
    var key: String = color_hex + str(roughness)
    if _materials.has(key):
        return _materials[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(color_hex)
    mat.roughness = roughness
    _materials[key] = mat
    return mat

func _block(pos: Vector3, size: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visual.position = pos
    add_child(visual)

func _window_batch(transforms: Array[Transform3D], color_hex: String, width: float = 1.08) -> void:
    if transforms.is_empty():
        return
    var panel := BoxMesh.new()
    panel.size = Vector3(width, 1.4, 0.045)
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = panel
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.multimesh = instances
    node.material_override = _mat(color_hex, 0.46)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _row_housing(index: int, x: float, z: float, facings: float, rng: RandomNumberGenerator) -> void:
    var width: float = rng.randf_range(9.3, 13.5)
    var depth: float = rng.randf_range(9.0, 15.0)
    var floors: int = rng.randi_range(4, 10)
    var height: float = float(floors) * 3.15
    var palette: Array[String] = ["#8b9a93", "#a4a7a0", "#949e9e", "#aa9b8d", "#89948e", "#9ca69e"]
    var facade := _mat(palette[index % palette.size()])
    var accent := _mat("#687876" if index % 3 == 0 else "#7e8780")
    var roof := _mat("#626e6b")
    # Street-level podium and main body are different construction volumes.
    _block(Vector3(x, 1.7, z), Vector3(width + 0.5, 3.4, depth + 0.4), accent)
    _block(Vector3(x, 3.4 + (height - 3.4) * .5, z), Vector3(width, height - 3.4, depth), facade)
    var trim_level: float = height * .57
    if index % 3 == 0:
        # Upper storey pulled in: genuine spatial silhouette rather than a sticker.
        _block(Vector3(x, height + 1.6, z + facings*.65), Vector3(width - 2.15, 3.2, depth - 2.3), facade)
        _block(Vector3(x, height + 3.27, z + facings*.65), Vector3(width - 1.6, .20, depth - 1.8), roof)
    else:
        _block(Vector3(x, height + .12, z), Vector3(width + .15, .24, depth + .20), roof)
    if index % 4 == 0:
        _block(Vector3(x - width*.28, height + .55, z - depth*.1), Vector3(2.15, 1.1, 3.0), roof)
    elif index % 4 == 1:
        _block(Vector3(x + width*.24, height + .55, z + depth*.18), Vector3(2.7, 1.1, 2.0), accent)
    var face: float = z + facings * (depth*.5 + .047)
    var col_count: int = clampi(int(width / 2.6), 3, 6)
    for floor_n in range(1, floors):
        var yy: float = 3.35 + float(floor_n - 1) * 3.12 + 1.05
        for col in range(col_count):
            # Some rooms are unlit, some curtained, and not all bays repeat.
            if ((col * 11 + floor_n * 7 + index * 3) % 13) in [2, 9]:
                continue
            var xx: float = x + (float(col) - float(col_count-1) * .5) * (width / float(col_count))
            var window_position: Vector3 = Vector3(xx, yy, face)
            var warm: bool = ((col * 7 + floor_n * 3 + index) % 19) == 0
            if warm:
                _windows_warm.append(Transform3D(Basis(), window_position))
            else:
                _windows_dark.append(Transform3D(Basis(), window_position))
    # Lower shop / lobby panels separate ground floor from repetitive housing.
    _block(Vector3(x, 2.24, face), Vector3(width*.58, 2.2, .10), _mat("#46585a", .39))
    _block(Vector3(x, .65, face + facings*.045), Vector3(width*.64, .11, .17), roof)

func _side_building(index: int, x: float, z: float, facings: float, rng: RandomNumberGenerator) -> void:
    # Side-wall silhouette connects the two distant back rows.
    var width: float = rng.randf_range(11.0, 18.0)
    var depth: float = rng.randf_range(7.0, 11.5)
    var height: float = rng.randf_range(14.0, 29.0)
    var facade := _mat("#8b9998" if index % 2 == 0 else "#969c91")
    var roof := _mat("#697875")
    _block(Vector3(x, height*.5, z), Vector3(width, height, depth), facade)
    _block(Vector3(x, height+.13, z), Vector3(width+.4,.26,depth+.4),roof)
    var face_x: float = x + facings * (width*.5+.08)
    for floor_n in range(2, int(height / 3.0)):
        var y: float = float(floor_n) * 2.9
        for col in range(3):
            var zz: float = z + (float(col)-1.0) * (depth*.27)
            var transform := Transform3D(Basis(Vector3.UP,PI*.5), Vector3(face_x,y,zz))
            _windows_side.append(transform)

func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 778083
    # Two rows, staggered by 5.5m. These sit beyond the play boundary.
    for row in range(2):
        for i in range(14):
            var x: float = -87.5 + float(i) * 13.3 + (4.1 if row == 1 else 0.0)
            var z: float = -112.0 if row == 0 else 110.0
            _row_housing(i + row * 14, x, z, 1.0 if row == 0 else -1.0, rng)
    for edge in [-1,1]:
        for i in range(8):
            var zz: float = -83.0 + float(i)*22.0 + rng.randf_range(-3.2, 3.2)
            _side_building(i + 15 * (edge+1), float(edge) * 116.0, zz, -float(edge), rng)
    # All windows render in three MultiMesh batches to preserve WebGL performance.
    _window_batch(_windows_dark, "#42575d")
    _window_batch(_windows_warm, "#ac9c80")
    _window_batch(_windows_side, "#5b6f70", 0.83)