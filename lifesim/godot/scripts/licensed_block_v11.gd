extends Node3D
class_name LicensedBlockV11

# Small walkable neighborhood assembled from licensed Kenney CC0 glTF scenes.
# Not a reconstruction of a specific real city or a commercial game's map.
const MODEL_DIR: String = "res://art/third_party/kenney/"
var model_count: int = 0
var building_count: int = 0

func _ready() -> void:
    name = "V11LicensedNeighborhood"
    _place("city-kit-suburban", "building-type-a", Vector3(-24.5, 0, -57), 12.2, 0.0, true)
    _place("city-kit-suburban", "building-type-g", Vector3(24.5, 0, -57), 13.5, PI, true)
    _place("city-kit-suburban", "building-type-c", Vector3(-24.5, 0, -75), 12.0, 0.0, true)
    _place("city-kit-suburban", "building-type-l", Vector3(24.5, 0, -75), 11.1, PI, true)
    _place("city-kit-commercial", "building-k", Vector3(-53, 0, -77), 16.0, PI * .5, true)
    _place("city-kit-commercial", "building-g", Vector3(53, 0, -77), 14.4, -PI * .5, true)
    for z in [-60.0, -73.0]:
        _place("city-kit-suburban", "planter", Vector3(-11.5, .05, z), 0.55)
        _place("city-kit-suburban", "planter", Vector3(11.5, .05, z+2.0), 0.55)
    _place("city-kit-roads", "light-square", Vector3(10.8, .08, -68), 5.0)
    _place("city-kit-roads", "light-curved", Vector3(-10.8, .08, -55), 5.0, PI)
    _place("city-kit-roads", "road-sign-object-stop", Vector3(-10.7, .05, -41), 2.0)
    _place("city-kit-roads", "dumpster", Vector3(37.0, .05, -80), 1.30, -PI/2)

func _compute_bounds(root_node: Node3D) -> AABB:
    var stack: Array[Node] = [root_node]
    var out := AABB(Vector3.ZERO, Vector3.ZERO)
    var have: bool = false
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mesh := node as MeshInstance3D
            if mesh.mesh != null:
                var aabb: AABB = mesh.get_aabb()
                var xf: Transform3D = root_node.global_transform.affine_inverse() * mesh.global_transform
                for xi in [0, 1]:
                    for yi in [0, 1]:
                        for zi in [0, 1]:
                            var p: Vector3 = xf * (aabb.position + Vector3(aabb.size.x * xi, aabb.size.y * yi, aabb.size.z * zi))
                            if not have:
                                out = AABB(p, Vector3.ZERO)
                                have = true
                            else:
                                out = out.expand(p)
        for child in node.get_children():
            stack.append(child)
    return out if have else AABB(Vector3.ZERO, Vector3.ONE)

func _place(pack: String, name_part: String, at: Vector3, height: float, yaw: float = 0.0, building: bool = false) -> void:
    var path: String = MODEL_DIR + pack + "/" + name_part + ".glb"
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        push_error("V0.11 licensed block asset missing: " + path)
        return
    var pivot := Node3D.new()
    pivot.name = "Licensed_%s_%02d" % [name_part, model_count]
    pivot.position = at
    pivot.rotation.y = yaw
    pivot.set_meta("license", "CC0-1.0 Kenney")
    add_child(pivot)
    var model := packed.instantiate() as Node3D
    pivot.add_child(model)
    var b: AABB = _compute_bounds(model)
    var factor: float = height / maxf(b.size.y, .05)
    model.scale = Vector3.ONE * factor
    model.position = -(b.position + Vector3(b.size.x * .5, b.position.y * 0, b.size.z * .5)) * factor
    model.position.y = -b.position.y * factor
    model_count += 1
    if building:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.position = Vector3(0, height * .5, 0)
        var shape := BoxShape3D.new()
        shape.size = Vector3(clampf(b.size.x * factor * .82, 4.0, 20.0), height, clampf(b.size.z * factor * .82, 4.0, 16.0))
        var collision := CollisionShape3D.new()
        collision.shape = shape
        body.add_child(collision)
        pivot.add_child(body)
        building_count += 1