extends Node3D
class_name CityBuilder

# All geometry is local to the Godot project (no runtime CDN).
# V0.3 art is a material-and-lighting blockout, not final rigged/photoreal assets.
var lamps: Array[OmniLight3D] = []
var windows: Array[StandardMaterial3D] = []
var npc_root: Node3D
var npc_figures: Array[Node3D] = []
var all_materials: Dictionary = {}

func _color(hex: String, roughness: float = 0.80, metal: float = 0.0) -> StandardMaterial3D:
    var key := "%s/%s/%s" % [hex, roughness, metal]
    if all_materials.has(key):
        return all_materials[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = roughness
    m.metallic = metal
    all_materials[key] = m
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, shadow: bool = true) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    if not shadow:
        n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(n)
    return n

func _sphere(parent: Node3D, pos: Vector3, scale_by: Vector3, mat: Material) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 12
    mesh.rings = 6
    var m := MeshInstance3D.new()
    m.mesh = mesh
    m.material_override = mat
    m.position = pos
    m.scale = scale_by
    parent.add_child(m)

func _collision_box(parent: Node3D, center: Vector3, dimensions: Vector3) -> void:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.position = center
    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = dimensions
    col.shape = box
    body.add_child(col)
    parent.add_child(body)

func _label(parent: Node3D, title: String, pos: Vector3, size: int = 45, color: Color = Color.WHITE) -> void:
    var sign := Label3D.new()
    sign.text = title
    sign.font_size = size
    sign.pixel_size = 0.008
    sign.modulate = color
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.no_depth_test = false
    sign.position = pos
    sign.outline_size = 4
    parent.add_child(sign)

func _ready() -> void:
    create_city()

func create_city() -> void:
    _ground()
    _roads()
    _building("APARTMENTS", Vector3(-28, 0, 13), Vector3(21, 18, 18), "#b3b7b4", "#758a83", 4, true)
    _building("AOI MART", Vector3(-28, 0, -14), Vector3(21, 10, 17), "#c7b99c", "#4c796f", 2, true)
    _building("KAWA COFFEE", Vector3(28, 0, -14), Vector3(20, 13, 17), "#b6aaa1", "#9c6558", 3, false)
    _building("SLOW LIVING", Vector3(28, 0, 15), Vector3(20, 12, 19), "#b2aca2", "#7d8c79", 3, false)
    _building("MIDORI STUDIO", Vector3(-51, 0, -52), Vector3(29, 27, 24), "#909a9d", "#334653", 6, true)
    _building("KITA OFFICE", Vector3(51, 0, -52), Vector3(27, 29, 24), "#7b898c", "#505e67", 6, false)
    _building("HIGASHI HOTEL", Vector3(-49, 0, 50), Vector3(27, 32, 24), "#9b9a97", "#786a5a", 7, true)
    _building("MOMI COURT", Vector3(51, 0, 50), Vector3(29, 22, 25), "#a09b91", "#536f6b", 5, false)
    _park_and_props()
    _people()

func _ground() -> void:
    _box(self, Vector3(0, -0.36, 0), Vector3(180, 0.6, 180), _color("#8a9180"))
    _collision_box(self, Vector3(0, -0.10, 0), Vector3(180, 0.2, 180))

func _roads() -> void:
    var road := _color("#353c44", 0.99)
    var walk := _color("#c2c0b6", 0.99)
    var curb := _color("#8e9994", 0.99)
    var stripe := _color("#deddd5", 0.95)
    _box(self, Vector3(0, 0.005, 0), Vector3(13, 0.04, 177), road, false)
    _box(self, Vector3(0, 0.014, -32), Vector3(177, 0.04, 13), road, false)
    for side in [-1, 1]:
        _box(self, Vector3(side * 9.0, 0.035, 0), Vector3(5, 0.08, 177), walk, false)
        _box(self, Vector3(side * 6.65, 0.056, 0), Vector3(0.24, 0.10, 177), curb, false)
        _box(self, Vector3(0, 0.035, -32 + side * 9.0), Vector3(177, 0.08, 5), walk, false)
        _box(self, Vector3(0, 0.056, -32 + side * 6.65), Vector3(177, 0.10, 0.24), curb, false)
    for z in range(-84, 84, 8):
        if z < -39 or z > -25:
            _box(self, Vector3(0, 0.05, z), Vector3(0.19, 0.005, 3.6), stripe, false)
    for x in range(-84, 84, 8):
        if x < -8 or x > 8:
            _box(self, Vector3(x, 0.05, -32), Vector3(3.6, 0.005, 0.19), stripe, false)
    for x in range(-6, 7, 2):
        _box(self, Vector3(x, 0.073, -23.0), Vector3(1.0, 0.006, 3.5), stripe, false)
        _box(self, Vector3(x, 0.073, -41.0), Vector3(1.0, 0.006, 3.5), stripe, false)
    for z in range(-37, -26, 2):
        _box(self, Vector3(-9.2, 0.073, z), Vector3(3.2, 0.006, 1.0), stripe, false)
        _box(self, Vector3(9.2, 0.073, z), Vector3(3.2, 0.006, 1.0), stripe, false)

func _building(title: String, origin: Vector3, size: Vector3, facade: String, accent: String, floors: int, front_right: bool) -> void:
    var n := Node3D.new()
    n.name = title
    n.position = origin
    add_child(n)
    var wall := _color(facade)
    var trim := _color(accent)
    var glass := _color("#42616c", 0.14, 0.27)
    var dark := _color("#2c3e47", 0.30, 0.23)
    var metal := _color("#899898", 0.39, 0.58)
    var roof := _color("#454b4b")
    var w: float = size.x
    var h: float = size.y
    var d: float = size.z
    _box(n, Vector3(0, h / 2.0, 0), Vector3(w, h, d), wall)
    _box(n, Vector3(0, h + 0.17, 0), Vector3(w + 0.75, 0.34, d + 0.7), roof)
    _box(n, Vector3(0, 0.7, 0), Vector3(w + 0.4, 1.4, d + 0.45), trim)
    # Storefront faces the road, with framed window bays, door, and awning.
    var side: float = 1.0 if front_right else -1.0
    var face_x: float = side * (w / 2.0 + 0.04)
    for i in range(-2, 3):
        var z: float = float(i) * d * 0.16
        _box(n, Vector3(face_x + side * 0.08, 2.25, z), Vector3(0.07, 2.65, d * 0.127), glass, false)
        _box(n, Vector3(face_x + side * 0.13, 3.7, z), Vector3(0.12, 0.13, d * 0.145), metal)
    _box(n, Vector3(face_x + side * 0.17, 3.9, 0), Vector3(1.85, 0.20, d * 0.85), trim)
    _box(n, Vector3(face_x + side * 0.32, 3.79, 0), Vector3(2.2, 0.18, d * 0.72), _color("#dfd4b7"))
    _label(n, title, Vector3(face_x + side * 0.36, 5.3, 0), 38, Color("#f7efe0"))
    # Windows with top/bottom edging and slim intermediate mullions.
    var rows: int = maxi(1, floors - 1)
    for k in range(rows):
        var y: float = 6.7 + float(k) * (h - 7.8) / float(maxi(1, rows - 1))
        for col in range(5):
            var z: float = -d * 0.37 + float(col) * (d * 0.185)
            _box(n, Vector3(face_x + side * 0.065, y, z), Vector3(0.10, 1.62, d * 0.112), glass, false)
            _box(n, Vector3(face_x + side * 0.14, y - 0.85, z), Vector3(0.24, 0.13, d * 0.125), _color("#d5d0c5"))
            if col % 2 == 0:
                _box(n, Vector3(face_x + side * 0.125, y, z), Vector3(0.14, 1.63, 0.07), metal)
    # Side façade and AC boxes make the buildings read as inhabited, not plain cubes.
    for col in range(3):
        var xx: float = -w * 0.29 + float(col) * (w * 0.28)
        for k in range(1, rows + 1):
            var y: float = minf(h - 1.3, 3.8 + float(k) * 2.7)
            _box(n, Vector3(xx, y, d / 2.0 + 0.06), Vector3(w * 0.145, 1.5, 0.12), glass, false)
            if k % 2 == 0:
                _box(n, Vector3(xx + 0.8, y - 0.9, d / 2.0 + 0.28), Vector3(0.88, 0.45, 0.5), metal)
    # Ventilation structures and water tank on rooftop.
    _box(n, Vector3(-w * 0.25, h + 0.55, -d * 0.27), Vector3(3.3, 0.88, 2.6), roof)
    _box(n, Vector3(w * 0.25, h + 0.85, d * 0.2), Vector3(2.4, 1.4, 2.4), trim)
    _collision_box(n, Vector3(0, h / 2.0, 0), Vector3(w, h, d))

func _tree(where: Vector3, big: bool = false) -> void:
    var root := Node3D.new()
    root.position = where
    add_child(root)
    var trunk := _color("#665e51")
    var leaf_a := _color("#526d58")
    var leaf_b := _color("#799277")
    var height: float = 4.2 if big else 3.3
    _box(root, Vector3(0, height * 0.45, 0), Vector3(0.37, height * 0.9, 0.37), trunk)
    _sphere(root, Vector3(0, height, 0), Vector3(2.2, 2.3, 2.0) if big else Vector3(1.75, 1.9, 1.65), leaf_a)
    _sphere(root, Vector3(-0.8, height + 0.45, -0.3), Vector3(1.22, 1.25, 1.12), leaf_b)
    _sphere(root, Vector3(0.6, height + 0.28, 0.5), Vector3(1.17, 1.24, 1.16), leaf_a)

func _street_lamp(where: Vector3) -> void:
    var n := Node3D.new()
    n.position = where
    add_child(n)
    var black := _color("#3d464a", 0.4, 0.7)
    _box(n, Vector3(0, 2.95, 0), Vector3(0.12, 5.9, 0.12), black)
    _box(n, Vector3(-0.55, 5.8, 0), Vector3(1.2, 0.13, 0.14), black)
    var bulb := _color("#f3e4c5", 0.22)
    _box(n, Vector3(-1.09, 5.7, 0), Vector3(0.36, 0.15, 0.39), bulb)
    var light := OmniLight3D.new()
    light.position = Vector3(-1.04, 5.46, 0)
    light.light_color = Color("#ffce91")
    light.light_energy = 1.8
    light.omni_range = 10.0
    light.shadow_enabled = false
    n.add_child(light)
    lamps.append(light)

func _bench(where: Vector3) -> void:
    var root := Node3D.new()
    root.position = where
    root.rotation.y = 0.18
    add_child(root)
    var wood := _color("#9a6f50")
    var frame := _color("#40454b", 0.4, 0.7)
    for y in [0.70, 0.84]:
        _box(root, Vector3(0, y, 0), Vector3(2.25, 0.10, 0.58), wood)
    for y in [1.07, 1.34]:
        _box(root, Vector3(0, y, 0.30), Vector3(2.25, 0.14, 0.12), wood)
    for x in [-0.89, 0.89]:
        _box(root, Vector3(x, 0.40, 0), Vector3(0.13, 0.70, 0.13), frame)

func _park_and_props() -> void:
    # Small square by the station, sidewalk planters, bus stop and street furniture.
    var green := _color("#62775e")
    var concrete := _color("#9c9991")
    var black := _color("#364751")
    _box(self, Vector3(-23, 0.045, 49), Vector3(20, 0.1, 24), green, false)
    for p in [Vector3(-32, 0, 44), Vector3(-17, 0, 45), Vector3(-29, 0, 54), Vector3(-16, 0, 56)]:
        _tree(p, true)
    for z in [-70, -50, 0, 25, 58, 76]:
        _tree(Vector3(-11, 0, z))
        _tree(Vector3(11, 0, z))
    for z in [-58, -12, 20, 58]:
        _street_lamp(Vector3(-7.65, 0.12, z))
        _street_lamp(Vector3(7.65, 0.12, z))
    _bench(Vector3(-16, 0.12, 50))
    _bench(Vector3(-19, 0.12, 58))
    _box(self, Vector3(-12.6, 0.14, -18), Vector3(1.4, 0.28, 4.5), concrete)
    _box(self, Vector3(-12.6, 2.50, -18), Vector3(0.09, 4.5, 0.09), black)
    _box(self, Vector3(-12.6, 4.72, -18), Vector3(3.3, 0.12, 1.4), black)
    _label(self, "BUS 01", Vector3(-12.6, 3.45, -18), 33, Color("#f0f1e9"))
    # Vending machine and bicycle-like street fixtures.
    _box(self, Vector3(12, 1.12, 3), Vector3(1.3, 2.2, 1.05), _color("#d7dcd4"))
    _box(self, Vector3(12, 1.35, 3.54), Vector3(1.12, 1.45, 0.055), _color("#487b90", 0.28))
    _label(self, "DRINKS", Vector3(12, 2.1, 3.67), 18)
    for z in [12.0, 14.4, 16.8]:
        _box(self, Vector3(-13.2, 0.42, z), Vector3(1.25, 0.86, 0.8), _color("#727d75"))
        _sphere(self, Vector3(-13.2, 0.88, z), Vector3(0.72, 0.64, 0.6), _color("#658265"))

func _people() -> void:
    npc_root = Node3D.new()
    npc_root.name = "AmbientResidents"
    add_child(npc_root)
    var shirts: Array[String] = ["#b5937c", "#738c99", "#ac9e90", "#718a7b", "#7d7c95", "#b68b7b"]
    var spots: Array[Vector3] = [Vector3(-10, 0, -15), Vector3(-9, 0, 16), Vector3(10, 0, -10), Vector3(8, 0, 24), Vector3(-11, 0, -55), Vector3(11, 0, 55)]
    for i in range(spots.size()):
        var npc := Node3D.new()
        npc.position = spots[i]
        npc.set_meta("base", spots[i])
        npc.set_meta("offset", float(i) * 1.71)
        npc_root.add_child(npc)
        _box(npc, Vector3(0, 1.11, 0), Vector3(0.68, 1.04, 0.36), _color(shirts[i]))
        _sphere(npc, Vector3(0, 1.9, 0), Vector3(0.25, 0.29, 0.25), _color("#c5aa94"))
        _box(npc, Vector3(-0.17, 0.38, 0), Vector3(0.22, 0.76, 0.23), _color("#4c515a"))
        _box(npc, Vector3(0.17, 0.38, 0), Vector3(0.22, 0.76, 0.23), _color("#4c515a"))
        npc_figures.append(npc)

func update_ambience(daylight: float, elapsed: float) -> void:
    for light in lamps:
        light.visible = daylight < 0.47
        light.light_energy = lerpf(2.7, 0.0, daylight)
    var hour: int = int(WorldClock.snapshot()["hour"])
    for npc in npc_figures:
        # Day schedule: shops active in morning/evening; fewer people after midnight.
        var idx: int = npc_figures.find(npc)
        npc.visible = (hour >= 6 and hour <= 23) or idx == 0
        var base: Vector3 = npc.get_meta("base")
        var phase: float = float(npc.get_meta("offset"))
        npc.position = base + Vector3(sin(elapsed * 0.20 + phase) * 2.4, 0, cos(elapsed * 0.20 + phase) * 1.0)
        npc.rotation.y = sin(elapsed * 0.20 + phase)