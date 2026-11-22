extends Node3D
class_name WalkableShopV37

# QA-only spatial architecture test on west_homes_a. This addresses the
# specifically verified V36 defect: a solid full-footprint collider makes
# its attractive 'shop' purely decorative. No economy/POI integration.
# All dimensions are metres in the V32 parcel's LOCAL coordinates.
# Only the ground-level 7.6 x 6.0 m room is physically traversable.
const ASSET_ROOT: String = "res://art/third_party/tevy_v36/"
const SOURCE_PARTS: Array[String] = [
    "housing-facade-shop",
    "housing-facade-window",
    "housing-facade-balcony"
]
const ENTRANCE_CLEAR_WIDTH: float = 2.9
const ENTRANCE_HEIGHT: float = 2.75
const RETAIL_DEPTH: float = 6.0
const RETAIL_WIDTH: float = 7.6

var statistics: Dictionary = {}
var _source: Dictionary = {}
var _palette: Dictionary = {}

func _mat(hex: String, rough: float = 0.84, metallic: float = 0.0) -> StandardMaterial3D:
    var key: String = hex + "/" + str(rough) + "/" + str(metallic)
    if _palette.has(key):
        return _palette[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = rough
    mat.metallic = metallic
    _palette[key] = mat
    return mat

func _block(label: String, at: Vector3, dims: Vector3,
        colour: String, solid: bool = true, rough: float = 0.84) -> void:
    assert(dims.x > 0.0 and dims.y > 0.0 and dims.z > 0.0)
    var mesh := MeshInstance3D.new()
    mesh.name = "Mesh_" + label
    var geometry := BoxMesh.new()
    geometry.size = dims
    mesh.mesh = geometry
    mesh.material_override = _mat(colour, rough)
    mesh.position = at
    add_child(mesh)
    statistics["authored_visual_pieces"] = int(statistics.get("authored_visual_pieces",0)) + 1
    if solid:
        var body := StaticBody3D.new()
        body.name = "Solid_" + label
        body.collision_layer = 1
        body.collision_mask = 1
        body.position = at
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = dims
        collision.shape = shape
        body.add_child(collision)
        add_child(body)
        statistics["authored_solid_pieces"] = int(statistics.get("authored_solid_pieces",0)) + 1

func _bounds(model: Node3D) -> AABB:
    var stack: Array[Node] = [model]
    var bounds := AABB(Vector3.ZERO, Vector3.ZERO)
    var has_mesh: bool = false
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var item: MeshInstance3D = node as MeshInstance3D
            if item.mesh != null:
                var bb: AABB = item.get_aabb()
                var xf: Transform3D = model.global_transform.affine_inverse() * item.global_transform
                for i in [0, 1]:
                    for j in [0, 1]:
                        for k in [0, 1]:
                            var p: Vector3 = xf * (
                                bb.position + Vector3(float(i) * bb.size.x,
                                    float(j) * bb.size.y, float(k) * bb.size.z))
                            if not has_mesh:
                                bounds = AABB(p, Vector3.ZERO)
                                has_mesh = true
                            else:
                                bounds = bounds.expand(p)
        for child in node.get_children():
            stack.append(child)
    return bounds if has_mesh else AABB(Vector3.ZERO,Vector3.ZERO)

func _source_module(slug: String, level: int, bay: int) -> void:
    var packed: PackedScene = _source.get(slug) as PackedScene
    if packed == null:
        push_error("V37 missing verified source module " + slug)
        statistics["missing_source"] = int(statistics.get("missing_source",0)) + 1
        return
    var node := Node3D.new()
    node.name = "V37Pinned_%d_%d_%s" % [level,bay,slug]
    node.position = Vector3(10.26, float(level) * 3.15, float(bay-1) * 6.0)
    node.rotation.y = PI * 0.5
    add_child(node)
    var imported: Node3D = packed.instantiate() as Node3D
    if imported == null:
        push_error("V37 source must instantiate Node3D " + slug)
        statistics["missing_source"] = int(statistics.get("missing_source",0)) + 1
        return
    node.add_child(imported)
    var bb: AABB = _bounds(imported)
    if bb.size.x < 4.0 or bb.size.x > 7.0 or bb.size.y < 2.5:
        push_error("V37 imported geometry altered outside source bounds: " + slug)
        statistics["bad_bounds"] = int(statistics.get("bad_bounds",0)) + 1
        return
    imported.position = Vector3(
        -(bb.position.x + bb.size.x*.5),
        -bb.position.y,
        -(bb.position.z + bb.size.z*.5))
    node.set_meta("source_license_declared","CC0-1.0")
    node.set_meta("original_source",slug)
    statistics["verified_glb_instances"] = int(statistics.get("verified_glb_instances",0)) + 1

func _goods_and_furniture() -> void:
    # Shelving, counter and products stay outside the central 2.9m door path.
    # Original life-game commerce is NOT connected; no fake work payouts.
    _block("counter_top", Vector3(5.25,1.03,-2.67),Vector3(1.55,.12,1.05),"#9b8069",true)
    _block("counter_front",Vector3(5.25,.51,-2.67),Vector3(1.48,.97,.91),"#6d746e",true)
    for side in [-1.0,1.0]:
        var zz: float = side * 3.22
        for tier in range(3):
            _block("shelf_%s_%s" % [str(side),str(tier)],
                Vector3(7.13,.64+float(tier)*.65,zz),
                Vector3(3.30,.12,.55),"#a39178",true)
        # Merchandise is visual only, not attached to money/save state.
        for n in range(6):
            _block("goods_%s_%s" % [str(side),str(n)],
                Vector3(5.85+float(n%3)*.96,.76+float(n/3)*.65,zz),
                Vector3(.25,.36,.24),"#869b90" if n%2==0 else "#c2a78e",false)
    statistics["furniture_pieces"] = 2 + 6

func build_lot(lot: Dictionary) -> void:
    statistics = {
        "version":"V0.37","pilot_lot":"west_homes_a",
        "source_assets":"tevy v1 pinned original GLBs, SHA verified during CI build",
        "source_license":"CC0-1.0 supplier declaration",
        "interior_mode":"ground-floor spatial QA only",
        "economy_integrated":false,"poi_registered":false,
        "source_variant_count":SOURCE_PARTS.size(),
        "verified_glb_instances":0,"missing_source":0,"bad_bounds":0,
        "authored_visual_pieces":0,"authored_solid_pieces":0,
        "entrance_clear_width_m":ENTRANCE_CLEAR_WIDTH,
        "entrance_clear_height_m":ENTRANCE_HEIGHT,
        "walkable_room_depth_m":RETAIL_DEPTH,
        "walkable_room_width_m":RETAIL_WIDTH
    }
    if str(lot.get("id","")) != "west_homes_a" or str(lot.get("door","")) != "east":
        push_error("V37 refuses to create an unplanned walkable site")
        statistics["bad_bounds"] = 1
        return
    if absf(float(lot["w"])-20.0)>.01 or absf(float(lot["d"])-22.0)>.01 or absf(float(lot["h"])-19.2)>.01:
        push_error("V37 refuses to resize V32 planned footprint silently")
        statistics["bad_bounds"] = 1
        return
    for slug in SOURCE_PARTS:
        var path: String = ASSET_ROOT + slug + ".glb"
        var packed: PackedScene = load(path) as PackedScene
        if packed == null:
            statistics["missing_source"] = int(statistics.get("missing_source",0))+1
            push_error("V37 original CC0 GLB unavailable, no fake substitute: " + path)
            return
        _source[slug] = packed
    # Upper floors are SOLID. Ground floor has a real empty lower cavity
    # on the EAST street edge, unlike the full-height V36 solid box.
    _block("upper_solid",Vector3(0,11.30,0),
        Vector3(19.4,15.8,21.4),"#9b988d",true)
    _block("west_ground_solid",Vector3(-3.15,1.65,0),
        Vector3(13.1,3.30,21.4),"#908e83",true)
    for side in [-1.0,1.0]:
        _block("ground_wing_"+str(side),
            Vector3(6.65,1.65,side*7.48),
            Vector3(6.5,3.30,6.43),"#918d82",true)
        _block("store_wall_"+str(side),
            Vector3(7.0,1.57,side*3.89),
            Vector3(6.05,3.14,.19),"#aaa79b",true)
        _block("glazed_front_jamb_"+str(side),
            Vector3(9.91,1.48,side*2.64),
            Vector3(.16,2.65,2.40),"#6b8589",true,.34)
        _block("door_vertical_frame_"+str(side),
            Vector3(10.03,1.47,side*1.55),
            Vector3(.22,2.88,.12),"#596968",true,.52)
    _block("door_header",Vector3(9.99,3.0,0),
        Vector3(.24,.50,3.18),"#71796f",true)
    _block("door_canopy",Vector3(10.48,3.45,0),
        Vector3(1.58,.17,6.40),"#737c79",false)
    _block("sill_stone",Vector3(10.1,.075,0),
        Vector3(1.22,.09,2.92),"#a3a098",true)
    _block("retail_floor",Vector3(7.10,.075,0),
        Vector3(5.78,.13,7.55),"#afa9a0",true)
    _block("retail_ceiling",Vector3(7.00,3.29,0),
        Vector3(6.05,.14,7.76),"#bcb9ac",false)
    _block("rear_retail_wall",Vector3(4.03,1.60,0),
        Vector3(.22,3.2,7.72),"#a69e92",true)
    _goods_and_furniture()
    # Imported meshes are authentic source modules, never stand-ins for
    # collisions or art review. Two ground side bays leave centre open.
    for level in range(6):
        for bay in range(3):
            if level == 0 and bay == 1:
                continue
            var slug: String = "housing-facade-window"
            if level == 0:
                slug = "housing-facade-shop"
            elif (level + bay) % 3 == 0:
                slug = "housing-facade-balcony"
            _source_module(slug,level,bay)
    # Give the previously bare rear upper wall actual window cadence.
    for floor in range(1,6):
        for column in [-1,0,1]:
            _block("rear_window_%d_%d" % [floor,column],
                Vector3(-9.78,4.33+float(floor-1)*3.07,float(column)*5.24),
                Vector3(.06,1.63,2.32),"#4f676c",false,.25)
            _block("rear_sill_%d_%d" % [floor,column],
                Vector3(-9.84,3.47+float(floor-1)*3.07,float(column)*5.24),
                Vector3(.23,.16,2.58),"#c5bbaa",false)
    statistics["interior_spatial_preview_only"] = true
    statistics["open_central_door"] = true
    statistics["upper_floors_inaccessible"] = true
    statistics["furniture_collision_active"] = true
    set_meta("v37_qa_walkable",true)
