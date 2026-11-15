extends Node3D
class_name CuratedInteriorsV11

# V0.11: Licensed CC0 Kenney furniture + Food Kit, not primitive placeholder boxes.
# These scenes are imported, packaged into the game and work without a live CDN.
const ROOT: String = "res://art/third_party/kenney/"
var placed_assets: int = 0
var collidable_assets: int = 0

func _material(col: Color, rough: float = 0.83, metal: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.roughness = rough
    mat.metallic = metal
    return mat

func _slab(where: Vector3, size: Vector3, mat: Material, block: bool = true) -> void:
    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.mesh.size = size
    mesh.material_override = mat
    mesh.position = where
    add_child(mesh)
    if block:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.position = where
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        add_child(body)

func _shell(theme: String) -> void:
    var living: bool = theme == "home"
    var cafe: bool = theme == "cafe"
    var wall := _material(Color("#ede7da") if living else (Color("#d8c4ae") if cafe else Color("#e9e9df")))
    var floor_mat := _material(Color("#ab9278") if living else (Color("#92765b") if cafe else Color("#c5c1b5")), 0.70)
    var metal := _material(Color("#53646a"), 0.38, 0.42)
    var glass := _material(Color(0.53, 0.67, 0.70, 0.19), 0.08)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    _slab(Vector3(0, -0.14, 0), Vector3(14, 0.26, 14), floor_mat)
    _slab(Vector3(-7.05, 2.7, 0), Vector3(0.16, 5.4, 14), wall)
    _slab(Vector3(7.05, 2.7, 0), Vector3(0.16, 5.4, 14), wall)
    _slab(Vector3(0, 2.7, -7.05), Vector3(14, 5.4, 0.16), wall)
    # The facade is an actual opening (2.4m door) flanked by glazed panes.
    _slab(Vector3(-4.0, 2.7, 7.05), Vector3(6, 5.4, 0.12), glass, false)
    _slab(Vector3(4.0, 2.7, 7.05), Vector3(6, 5.4, 0.12), glass, false)
    _slab(Vector3(-1.2, 2.8, 7.05), Vector3(.08, 5.0, .16), metal, false)
    _slab(Vector3(1.2, 2.8, 7.05), Vector3(.08, 5.0, .16), metal, false)
    _slab(Vector3(0, 5.27, 7.05), Vector3(14, .18, .16), wall)
    # No oversized ceiling directly above the 3rd-person camera; perimeter coves only.
    for x in [-6.8, 6.8]:
        _slab(Vector3(x, 5.32, 0), Vector3(.38, .22, 14), wall, false)
    for z in [-6.8, 6.8]:
        _slab(Vector3(0, 5.32, z), Vector3(14, .22, .38), wall, false)
    # Enclosed roof: no exterior skyline visible through the room ceiling.
    var ceiling := _material(Color("#e5dfd3") if cafe else Color("#e9e7de"), .92)
    ceiling.cull_mode = BaseMaterial3D.CULL_DISABLED
    _slab(Vector3(0, 5.49, 0), Vector3(14.1, .24, 14.1), ceiling, false)
    for x in [-3.6, 3.6]:
        for z in [-3.2, 3.3]:
            var light := OmniLight3D.new()
            light.position = Vector3(x, 4.78, z)
            light.light_color = Color("#ffdeb4") if cafe or living else Color("#f4f8f6")
            light.light_energy = 1.30
            light.omni_range = 7.0
            light.shadow_enabled = false
            add_child(light)

func _bounds(node: Node3D, root: Node3D) -> AABB:
    var stack: Array[Node] = [node]
    var have: bool = false
    var out := AABB(Vector3.ZERO, Vector3.ONE)
    while not stack.is_empty():
        var current: Node = stack.pop_back()
        if current is MeshInstance3D:
            var mi := current as MeshInstance3D
            if mi.mesh != null:
                var aabb: AABB = mi.get_aabb()
                var xform: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
                var corners: Array[Vector3] = []
                for ix in [0, 1]:
                    for iy in [0, 1]:
                        for iz in [0, 1]:
                            corners.append(xform * (aabb.position + aabb.size * Vector3(ix, iy, iz)))
                for point in corners:
                    if not have:
                        out = AABB(point, Vector3.ZERO)
                        have = true
                    else:
                        out = out.expand(point)
        for child in current.get_children():
            stack.append(child)
    return out if have else AABB(Vector3.ZERO, Vector3.ONE)

func _prop(pack: String, model_name: String, where: Vector3, desired_height: float, yaw: float = 0.0, solid: bool = false) -> Node3D:
    var path: String = ROOT + pack + "/" + model_name + ".glb"
    var loaded: PackedScene = load(path) as PackedScene
    if loaded == null:
        push_error("Missing licensed interior asset: " + path)
        return null
    var pivot := Node3D.new()
    pivot.name = "Kit_%s_%03d" % [model_name, placed_assets]
    pivot.position = where
    pivot.rotation.y = yaw
    pivot.set_meta("source", "Hidencod/tge-assets; Kenney; CC0-1.0")
    add_child(pivot)
    var scene: Node3D = loaded.instantiate() as Node3D
    if scene == null:
        push_error("Unable to instantiate asset " + path)
        return pivot
    pivot.add_child(scene)
    var b: AABB = _bounds(scene, scene)
    var factor: float = desired_height / maxf(b.size.y, 0.05)
    scene.scale = Vector3.ONE * factor
    scene.position = Vector3(-b.position.x - b.size.x * .5, -b.position.y, -b.position.z - b.size.z * .5) * factor
    placed_assets += 1
    if solid:
        var body := StaticBody3D.new()
        body.name = "FurnitureCollision"
        body.collision_layer = 1
        body.position = Vector3(0, desired_height * .47, 0)
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(clampf(b.size.x * factor * .78, .35, 3.8), maxf(.35, desired_height * .90), clampf(b.size.z * factor * .78, .35, 3.8))
        col.shape = shape
        body.add_child(col)
        pivot.add_child(body)
        collidable_assets += 1
    return pivot

func build_shop(place: String) -> void:
    var cafe: bool = place == "咖啡馆"
    _shell("cafe" if cafe else "mart")
    if cafe:
        _prop("furniture-kit", "kitchenbar", Vector3(-2.7, .04, -4.65), 1.20, 0, true)
        _prop("furniture-kit", "kitchencoffeemachine", Vector3(-3.45, 1.27, -4.87), .55)
        _prop("furniture-kit", "kitchensink", Vector3(-5.8, .04, -5.1), .95)
        _prop("furniture-kit", "kitchenfridgesmall", Vector3(-5.8, .04, -3.1), 1.65, PI, true)
        _prop("furniture-kit", "bookcaseopen", Vector3(5.55, .04, -5.15), 2.60, PI / 2, true)
        _prop("furniture-kit", "plantsmall1", Vector3(5.30, 1.65, -5.5), .65)
        for x in [-4.75, 4.4]:
            for z in [.0, 3.8]:
                _prop("furniture-kit", "tableround", Vector3(x, .04, z), .76, 0, true)
                _prop("furniture-kit", "chaircushion", Vector3(x-.95, .04, z), .87, PI/2)
                _prop("furniture-kit", "chair", Vector3(x+.95, .04, z), .88, -PI/2)
        _prop("furniture-kit", "loungesofa", Vector3(-5.55, .04, 5.65), 1.05, -PI / 2, true)
        _prop("furniture-kit", "rugrectangle", Vector3(-4.95, .045, 4.95), .035)
        _prop("furniture-kit", "pottedplant", Vector3(5.9, .04, 5.65), 1.70)
        _prop("furniture-kit", "lamproundfloor", Vector3(5.55, .04, 1.45), 1.62)
        for n in range(4):
            var food_names: Array[String] = ["croissant", "cake", "donut", "cup-coffee"]
            _prop("food-kit", food_names[n], Vector3(-4.25 + n * .55, 1.26, -4.1), .17)
    else:
        _prop("furniture-kit", "kitchenbar", Vector3(-5.1, .04, 4.65), 1.16, PI / 2, true)
        _prop("furniture-kit", "computerkeyboard", Vector3(-5.25, 1.25, 4.55), .07)
        _prop("furniture-kit", "computerscreen", Vector3(-5.8, 1.22, 4.10), .55, PI)
        for x in [-4.65, 4.45]:
            for z in [-3.70, 0.30]:
                _prop("furniture-kit", "bookcaseopen", Vector3(x, .04, z), 2.12, PI/2, true)
        _prop("furniture-kit", "kitchenfridgelarge", Vector3(5.50, .04, -5.25), 2.55, PI, true)
        _prop("furniture-kit", "kitchenmicrowave", Vector3(-6.10, 1.45, -5.5), .44)
        _prop("furniture-kit", "trashcan", Vector3(5.8, .04, 5.85), .81)
        for i in range(12):
            var food_names: Array[String] = ["soda-can", "soda-bottle", "sandwich", "bread", "burger", "carton-small"]
            var x: float = [-4.65, 4.45][i % 2]
            var z: float = [-4.1, .15][int(i / 2) % 2]
            var y: float = 1.0 + float(int(i / 4)) * .45
            _prop("food-kit", food_names[i % 6], Vector3(x, y, z), .30)

func build_home(owned: Array) -> void:
    _shell("home")
    _prop("furniture-kit", "beddouble", Vector3(-4.5, .04, -4.15), 0.85, PI / 2, true)
    _prop("furniture-kit", "desk", Vector3(3.9, .04, -4.85), 1.0, PI, true)
    _prop("furniture-kit", "chairdesk", Vector3(3.65, .04, -3.15), .92, 0)
    _prop("furniture-kit", "laptop", Vector3(3.9, 1.04, -4.85), .30, PI)
    _prop("furniture-kit", "loungesofa", Vector3(-4.9, .04, 3.35), 1.08, PI / 2, true)
    _prop("furniture-kit", "tablecoffee", Vector3(-3.0, .04, 3.2), .50)
    _prop("furniture-kit", "bookcaseopenlow", Vector3(5.80, .04, 2.7), 1.25, -PI / 2)
    _prop("furniture-kit", "kitchenfridgesmall", Vector3(5.95, .04, 5.55), 1.67, PI)
    _prop("furniture-kit", "plantsmall2", Vector3(-6.1, .04, 5.65), 1.27)
    _prop("furniture-kit", "rugrounded", Vector3(-3.6, .05, 2.4), .033)
    _prop("furniture-kit", "lamproundfloor", Vector3(-6.00, .04, .80), 1.58)
    for id in owned:
        add_purchased_item(str(id))

func add_purchased_item(item: String) -> void:
    match item:
        "desk_lamp":
            _prop("furniture-kit", "lamproundtable", Vector3(4.75, 1.03, -4.85), .52)
        "soft_rug":
            _prop("furniture-kit", "rugrectangle", Vector3(-1.7, .05, -3.6), .035)
        "green_plant":
            _prop("furniture-kit", "pottedplant", Vector3(5.85, .04, 4.55), 1.74)
        "bookshelf":
            _prop("furniture-kit", "bookcaseclosedwide", Vector3(5.80, .04, 0.0), 2.23, PI / 2, true)
        "computer":
            _prop("furniture-kit", "computerscreen", Vector3(4.0, 1.05, -4.6), .48, PI)
            _prop("furniture-kit", "computerkeyboard", Vector3(3.9, 1.05, -4.0), .08)