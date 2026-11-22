extends Node3D
class_name UrbanFacadeV36

# One-parcel, source-verified modern urban housing EXTERIOR demonstration.
# Imported original CC0 GLBs, not placeholder boxes in place of missing art.
# Original V32 lot collision / public access continue to be owned by V32.
const ROOT_PATH: String = "res://art/third_party/tevy_v36/"
const ART: Array[String] = [
    "housing-facade-shop",
    "housing-facade-window",
    "housing-facade-balcony"
]

var statistics: Dictionary = {}
var _cache: Dictionary = {}

func _material(hex: String, rough: float = .86) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = rough
    return mat

func _cube(parent: Node3D, size: Vector3, position: Vector3,
        hex: String, rough: float = .86) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _material(hex, rough)
    node.position = position
    parent.add_child(node)
    statistics["original_backing_meshes"] = int(statistics.get("original_backing_meshes",0)) + 1

func _bounds(parent: Node3D) -> AABB:
    # Measure actual imported GLB mesh geometry rather than assuming
    # authored asset pivot is centered or that origin is bottom-left.
    var stack: Array[Node] = [parent]
    var bounds := AABB(Vector3.ZERO, Vector3.ZERO)
    var initialized: bool = false
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mesh_node: MeshInstance3D = node as MeshInstance3D
            if mesh_node.mesh != null:
                var bb: AABB = mesh_node.get_aabb()
                var xf: Transform3D = parent.global_transform.affine_inverse() * mesh_node.global_transform
                for i in [0,1]:
                    for j in [0,1]:
                        for k in [0,1]:
                            var point: Vector3 = xf * (bb.position + Vector3(
                                bb.size.x * float(i), bb.size.y * float(j), bb.size.z * float(k)))
                            if not initialized:
                                bounds = AABB(point,Vector3.ZERO)
                                initialized = true
                            else:
                                bounds = bounds.expand(point)
        for child in node.get_children():
            stack.append(child)
    return bounds if initialized else AABB(Vector3.ZERO, Vector3.ZERO)

func _module(slug: String, height: float, z: float,
        outward_x: float, location: String) -> void:
    var packed: PackedScene = _cache.get(slug) as PackedScene
    if packed == null:
        push_error("V36 verified art module unavailable: " + slug)
        statistics["missing_source_models"] = int(statistics.get("missing_source_models",0))+1
        return
    var holder := Node3D.new()
    holder.name = "VerifiedOriginal_" + location
    holder.position = Vector3(outward_x,height,z)
    holder.rotation.y = PI * .5 # source forward +Z => east +X on the original lot
    add_child(holder)
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        push_error("V36 source must be an instantiable Node3D GLB: " + slug)
        statistics["missing_source_models"] = int(statistics.get("missing_source_models",0))+1
        return
    holder.add_child(model)
    var bb: AABB = _bounds(model)
    if bb.size.x < 4.0 or bb.size.y < 2.5 or bb.size.x > 7.0:
        push_error("V36 unexpected asset dimensions " + slug + " " + str(bb.size))
        statistics["bad_asset_bounds"] = int(statistics.get("bad_asset_bounds",0))+1
        return
    # Do not stretch real 6m modules to fill a 20m old low-poly wall.
    # The remaining setbacks are filled by plain structural side walls.
    model.position = Vector3(-(bb.position.x + bb.size.x*.5),
        -bb.position.y, -(bb.position.z + bb.size.z*.5))
    holder.set_meta("source_asset",slug)
    holder.set_meta("license","CC0-1.0")
    statistics["original_glb_instances"] = int(statistics.get("original_glb_instances",0)) + 1

func build_lot(lot: Dictionary) -> void:
    var lot_id: String = str(lot["id"])
    statistics = {"version":"V0.36","parcel":lot_id,"license":"CC0-1.0",
        "exterior_only":true,"original_glb_instances":0,
        "original_backing_meshes":0,"missing_source_models":0,"bad_asset_bounds":0,
        "visual_floor_count":6,"source_mesh_variants":ART.size(),
        "preserved_v32_collision":true,"preserved_v32_entry_path":true}
    if lot_id != "west_homes_a" or str(lot["door"]) != "east":
        push_error("V36 refuses unrelated parcel or inverted facade orientation")
        return
    for slug in ART:
        var p: String = ROOT_PATH + slug + ".glb"
        var original: PackedScene = load(p) as PackedScene
        if original == null:
            statistics["missing_source_models"] = int(statistics.get("missing_source_models",0))+1
            push_error("V36 requires fixed-SHA original CC0 GLB: " + p)
            return
        _cache[slug] = original
    var w: float = float(lot["w"])
    var d: float = float(lot["d"])
    var h: float = float(lot["h"])
    if absf(w-20.0)>.01 or absf(d-22.0)>.01 or absf(h-19.2)>.01:
        push_error("V36 pilot requires original fixed housing footprint, no silent resize")
        statistics["bad_asset_bounds"] = int(statistics.get("bad_asset_bounds",0))+1
        return
    # Low-detail parts are structural SIDE/REAR ONLY, not false window meshes.
    # Front originals are genuinely modelled windows/AC/laundry/balconies.
    _cube(self,Vector3(18.5,h,20.2),Vector3(-.45,h*.5,0), "#776d68")
    _cube(self,Vector3(19.0,.32,20.7),Vector3(-.45,h+.15,0), "#4e5352")
    _cube(self,Vector3(18.6,1.24,.30),Vector3(-.5,h+.75,-10.0),"#5f615a")
    var outward: float = w*.5 + .26
    for level in range(6):
        for bay in range(3):
            var item: String = "housing-facade-window"
            if level == 0 and bay == 1:
                item = "housing-facade-shop"
            elif level > 0 and (level + bay) % 3 == 0:
                item = "housing-facade-balcony"
            _module(item,float(level)*3.15,float(bay-1)*6.0,
                outward, "floor_%d_bay_%d" % [level,bay])
    statistics["frontage_width_metres"] = 18.0
    statistics["retail_modules"] = 1
    statistics["orientation"] = "east"
    set_meta("v36_preview_only",true)
