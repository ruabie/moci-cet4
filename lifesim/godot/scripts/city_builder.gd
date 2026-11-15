extends Node3D
class_name CityBuilder

# All geometry is local to the Godot project (no runtime CDN).
# V0.5.1 authored GLBs are a stylized art milestone, not photoreal-quality validation.
var lamps: Array[OmniLight3D] = []
var windows: Array[StandardMaterial3D] = []
var localized_font: Font
var npc_root: Node3D
var npc_figures: Array[Node3D] = []
var npc_rigs: Array[Skeleton3D] = []
var all_materials: Dictionary = {}

func _color(hex: String, roughness: float = 0.80, metal: float = 0.0) -> StandardMaterial3D:
    var key := "%s/%s/%s" % [hex, roughness, metal]
    if all_materials.has(key):
        return all_materials[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = roughness
    m.metallic = metal
    var texture_path := ""
    if hex == "#353c44":
        texture_path = "res://art/textures/asphalt.png"
    elif hex in ["#c2c0b6", "#9c9991", "#aaa99f"]:
        texture_path = "res://art/textures/concrete.png"
    elif hex in ["#c9b4a1", "#d1c4b2", "#bbab9a", "#9daea2", "#9aa7a6", "#8ea2a6", "#bca694", "#a5afa2"]:
        texture_path = "res://art/textures/stucco.png"
    if texture_path != "":
        m.albedo_texture = load(texture_path)
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(0.24, 0.24, 0.24)
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
    if localized_font != null:
        sign.font = localized_font
    sign.font_size = size
    sign.pixel_size = 0.008
    sign.modulate = color
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.no_depth_test = false
    sign.position = pos
    sign.outline_size = 4
    parent.add_child(sign)

func _ready() -> void:
    var font_path := "res://art/fonts/NotoSansCJKsc-Regular.otf"
    if ResourceLoader.exists(font_path):
        localized_font = load(font_path) as Font
    else:
        var system_font := SystemFont.new()
        system_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC"])
        localized_font = system_font
    create_city()

func create_city() -> void:
    _ground()
    _roads()
    # V0.7 integrated street: no opaque generic building behind an overlay storefront.
    _integrated_building("公寓", "apartment", Vector3(-28, 0, 13), Vector3(21, 18, 18), true, "青川公寓")
    _integrated_building("便利店", "mart", Vector3(-28, 0, -14), Vector3(21, 10, 17), true, "AOI MART  ·  24H")
    _integrated_building("咖啡馆", "coffee", Vector3(28, 0, -14), Vector3(20, 13, 17), false, "KAWA COFFEE")
    _integrated_building("生活商店", "living", Vector3(28, 0, 15), Vector3(20, 12, 19), false, "SLOW LIVING")
    _building("MIDORI STUDIO", Vector3(-51, 0, -52), Vector3(29, 27, 24), "#9aa7a6", "#334653", 6, true)
    _building("KITA OFFICE", Vector3(51, 0, -52), Vector3(27, 29, 24), "#8ea2a6", "#505e67", 6, false)
    _building("HIGASHI HOTEL", Vector3(-49, 0, 50), Vector3(27, 32, 24), "#bca694", "#786a5a", 7, true)
    _building("MOMI COURT", Vector3(51, 0, 50), Vector3(29, 22, 25), "#a5afa2", "#536f6b", 5, false)
    _park_and_props()
    _life_props()
    _people()
    _detail_pass()
    _integrated_forecourts()
    var legal_block := LicensedBlockV11.new()
    add_child(legal_block)

func _ground() -> void:
    _box(self, Vector3(0, -0.36, 0), Vector3(180, 0.6, 180), _color("#66736a"))
    _collision_box(self, Vector3(0, -0.10, 0), Vector3(180, 0.2, 180))

func _roads() -> void:
    var road := _color("#303a40", 0.99)
    var walk := _color("#666e69", 0.99)
    var curb := _color("#515a57", 0.99)
    var stripe := _color("#bdc4bc", 0.95)
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
    # Original glTF foliage with tapered limbs and individually shaped leaves.
    # Three variants break the previous repeated sphere-canopy silhouette.
    var hash_value: int = absi(roundi(where.x * 19.0 + where.z * 7.0))
    var variants: Array[String] = ["zelkova_full", "zelkova_narrow", "katsura_warm"]
    var species: String = variants[hash_value % variants.size()]
    var path: String = "res://art/vegetation/%s.glb" % species
    var resource: PackedScene = load(path) as PackedScene
    if resource == null:
        push_error("V0.10 vegetation asset not imported: " + path)
        return
    var root := Node3D.new()
    root.name = "V10StreetscapeTree_%s_%d_%d" % [species, roundi(where.x * 10.0), roundi(where.z * 10.0)]
    root.position = where
    root.rotation.y = float(hash_value % 13) * 0.31
    var random_scale: float = 1.02 + float(hash_value % 5) * 0.035
    root.scale = Vector3.ONE * (random_scale if big else random_scale * .81)
    var model: Node3D = resource.instantiate() as Node3D
    root.add_child(model)
    add_child(root)

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
    _box(self, Vector3(-12.6, 0.14, -49), Vector3(1.4, 0.28, 4.5), concrete)
    _box(self, Vector3(-12.6, 2.50, -49), Vector3(0.09, 4.5, 0.09), black)
    _box(self, Vector3(-12.6, 4.72, -49), Vector3(3.3, 0.12, 1.4), black)
    _label(self, "BUS 01", Vector3(-12.6, 3.45, -49), 33, Color("#f0f1e9"))
    # Vending machine and bicycle-like street fixtures.
    _box(self, Vector3(12, 1.12, 3), Vector3(1.3, 2.2, 1.05), _color("#d7dcd4"))
    _box(self, Vector3(12, 1.35, 3.54), Vector3(1.12, 1.45, 0.055), _color("#487b90", 0.28))
    _label(self, "DRINKS", Vector3(12, 2.1, 3.67), 18)
    for z in [12.0, 14.4, 16.8]:
        _box(self, Vector3(-13.2, 0.42, z), Vector3(1.25, 0.86, 0.8), _color("#727d75"))
        var shrub: PackedScene = load("res://art/vegetation/street_shrub.glb") as PackedScene
        if shrub != null:
            var leaves: Node3D = shrub.instantiate() as Node3D
            leaves.name = "V10ParkVegetation"
            leaves.position = Vector3(-13.2, .84, z)
            leaves.scale = Vector3.ONE * .65
            add_child(leaves)

func _life_props() -> void:
    # Visible affordances make errands legible without requiring a minimap.
    var timber := _color("#82644b")
    var ink := _color("#314f48")
    var poster := _color("#f3e0b7")
    # Park bulletin board: the town's daily objectives live here.
    var board := Node3D.new()
    board.name = "LifeQuestBoard"
    board.position = Vector3(-18, 0.13, 55)
    add_child(board)
    _box(board, Vector3(-1.1, 1.05, 0), Vector3(0.13, 2.1, 0.13), timber)
    _box(board, Vector3(1.1, 1.05, 0), Vector3(0.13, 2.1, 0.13), timber)
    _box(board, Vector3(0, 2.03, 0), Vector3(3.1, 1.75, 0.18), ink)
    _box(board, Vector3(0, 2.04, -0.12), Vector3(2.82, 1.47, 0.04), poster, false)
    _label(board, "TODAY  /  今日委托", Vector3(0, 2.32, -0.27), 30, Color("#29463c"))
    _label(board, "E 查看目标", Vector3(0, 1.81, -0.27), 24, Color("#486b57"))
    # Parcel locker opposite the park — delivery requires actually walking here.
    var parcel := Node3D.new()
    parcel.name = "RiversideParcelLocker"
    parcel.position = Vector3(12, 0.12, 47)
    add_child(parcel)
    _box(parcel, Vector3(0, 1.15, 0), Vector3(2.2, 2.3, 1.0), _color("#718c8e"))
    for x in [-0.58, 0.58]:
        for y in [0.66, 1.26, 1.86]:
            _box(parcel, Vector3(x, y, -0.54), Vector3(0.98, 0.51, 0.04), _color("#d3d7cb"), false)
    _label(parcel, "PARCEL  /  河畔取件", Vector3(0, 2.65, -0.6), 22, Color("#e9e5d2"))
    # Three camera-friendly, distinct spots across the walkable district.
    var signs: Array = [
        ["RIVER / P 摄影", Vector3(-18, 0.13, 47)],
        ["CROSSING / P 摄影", Vector3(0, 0.13, -23)],
        ["SHOP WINDOW / P 摄影", Vector3(13, 0.13, 16)]
    ]
    for idx in range(signs.size()):
        var item: Array = signs[idx]
        var post := Node3D.new()
        post.name = "PhotoMarker_%d" % idx
        post.position = item[1]
        add_child(post)
        _box(post, Vector3(0, 0.95, 0), Vector3(0.10, 1.9, 0.10), _color("#565b58"))
        _box(post, Vector3(0, 1.93, 0), Vector3(1.05, 0.48, 0.17), _color("#66817b"))
        _label(post, str(item[0]), Vector3(0, 2.37, 0), 21, Color("#f4e5cc"))

func _citizen_ellipsoid(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 12
    mesh.rings = 6
    var inst := MeshInstance3D.new()
    inst.mesh = mesh
    inst.position = pos
    inst.scale = dimensions
    inst.material_override = mat
    parent.add_child(inst)

func _find_resident_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var nested: Skeleton3D = _find_resident_skeleton(child)
        if nested != null:
            return nested
    return null

func _people() -> void:
    npc_root = Node3D.new()
    npc_root.name = "AmbientResidents"
    add_child(npc_root)
    var residents: Array[PackedScene] = [
        load("res://art/characters/resident_olive.glb"),
        load("res://art/characters/resident_sand.glb"),
        load("res://art/characters/commuter_rig.glb")
    ]
    var spots: Array[Vector3] = [Vector3(-10, 0, -15), Vector3(-9, 0, 16), Vector3(10, 0, -10), Vector3(8, 0, 24), Vector3(-11, 0, -55), Vector3(11, 0, 55)]
    for i in range(spots.size()):
        var npc := Node3D.new()
        npc.name = "Citizen_%02d" % i
        npc.position = spots[i]
        npc.set_meta("resident_name", ["小遥", "拓海", "晴子", "阿诚", "美咲", "木村"][i])
        npc.set_meta("base", spots[i])
        npc.set_meta("offset", float(i) * 1.71)
        npc_root.add_child(npc)
        var figure: Node3D = residents[i % residents.size()].instantiate() as Node3D
        figure.name = "ResidentRigModel"
        figure.scale = Vector3.ONE * (0.77 + float(i % 3) * 0.025)
        npc.add_child(figure)
        var skeleton: Skeleton3D = _find_resident_skeleton(figure)
        if skeleton == null or skeleton.find_bone("LeftThigh") < 0:
            push_error("Missing resident Skeleton3D for " + npc.name)
        npc_rigs.append(skeleton)
        npc_figures.append(npc)
        _label(npc, str(npc.get_meta("resident_name")), Vector3(0, 2.6, 0), 28, Color("#e6d4b2"))

func _resident_pose(rig: Skeleton3D, name: String, rotation: float) -> void:
    if rig == null:
        return
    var idx: int = rig.find_bone(name)
    if idx >= 0:
        rig.set_bone_pose_rotation(idx, Quaternion(Vector3.RIGHT, rotation))

func update_ambience(daylight: float, elapsed: float) -> void:
    for light in lamps:
        light.visible = daylight < 0.48
        light.light_energy = lerpf(1.65, 0.0, daylight)
    var hour: int = int(WorldClock.snapshot()["hour"])
    for idx in range(npc_figures.size()):
        var npc: Node3D = npc_figures[idx]
        if hour < 6:
            npc.visible = idx in [0, 3]
        elif hour < 10:
            npc.visible = idx in [0, 1, 3, 5]
        elif hour < 18:
            npc.visible = idx in [0, 1, 2, 3, 4]
        else:
            npc.visible = idx in [0, 1, 2, 4, 5]
        var base: Vector3 = npc.get_meta("base")
        var phase: float = float(npc.get_meta("offset"))
        var t: float = elapsed * 0.24 + phase
        var movement := Vector3(cos(t) * 0.48, 0, -sin(t) * 1.45)
        npc.position = base + Vector3(sin(t) * 2.0, 0, cos(t) * 1.45)
        npc.rotation.y = atan2(-movement.x, -movement.z)
        var stride: float = sin(elapsed * 4.0 + phase) * 0.36
        var rig: Skeleton3D = npc_rigs[idx]
        _resident_pose(rig, "LeftThigh", stride)
        _resident_pose(rig, "RightThigh", -stride)
        _resident_pose(rig, "LeftShin", maxf(0.0, -stride) * .7)
        _resident_pose(rig, "RightShin", maxf(0.0, stride) * .7)
        _resident_pose(rig, "LeftUpperArm", -stride * .68)
        _resident_pose(rig, "RightUpperArm", stride * .68)

func _round_post(parent: Node3D, where: Vector3, height: float, radius: float, color: String) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    var inst := MeshInstance3D.new()
    inst.mesh = mesh
    inst.material_override = _color(color, 0.58, 0.45)
    inst.position = where + Vector3.UP * height * 0.5
    parent.add_child(inst)

func _planter(where: Vector3, lush: bool = false) -> void:
    var root := Node3D.new()
    root.position = where
    add_child(root)
    _box(root, Vector3(0, 0.29, 0), Vector3(1.15, 0.58, 1.05), _color("#90857a"))
    _box(root, Vector3(0, 0.56, 0), Vector3(0.95, 0.05, 0.87), _color("#52483e"))
    var shrub: PackedScene = load("res://art/vegetation/street_shrub.glb") as PackedScene
    if shrub == null:
        push_error("V0.10 street shrub failed to import")
        return
    var copy_count: int = 3 if lush else 2
    for i in range(copy_count):
        var instance: Node3D = shrub.instantiate() as Node3D
        instance.name = "V10LeafyPlanter"
        instance.position = Vector3(-.16 + .21 * float(i), .58, -.12 + .10 * float(i))
        instance.rotation.y = float(i) * 1.65
        instance.scale = Vector3.ONE * (.64 + .12 * float(i % 2))
        root.add_child(instance)

func _bike_rod(root: Node3D, a: Vector3, b: Vector3, material: Material) -> void:
    var bar := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(a.distance_to(b), 0.055, 0.055)
    bar.mesh = mesh
    bar.position = (a + b) * 0.5
    bar.rotation.z = atan2(b.y - a.y, b.x - a.x)
    bar.material_override = material
    root.add_child(bar)

func _parked_bicycle(where: Vector3) -> void:
    var root := Node3D.new()
    root.position = where
    root.rotation.y = 0.10
    add_child(root)
    var metal := _color("#56616a", 0.40, 0.68)
    for x in [-0.67, 0.67]:
        var tire := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.38
        torus.outer_radius = 0.46
        tire.mesh = torus
        tire.material_override = _color("#262a2c", 0.94)
        tire.position = Vector3(x, 0.47, 0)
        tire.rotation.x = PI * 0.5
        root.add_child(tire)
    _bike_rod(root, Vector3(-0.67, 0.47, 0), Vector3(-0.21, 0.96, 0), metal)
    _bike_rod(root, Vector3(-0.21, 0.96, 0), Vector3(0.32, 0.92, 0), metal)
    _bike_rod(root, Vector3(0.32, 0.92, 0), Vector3(-0.08, 0.49, 0), metal)
    _bike_rod(root, Vector3(-0.08, 0.49, 0), Vector3(-0.67, 0.47, 0), metal)
    _bike_rod(root, Vector3(0.32, 0.92, 0), Vector3(0.67, 0.47, 0), metal)
    _bike_rod(root, Vector3(-0.21, 0.96, 0), Vector3(-0.08, 0.49, 0), metal)
    _box(root, Vector3(0, 0.56, 0), Vector3(0.06, 0.59, 0.06), metal)
    _box(root, Vector3(-0.27, 1.10, 0), Vector3(0.44, 0.07, 0.22), _color("#4e4743"))
    _box(root, Vector3(0.64, 1.19, 0), Vector3(0.65, 0.065, 0.08), metal)

func _awning(front: float, z0: float, y: float, width: float, base: String) -> void:
    # Shop canopy with separate canvas stripes and a dark metal frame.
    var side := 1.0 if front > 0 else -1.0
    var strip_mat := _color(base)
    _box(self, Vector3(front + side * 1.0, y, z0), Vector3(1.88, 0.10, width), strip_mat)
    for i in range(9):
        if i % 2 == 0:
            var z: float = z0 - width * 0.5 + width * (float(i) + 0.5) / 9.0
            _box(self, Vector3(front + side * 1.0, y + 0.06, z), Vector3(1.88, 0.025, width / 9.0), _color("#e1d4bc"))
    _box(self, Vector3(front + side * 1.92, y - 0.11, z0), Vector3(0.14, 0.26, width), _color("#5f6262"))

func _detail_pass() -> void:
    # Forecourts and shopfronts establish a walkable rather than empty street edge.
    # V0.7: removed stamped 3m sidewalk blocks. They covered the base concrete
    # with a visible periodic patchwork and intersected shop threshold surfaces.
    # A single seamless walk mesh is provided by _roads() instead.
    for side in [-1.0, 1.0]:
        for z in [-65.0, -18.0, 13.0, 62.0]:
            _planter(Vector3(side * 11.0, 0.10, z))
        for z in [-78.0, -22.0, 38.0, 79.0]:
            _round_post(self, Vector3(side * 6.65, 0.11, z), 0.90, 0.11, "#505d60")
    # No additional shop canopies or floating planters: details are part of the integrated GLB.
    _parked_bicycle(Vector3(-13.3, 0.10, 2.9))
    _parked_bicycle(Vector3(13.8, 0.10, 29.2))
    # Thin building course lines, floor plates, balcony rails and planted terraces.
    var specs := [
        ["MIDORI STUDIO", Vector3(-51, 0, -52), 29.0, 27.0, 24.0, true],
        ["KITA OFFICE", Vector3(51, 0, -52), 27.0, 29.0, 24.0, false],
        ["HIGASHI HOTEL", Vector3(-49, 0, 50), 27.0, 32.0, 24.0, true],
        ["MOMI COURT", Vector3(51, 0, 50), 29.0, 22.0, 25.0, false]
    ]
    for spec in specs:
        var origin: Vector3 = spec[1]
        var w: float = spec[2]
        var h: float = spec[3]
        var d: float = spec[4]
        var s: float = 1.0 if spec[5] else -1.0
        var facade_x: float = origin.x + s * (w * 0.5 + 0.09)
        var edge_color := _color("#777e79")
        for level in range(1, int(h / 3.3)):
            var y := float(level) * 3.25 + 0.4
            _box(self, Vector3(facade_x + s * 0.06, y, origin.z), Vector3(0.20, 0.10, d * 0.94), edge_color)
        for level in range(2, int(h / 3.35)):
            if level % 2 == 0 and h > 14.0:
                var y := float(level) * 3.3
                for q in [-0.27, 0.25]:
                    var z: float = origin.z + float(q) * d
                    _box(self, Vector3(facade_x + s * 0.58, y - 0.88, z), Vector3(1.12, 0.14, d * 0.24), _color("#a4a8a0"))
                    _box(self, Vector3(facade_x + s * 1.07, y - 0.44, z), Vector3(0.09, 0.78, d * 0.24), _color("#657371", 0.38, 0.4))
                    _box(self, Vector3(facade_x + s * 0.58, y - 0.44, z - d * 0.115), Vector3(1.05, 0.08, 0.10), edge_color)
                    _box(self, Vector3(facade_x + s * 0.58, y - 0.44, z + d * 0.115), Vector3(1.05, 0.08, 0.10), edge_color)
    # Railings and landscape at the park, away from collision-critical NPC paths.
    for z in [38.0, 62.0]:
        for x in [-32.5, -28.0, -23.5, -19.0]:
            _round_post(self, Vector3(x, 0.12, z), 0.78, 0.055, "#727d77")
    # The old skyline was 36 identical empty cubes. This compact backdrop uses
    # setbacks and batched facade glazing without colliding with the playable city.
    var backdrop := DistrictBackdropV10.new()
    backdrop.name = "V10DistantUrbanBackdrop"
    add_child(backdrop)

func _integrated_building(title: String, variant: String, origin: Vector3, size: Vector3, front_right: bool, signage: String) -> void:
    # One complete GLB structure per address; local +X faces street.
    var side: float = 1.0 if front_right else -1.0
    var root := Node3D.new()
    root.name = "Authored_%s" % signage.replace(" ", "_")
    root.position = Vector3(origin.x + side * size.x * 0.5, 0.0, origin.z)
    root.rotation.y = 0.0 if front_right else PI
    add_child(root)
    var path: String = "res://art/architecture/v09_coffee_integrated.glb" if variant == "coffee" else "res://art/architecture/v08_%s_integrated.glb" % variant
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        push_error("V0.7 envelope missing: " + path)
        return
    var model: Node3D = packed.instantiate() as Node3D
    model.name = "V09CuratedCafeAndInterior" if variant == "coffee" else "V08TexturedEnvelopeAndInterior"
    root.add_child(model)
    # Collision behind the front reveals; front face itself is not a full opaque slab.
    _collision_box(root, Vector3(-size.x * .5 - .60, size.y * .5, 0),
        Vector3(size.x - 1.2, size.y, size.z - .25))
    if variant == "coffee":
        _label(root, "KAWA 珈琲", Vector3(.80, 4.42, 4.35), 51, Color("#312823"))
        var evening_light := OmniLight3D.new()
        evening_light.name = "CafeWindowWarmth"
        evening_light.position = Vector3(-1.90, 2.57, -0.4)
        evening_light.light_color = Color("#ffdfb0")
        evening_light.light_energy = 0.74
        evening_light.omni_range = 8.0
        evening_light.shadow_enabled = false
        root.add_child(evening_light)
    else:
        _label(root, signage, Vector3(.49, 4.39, 0), 42, Color("#f0e8d6"))

func _integrated_forecourts() -> void:
    # Full threshold pavers meet the storefront: no floating trim modules.
    var paver: Material = _color("#666e69", .99)
    var edge: Material = _color("#5e665e", .98)
    var drain: Material = _color("#3a4747", .62, .45)
    for xcenter in [-15.0, 15.0]:
        for spec in [[-14.0, 15.9], [14.0, 16.0]]:
            var zcenter: float = float(spec[0])
            var width: float = float(spec[1])
            _box(self, Vector3(xcenter, .095, zcenter),
                Vector3(4.9, .055, width), paver, false)
            _box(self, Vector3(xcenter + (2.42 if xcenter < 0 else -2.42), .115, zcenter),
                Vector3(.08, .07, width), edge, false)
            _box(self, Vector3(xcenter + (-1.9 if xcenter < 0 else 1.9), .128, zcenter),
                Vector3(.13, .07, width - .6), drain, false)
    for pos in [Vector3(-13.1,.10,-20.2), Vector3(13.3,.10,-7.0), Vector3(-13.0,.10,20.1)]:
        _round_post(self, pos, .71, .07, "#69716e")