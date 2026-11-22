extends Node3D
class_name StreetscapeDetailsV33

# QA-only: small-scale occupancy, not more cloned office boxes.
# Real bundled Kenney CC0 meshes, plus architectural pieces on existing
# V0.32 lots, with all storefront centerline door routes left unobstructed.
const PLAN: String = "res://data/v32_north_district.json"
const KENNEY: String = "res://art/third_party/kenney/"
var stats: Dictionary = {}
var _materials: Dictionary = {}
var _resources: Dictionary = {}

func _mat(hex: String, rough: float = .80) -> StandardMaterial3D:
    var k:String=hex+"|"+str(rough)
    if _materials.has(k):
        return _materials[k] as StandardMaterial3D
    var m:=StandardMaterial3D.new()
    m.albedo_color=Color(hex)
    m.roughness=rough
    _materials[k]=m
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, rough: float = .82) -> void:
    var mesh:=BoxMesh.new()
    mesh.size=size
    var node:=MeshInstance3D.new()
    node.mesh=mesh
    node.position=pos
    node.material_override=_mat(hex,rough)
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    stats["authored_detail_meshes"]=int(stats.get("authored_detail_meshes",0))+1

func _bounds(root_node: Node3D) -> AABB:
    var stack:Array[Node]=[root_node]
    var bounds:=AABB(Vector3.ZERO,Vector3.ZERO)
    var have:bool=false
    while not stack.is_empty():
        var node:Node=stack.pop_back()
        if node is MeshInstance3D:
            var mi:MeshInstance3D=node as MeshInstance3D
            if mi.mesh!=null:
                var bb:AABB=mi.get_aabb()
                var xf:Transform3D=root_node.global_transform.affine_inverse()*mi.global_transform
                for i in [0,1]:
                    for j in [0,1]:
                        for k in [0,1]:
                            var point:Vector3=xf*(bb.position+Vector3(
                                bb.size.x*float(i),bb.size.y*float(j),bb.size.z*float(k)))
                            if not have:
                                bounds=AABB(point,Vector3.ZERO)
                                have=true
                            else:
                                bounds=bounds.expand(point)
        for child in node.get_children():
            stack.append(child)
    return bounds if have else AABB(Vector3.ZERO,Vector3.ONE)

func _kenney(pack:String,model_name:String,where:Vector3,height:float,yaw:float=0.0) -> void:
    var path:String=KENNEY+pack+"/"+model_name+".glb"
    var packed:PackedScene=null
    if _resources.has(path):
        packed=_resources[path] as PackedScene
    else:
        packed=load(path) as PackedScene
        if packed==null:
            push_error("V33 missing source-tracked CC0 fixture "+path)
            return
        _resources[path]=packed
    var root_node:=Node3D.new()
    root_node.name="V33_Kenney_"+model_name+"_"+str(int(stats.get("licensed_fixtures",0)))
    root_node.position=where
    root_node.rotation.y=yaw
    root_node.set_meta("license","Kenney CC0 1.0")
    add_child(root_node)
    var model:Node3D=packed.instantiate() as Node3D
    root_node.add_child(model)
    var bb:AABB=_bounds(model)
    var factor:float=height/maxf(bb.size.y,.01)
    model.scale=Vector3.ONE*factor
    model.position=Vector3(
        -(bb.position.x+bb.size.x*.5)*factor,
        -bb.position.y*factor,
        -(bb.position.z+bb.size.z*.5)*factor)
    stats["licensed_fixtures"]=int(stats.get("licensed_fixtures",0))+1

func _sign(parent:Node3D,at:Vector3,label:String) -> void:
    var n:=Label3D.new()
    n.text=label
    n.font_size=31
    n.pixel_size=.008
    n.outline_size=4
    n.modulate=Color("#e7e3d9")
    n.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    n.position=at
    parent.add_child(n)

func _detail_lot(lot:Dictionary) -> void:
    var id:String=str(lot["id"])
    var use_type:String=str(lot["type"])
    var cx:float=float(lot["x"]);var cz:float=float(lot["z"])
    var w:float=float(lot["w"]);var d:float=float(lot["d"])
    var side:String=str(lot["door"])
    var facing_x:bool=side=="east" or side=="west"
    var facing:float=1.0 if side in ["east","north"] else -1.0
    var frontage:=Node3D.new()
    frontage.name="V33AuthoredFront_"+id
    frontage.position=Vector3(cx,0,cz)
    frontage.set_meta("belongs_to_lot",id)
    add_child(frontage)
    var accent:String=str(lot["accent"])
    # Fixed lot-local transforms: the center +/-1.2m path to the main street
    # stays clear. Planters occupy only +/-33% side setbacks.
    var retail:bool=use_type in ["clinic","retail","library","studio","public"]
    var surface_1:float=(w*.5+.23) if facing_x else (d*.5+.23)
    var canopy_h:float=3.22 if retail else 3.05
    if facing_x:
        _box(frontage,Vector3(facing*(surface_1+.35),canopy_h,0),
            Vector3(.85,.14,d*.70),accent)
        _box(frontage,Vector3(facing*(surface_1+.17),2.02,-d*.24),
            Vector3(.11,2.6,d*.15),"#314c51",.27)
        _box(frontage,Vector3(facing*(surface_1+.17),2.02,d*.24),
            Vector3(.11,2.6,d*.15),"#314c51",.27)
        for s in [-1.0,1.0]:
            var side_z:float=s*d*.32
            # Fixtures remain away from the doorway at local z=0 and outside
            # the building footprint, but inside the reserved frontage apron.
            _kenney("city-kit-suburban","planter",
                Vector3(cx+facing*(surface_1+1.20),.045,cz+side_z),.80,
                0.0 if facing>0 else PI)
            _box(frontage,Vector3(facing*(surface_1+1.40),.10,side_z),
                Vector3(1.85,.16,2.12),"#737f79")
    else:
        _box(frontage,Vector3(0,canopy_h,facing*(surface_1+.35)),
            Vector3(w*.70,.14,.85),accent)
        _box(frontage,Vector3(-w*.24,2.02,facing*(surface_1+.17)),
            Vector3(w*.15,2.6,.11),"#314c51",.27)
        _box(frontage,Vector3(w*.24,2.02,facing*(surface_1+.17)),
            Vector3(w*.15,2.6,.11),"#314c51",.27)
        for s in [-1.0,1.0]:
            var side_x:float=s*w*.32
            _kenney("city-kit-suburban","planter",
                Vector3(cx+side_x,.045,cz+facing*(surface_1+1.20)),.80,
                PI*.5)
            _box(frontage,Vector3(side_x,.10,facing*(surface_1+1.40)),
                Vector3(2.12,.16,1.85),"#737f79")
    # Different street-level treatments by land-use; existing buildings
    # remain collision-backed and exterior-only. No fake accessible interiors.
    if retail:
        var right:bool=facing>0.0
        var side_p:float=surface_1+.26
        if facing_x:
            _box(frontage,Vector3(facing*side_p,.52,0),
                Vector3(.13,.45,2.10),"#a3aaa5")
            _box(frontage,Vector3(facing*(side_p+.03),3.90,0),
                Vector3(.10,.32,d*.42),"#c4b6a1")
            _sign(frontage,Vector3(facing*(side_p+.11),4.20,0),str(lot["name"]))
        else:
            _box(frontage,Vector3(0,.52,facing*side_p),
                Vector3(2.10,.45,.13),"#a3aaa5")
            _box(frontage,Vector3(0,3.90,facing*(side_p+.03)),
                Vector3(w*.42,.32,.10),"#c4b6a1")
            _sign(frontage,Vector3(0,4.20,facing*(side_p+.11)),str(lot["name"]))
    else:
        # Short entry steps and fence edges flank a *clear central entry*.
        if facing_x:
            _box(frontage,Vector3(facing*(surface_1+.70),.14,0),
                Vector3(1.55,.21,2.4),"#a9aaa2")
            for zz in [-d*.38,d*.38]:
                _box(frontage,Vector3(facing*(surface_1+1.08),.48,zz),
                    Vector3(.18,.92,2.9),"#6a7775")
        else:
            _box(frontage,Vector3(0,.14,facing*(surface_1+.70)),
                Vector3(2.4,.21,1.55),"#a9aaa2")
            for xx in [-w*.38,w*.38]:
                _box(frontage,Vector3(xx,.48,facing*(surface_1+1.08)),
                    Vector3(2.9,.92,.18),"#6a7775")
    stats["authored_frontages"]=int(stats.get("authored_frontages",0))+1

func _street_service() -> void:
    # Bundled real accessory meshes at verified public stops, rather than
    # extra boxy buildings or isolated freestanding kiosks blocking walks.
    _kenney("city-kit-roads","dumpster",Vector3(-43.0,.04,111.0),1.35,PI*.5)
    _kenney("city-kit-roads","dumpster",Vector3(43.0,.04,247.0),1.35,PI*.5)
    stats["service_courts"]=2

func _ready() -> void:
    var raw:String=FileAccess.get_file_as_string(PLAN)
    var payload:Variant=JSON.parse_string(raw)
    if not (payload is Dictionary) or str((payload as Dictionary).get("version",""))!="V0.32":
        push_error("V33 cannot lay streetscape without verified V32 plan")
        return
    for lot in (payload as Dictionary)["lots"]:
        _detail_lot(lot as Dictionary)
    _street_service()
    stats["version"]="V0.33"
    stats["exterior_only"]=true
    stats["qa_only"]=true
