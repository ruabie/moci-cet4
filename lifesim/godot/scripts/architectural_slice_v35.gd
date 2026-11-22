extends Node3D
class_name ArchitecturalSliceV35

# An opt-in, EXTERIOR-ONLY two-lot architecture experiment. It replaces
# V32's box-generated visuals on selected parcels; V32 keeps the same
# solid collision volumes and public entry paths. No new gameplay POIs.
var statistics: Dictionary = {}
var _materials: Dictionary = {}

func _mat(colour: String, rough: float = 0.83) -> StandardMaterial3D:
    var key: String = colour + "|" + str(rough)
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(colour)
    mat.roughness = rough
    _materials[key] = mat
    return mat

func _box(parent: Node3D, pos: Vector3, dims: Vector3, colour: String, rough: float = .82, tilt: float = 0.0) -> void:
    var shape := BoxMesh.new()
    shape.size = dims
    var item := MeshInstance3D.new()
    item.mesh = shape
    item.material_override = _mat(colour, rough)
    item.position = pos
    item.rotation.x = tilt
    parent.add_child(item)
    statistics["mesh_count"] = int(statistics.get("mesh_count", 0)) + 1

func _residence(w: float, d: float, h: float) -> void:
    # Terraced rental house, with three genuinely different silhouette
    # masses, corner circulation shaft, recessed glazing and balconies.
    var brick := "#86756a"
    var mortar := "#aaa297"
    var slab := "#777a76"
    var glazing := "#324c58"
    var metal := "#626d6c"
    _box(self, Vector3(0, 1.55, 0), Vector3(w, 3.10, d), "#8c8176")
    _box(self, Vector3(-.95, 3.1 + (h-3.1)*.5, -1.0),
        Vector3(w-2.3, h-3.1, d-2.3), brick)
    _box(self, Vector3(w*.31, 7.75, -d*.31),
        Vector3(w*.23, 9.30, d*.29), mortar)
    _box(self, Vector3(-2.7, h+.18, -1.0),
        Vector3(w-4.4, .36, d-1.4), slab)
    # Deliberate roof asymmetry, not the old cloned flat box cap.
    _box(self, Vector3(-.95, h+.58, -d*.26),
        Vector3(w-2.0, .23, d*.54), "#535f5d", .76, .13)
    _box(self, Vector3(-.95, h+.58, d*.22),
        Vector3(w-2.0, .23, d*.54), "#535f5d", .76, -.13)
    # A legible ground-floor portico on the EAST-facing pedestrian route.
    for z in [-d*.32, d*.32]:
        _box(self, Vector3(w*.5+.17, 1.54, z),
            Vector3(.22, 3.08, .25), mortar)
    _box(self, Vector3(w*.5+.37, 3.21, 0),
        Vector3(.78, .22, d*.76), slab)
    _box(self, Vector3(w*.5+.06, 1.48, 0),
        Vector3(.07, 2.60, 1.72), glazing, .25)
    # Floor-specific balconies with edge rails; door centre remains clear.
    for floor in range(1, 6):
        var y: float = 3.15 + float(floor)*2.56
        if y >= h-.75:
            continue
        for row in [-1.0, 1.0]:
            var zz: float = row*d*.255
            var front: float = w*.5-1.05
            _box(self, Vector3(front, y-.18, zz),
                Vector3(3.65, .19, d*.33), mortar)
            _box(self, Vector3(front+1.74, y+.34, zz),
                Vector3(.085, 1.04, d*.32), metal)
            _box(self, Vector3(front+1.8, y+.85, zz),
                Vector3(.12, .11, d*.34), metal)
            _box(self, Vector3(front-.06, y+.85, zz),
                Vector3(.09, 2.10, d*.19), glazing, .20)
            statistics["balconies"] = int(statistics.get("balconies", 0)) + 1
    # Narrow, individually framed side windows: different proportions
    # from the library's horizontal reading-hall curtain wall.
    for floor in range(1, 6):
        var cy: float = 4.20 + float(floor-1)*2.58
        if cy >= h-.65:
            continue
        for z in [-d*.30, 0.0, d*.30]:
            _box(self, Vector3(-w*.5+.02, cy, z),
                Vector3(.10, 1.45, 1.10), glazing, .23)
            _box(self, Vector3(-w*.5-.06, cy-.78, z),
                Vector3(.20, .14, 1.29), mortar)
            statistics["window_bays"] = int(statistics.get("window_bays",0)) + 1
    # Roof equipment and offset circulation tower, no advertised interiors.
    _box(self, Vector3(w*.27, h+1.0, -d*.31),
        Vector3(3.1, 1.8, 3.0), metal)
    statistics["profile"] = "setback_terraced_residence"

func _library(w: float, d: float, h: float) -> void:
    # Library: a low horizontal glazed reading hall behind a separated
    # upper wing with a deep projecting west canopy and sandstone fins.
    var stone := "#a69d8f"
    var concrete := "#777e7a"
    var glass := "#344c53"
    var bronze := "#655a4e"
    _box(self, Vector3(0, 1.65, 0), Vector3(w, 3.30, d), stone)
    _box(self, Vector3(2.10, 3.30+(h-3.30)*.5, -.95),
        Vector3(w-4.5, h-3.30, d-2.2), "#979b94")
    # Two very different-height masses break the repeated flat skyline.
    _box(self, Vector3(-w*.35, 5.7, d*.30),
        Vector3(w*.30, 4.80, d*.30), concrete)
    _box(self, Vector3(1.5, h+.16, -.95),
        Vector3(w-3.1, .31, d-1.3), bronze)
    _box(self, Vector3(-w*.5-.74, 3.76, 0),
        Vector3(2.35, .24, d*.90), concrete)
    # WEST facade opens toward the existing route, but remains a solid
    # exterior visual. No door-through or public interior claims.
    _box(self, Vector3(-w*.5-.025, 1.72, 0),
        Vector3(.10, 2.76, d*.80), glass, .19)
    for i in range(7):
        var zz: float = -d*.39 + float(i)*d*.13
        _box(self, Vector3(-w*.5-.24, 2.13, zz),
            Vector3(.30, 3.56, .20), stone)
        statistics["fins"] = int(statistics.get("fins", 0)) + 1
    # Recessed reading-room strips and deep horizontal sunshades.
    for floor in range(3):
        var y: float = 5.2 + float(floor)*2.9
        if y > h-1.0:
            continue
        _box(self, Vector3(-w*.5+1.08, y, -.85),
            Vector3(.08, 1.58, d*.64), glass, .22)
        _box(self, Vector3(-w*.5+.86, y-.89, -.85),
            Vector3(.58, .21, d*.72), bronze)
        for col in range(5):
            var z: float = -d*.31 + float(col)*d*.155
            _box(self, Vector3(-w*.5+.78, y, z),
                Vector3(.16, 1.73, .11), stone)
            statistics["window_bays"] = int(statistics.get("window_bays",0)) + 1
    # Side reading-hall glazing has long horizontal rhythm.
    for floor in range(2):
        var yy: float = 6.0 + float(floor)*3.15
        for x in [-w*.23, 0.0, w*.23]:
            _box(self, Vector3(x, yy, -d*.5+.02),
                Vector3(w*.19, 1.30, .10), glass, .25)
            _box(self, Vector3(x, yy-.77, -d*.5-.06),
                Vector3(w*.20, .12, .21), concrete)
    # Recessed shared deck is a visually distinct roof, not a playable area.
    _box(self, Vector3(1.5, h+.47, 0),
        Vector3(w*.48, .15, d*.26), stone)
    for xx in [-w*.21, w*.21]:
        _box(self, Vector3(xx, h+.92, d*.26),
            Vector3(.12, .9, d*.23), bronze)
    statistics["profile"] = "horizontal_civic_library"

func build_lot(lot: Dictionary) -> void:
    var id: String = str(lot["id"])
    var w: float = float(lot["w"])
    var d: float = float(lot["d"])
    var h: float = float(lot["h"])
    statistics = {"version": "V0.35", "lot": id, "mesh_count": 0,
        "window_bays": 0, "balconies": 0, "fins": 0,
        "collision_owner": "V32 original solid footprint", "exterior_only": true}
    set_meta("v35_exterior_only", true)
    if id == "west_homes_a":
        _residence(w,d,h)
    elif id == "east_library":
        _library(w,d,h)
    else:
        push_error("V35 is limited to exactly two pilot architectural lots")
