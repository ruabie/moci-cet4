extends Node3D
class_name PlannedDistrictV32

# V0.32: optional connected, collision-backed land-use pilot.
# Do NOT mark facilities interactable before interiors/doorway access exist.
# World plan and spatial validator consume the same exact JSON.
const DATA_PATH: String = "res://data/v32_north_district.json"
var statistics: Dictionary = {}
var _mats: Dictionary = {}
var _pieces: int = 0
var _windows: int = 0

func _material(hex: String, rough: float = 0.84, emission: bool = false) -> StandardMaterial3D:
    var key: String = hex + "|" + str(rough) + "|" + str(emission)
    if _mats.has(key):
        return _mats[key] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = rough
    if emission:
        m.emission_enabled = true
        m.emission = Color(hex)
        m.emission_energy_multiplier = 0.23
    _mats[key] = m
    return m

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, hex: String, rough: float = 0.85) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = dimensions
    n.mesh = box
    n.position = pos
    n.material_override = _material(hex,rough)
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(n)
    _pieces += 1
    return n

func _collider(parent: Node3D, pos: Vector3, size: Vector3, label: String) -> void:
    var body := StaticBody3D.new()
    body.name = "Solid_" + label
    body.collision_layer = 1
    body.collision_mask = 1
    body.position = pos
    var shape := CollisionShape3D.new()
    var solid := BoxShape3D.new()
    solid.size = size
    shape.shape = solid
    body.add_child(shape)
    parent.add_child(body)

func _sign(parent: Node3D, text_value: String, at: Vector3, size: int = 35) -> void:
    var sign := Label3D.new()
    sign.text = text_value
    sign.font_size = size
    sign.pixel_size = .008
    sign.outline_size = 4
    sign.modulate = Color("#f0efe7")
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.position = at
    parent.add_child(sign)

func _floor(plan: Dictionary) -> void:
    var b: Dictionary=plan["bounds"]
    var min_x: float=float(b["x_min"])
    var max_x: float=float(b["x_max"])
    var min_z: float=float(b["z_min"])
    var max_z: float=float(b["z_max"])
    var w:float=max_x-min_x
    var d:float=max_z-min_z
    var centre:=Vector3((min_x+max_x)*.5,-.26,(min_z+max_z)*.5)
    _box(self,centre,Vector3(w,.52,d),"#69736b",.99)
    _collider(self,Vector3(centre.x,-.10,centre.z),Vector3(w,.20,d),"V32WalkableGround")
    statistics["ground_m2"]=w*d

func _slab(parent:Node3D,x:float,z:float,w:float,d:float,hex:String,y:float=.054) -> void:
    _box(parent,Vector3(x,y,z),Vector3(w,.060,d),hex,.99)

func _roads(plan: Dictionary) -> void:
    var asphalt: String="#303940"
    var pavement: String="#747d79"
    var edge:String="#5a625f"
    var lines:String="#d9d9ce"
    # The old CityBuilder main road ends at z=88.5. This begins at z=87,
    # overlapping the same x coordinates for 1.5m without a visible seam.
    _slab(self,0,181,13,188,asphalt,.026) # z 87..275
    _slab(self,0,165,170,13,asphalt,.031) # x -85..85
    for side in [-1.0,1.0]:
        # Sidewalks stop at the junction: no gray pavement across live roads.
        for segment in [[87.0,153.5],[176.5,275.0]]:
            var za:float=float(segment[0])
            var zb:float=float(segment[1])
            _slab(self,side*9,(za+zb)*.5,5.0,zb-za,pavement)
            _box(self,Vector3(side*6.57,.091,(za+zb)*.5),
                Vector3(.17,.095,zb-za),edge)
        # The cross-street sidewalks similarly stop at the longitudinal road.
        for segment in [[-85.0,-12.0],[12.0,85.0]]:
            var xa:float=float(segment[0])
            var xb:float=float(segment[1])
            _slab(self,(xa+xb)*.5,165+side*9,xb-xa,5.0,pavement)
            _box(self,Vector3((xa+xb)*.5,.091,165+side*6.57),
                Vector3(xb-xa,.095,.17),edge)
    # The intersection, trampling at pavement gaps and actual zebra paint.
    for z in range(95,272,8):
        if absf(float(z)-165.0)>15.0:
            _box(self,Vector3(0,.078,float(z)),Vector3(.18,.009,3.35),lines)
    for x in range(-77,78,8):
        if absf(float(x))>17.0:
            _box(self,Vector3(float(x),.083,165),Vector3(3.35,.009,.18),lines)
    for row_z in [151.5,178.5,145.0,222.0]:
        for n in range(-5,6,2):
            _box(self,Vector3(float(n),.087,row_z),Vector3(1.05,.009,2.7),lines)
    for row_x in [-15.0,15.0]:
        for n in range(-5,6,2):
            _box(self,Vector3(row_x,.087,165+float(n)),Vector3(2.7,.009,1.05),lines)
    var concrete: String="#79817b"
    for route in plan["pedestrian_connectors"]:
        var z:float=float(route["z"])
        var width:float=float(route["width"])
        for p in route["segments"]:
            var a:float=float(p[0]);var b:float=float(p[1])
            _slab(self,(a+b)*.5,z,b-a,width,concrete)
            _box(self,Vector3((a+b)*.5,.091,z+width*.5),
                Vector3(b-a,.035,.09),"#6e7874")
    statistics["connected_roads"]=2
    statistics["pedestrian_routes"]=2
    statistics["marked_crossings"]=4

func _entry_path(lot: Dictionary) -> void:
    var cx:float=float(lot["x"]);var z:float=float(lot["z"])
    var w:float=float(lot["w"]);var d:float=float(lot["d"])
    var side:String=str(lot["door"])
    if side=="east":
        var fa:float=cx+w*.5
        var dest:float=-11.5
        _slab(self,(fa+dest)*.5,z,dest-fa,2.35,"#b6b5ac",.076)
    elif side=="west":
        var fa:float=cx-w*.5
        var dest:float=11.5
        _slab(self,(fa+dest)*.5,z,fa-dest,2.35,"#b6b5ac",.076)
    else:
        var fa:float=z+(d*.5 if side=="north" else -d*.5)
        var dest:float=145.0 if z<170 else 222.0
        _slab(self,cx,(fa+dest)*.5,2.35,absf(dest-fa),"#b6b5ac",.076)
    statistics["doors_with_paths"]=int(statistics.get("doors_with_paths",0))+1

func _building(lot: Dictionary) -> void:
    var name:String=str(lot["id"])
    var root:=Node3D.new()
    root.name="PlannedLot_" + name
    root.position=Vector3(float(lot["x"]),0,float(lot["z"]))
    root.set_meta("land_use",str(lot["type"]))
    root.set_meta("exterior_only",true)
    add_child(root)
    var w:float=float(lot["w"]);var d:float=float(lot["d"])
    var h:float=float(lot["h"]);var floors:int=int(lot["levels"])
    # V35 is deliberately two parcels only. Original QA and all production
    # geometry are byte-for-byte unchanged without this additional flag.
    if bool(ProjectSettings.get_setting("application/config/v35_architecture_preview", false)) \
            and name in ["west_homes_a", "east_library"]:
        var pilot := ArchitecturalSliceV35.new()
        pilot.name = "V35Architecture_" + name
        root.add_child(pilot)
        pilot.build_lot(lot)
        # Keep verified V32 collision and actual access path; V35 neither
        # opens a fake interior nor changes a public routing contract.
        _collider(root,Vector3(0,h*.5,0),Vector3(w-.4,h,d-.4),name)
        _entry_path(lot)
        statistics["buildings"]=int(statistics.get("buildings",0))+1
        statistics["v35_architecture_pilots"]=int(statistics.get("v35_architecture_pilots",0))+1
        return
    # Existing sky/tonemap washes light base materials nearly white.
    # Darker, locally-authored wall pigment preserves material contrast in QA.
    var wall:String=Color(str(lot["facade"])).darkened(.17).to_html(false)
    var accent:String=str(lot["accent"])
    var glass:String="#405b63"
    var frame:String="#838e89"
    var roof:String="#545d5c"
    var plinth:float=3.7
    # The base volume, upper stories and setback crown are physically distinct;
    # avoid the same repeated solid box for every lot.
    _box(root,Vector3(0,plinth*.5,0),Vector3(w+0.20,plinth,d+0.20),accent)
    var upper:float=h-plinth
    _box(root,Vector3(0,plinth+upper*.5,0),Vector3(w-.25,upper,d-.25),wall)
    _box(root,Vector3(0,h+.12,0),Vector3(w+.4,.24,d+.35),roof)
    if floors>=5:
        _box(root,Vector3(-w*.13,h+1.35,d*.08),
            Vector3(w*.55,2.5,d*.62),wall)
        _box(root,Vector3(-w*.13,h+2.66,d*.08),
            Vector3(w*.55+.12,.18,d*.62+.10),roof)
    else:
        _box(root,Vector3(w*.20,h+.47,-d*.18),
            Vector3(w*.26,.7,d*.22),roof)
    var face:String=str(lot["door"])
    var side_x:float=1.0 if face=="east" else -1.0
    var side_z:float=1.0 if face=="north" else -1.0
    var x_face:bool=face=="east" or face=="west"
    # Storefronts align to the corridor and never pretend a solid-box
    # interior is publicly accessible. Doors are aesthetic geometry only.
    var ty:String=str(lot["type"])
    if x_face:
        var fx:float=side_x*(w*.5+.14)
        _box(root,Vector3(fx,2.10,0),Vector3(.085,2.75,d*.62),glass,.20)
        for k in [-2,-1,1,2]:
            _box(root,Vector3(fx+side_x*.08,2.10,float(k)*d*.116),
                Vector3(.11,2.75,.09),frame)
        _box(root,Vector3(fx+side_x*.14,1.47,0),Vector3(.13,2.6,1.65),"#314951",.21)
        _box(root,Vector3(fx+side_x*.34,3.69,0),Vector3(.35,.13,d*.72),accent)
        _sign(root,_landmark(ty),Vector3(fx+side_x*.48,4.32,0),32)
        for level in range(1,floors):
            var y:float=minf(4.8+float(level-1)*2.82,h-1.16)
            for col in range(5):
                var zz:float=-d*.37+float(col)*d*.185
                var dark:bool=((col+level*3+name.length())%7)==0
                _box(root,Vector3(fx,y,zz),Vector3(.055,1.42,d*.115),
                    "#776f66" if dark else glass,.26)
                _box(root,Vector3(fx+side_x*.07,y-.73,zz),
                    Vector3(.12,.12,d*.132),frame)
                _windows+=1
    else:
        var fz:float=side_z*(d*.5+.14)
        _box(root,Vector3(0,2.1,fz),Vector3(w*.62,2.75,.085),glass,.21)
        for k in [-2,-1,1,2]:
            _box(root,Vector3(float(k)*w*.115,2.1,fz+side_z*.07),
                Vector3(.085,2.75,.13),frame)
        _box(root,Vector3(0,1.47,fz+side_z*.16),
            Vector3(1.66,2.60,.13),"#314951",.22)
        _box(root,Vector3(0,3.68,fz+side_z*.24),
            Vector3(w*.72,.13,.35),accent)
        _sign(root,_landmark(ty),Vector3(0,4.34,fz+side_z*.48),32)
        for level in range(1,floors):
            var y:float=minf(4.8+float(level-1)*2.82,h-1.15)
            for col in range(5):
                var xx:float=-w*.37+float(col)*w*.185
                var dark:bool=((col*2+level+name.length())%9)==0
                _box(root,Vector3(xx,y,fz),Vector3(w*.115,1.42,.055),
                    "#777770" if dark else glass,.28)
                _box(root,Vector3(xx,y-.73,fz+side_z*.06),
                    Vector3(w*.13,.10,.11),frame)
                _windows+=1
    # Rear elevations used to be blank, visibly boxlike from the aerial QA.
    # Add genuine framed glazing on the opposite street-facing side, without
    # collision or access claims for these upper floors.
    for level in range(1,floors):
        var y:float=minf(4.8+float(level-1)*2.82,h-1.16)
        for col in range(4):
            var lit:bool=((col*3+level*2+name.length())%11)==0
            var tint:String="#9d917b" if lit else glass
            if x_face:
                var back_x:float=-side_x*(w*.5+.115)
                var pz:float=-d*.34+float(col)*d*.225
                _box(root,Vector3(back_x,y,pz),
                    Vector3(.055,1.44,d*.12),tint,.27)
                _box(root,Vector3(back_x-side_x*.07,y-.75,pz),
                    Vector3(.14,.105,d*.135),frame)
            else:
                var back_z:float=-side_z*(d*.5+.115)
                var px:float=-w*.34+float(col)*w*.225
                _box(root,Vector3(px,y,back_z),
                    Vector3(w*.12,1.44,.055),tint,.27)
                _box(root,Vector3(px,y-.75,back_z-side_z*.07),
                    Vector3(w*.135,.105,.14),frame)
            _windows+=1
    # Upper parapet and rooftop service volumes, not repeated floor-height boxes.
    for zz in [-d*.41,d*.41]:
        _box(root,Vector3(0,h+.37,zz),Vector3(w*.88,.5,.13),frame)
    for xx in [-w*.42,w*.42]:
        _box(root,Vector3(xx,h+.37,0),Vector3(.13,.5,d*.84),frame)
    _box(root,Vector3(w*.28,h+.62,-d*.23),
        Vector3(1.35,1.0,1.15),"#586460")

    # Side elevation windows, drain pipes, wall bay and rooftop mechanicals.
    for level in range(1,maxi(2,floors-1)):
        var y:float=4.8+float(level-1)*2.82
        if y>h-1.1:continue
        for xx in [-w*.23,w*.22]:
            _box(root,Vector3(xx,y,-d*.5-.09),
                Vector3(w*.16,1.36,.055),glass,.25)
            _windows+=1
    for side in [-1.0,1.0]:
        _box(root,Vector3(side*(w*.5-.20),h*.49,-d*.5+.13),
            Vector3(.085,h*.88,.075),frame)
    if ty=="residential":
        for level in range(2,floors,2):
            var y:float=3.65+float(level)*2.7
            if y<h-.2:
                _box(root,Vector3(0,y,d*.5+.48),
                    Vector3(w*.47,.12,.9),"#9ca8a4")
                _box(root,Vector3(0,y+.42,d*.5+.90),
                    Vector3(w*.47,.74,.07),frame)
    # Collision follows the footprint, not over-wide decorative frontage.
    _collider(root,Vector3(0,h*.5,0),Vector3(w-.4,h,d-.4),name)
    _entry_path(lot)
    statistics["buildings"]=int(statistics.get("buildings",0))+1

func _landmark(kind:String) -> String:
    match kind:
        "clinic":return "NEIGHBORHOOD CLINIC"
        "library":return "COMMUNITY LIBRARY"
        "retail":return "STREET RETAIL"
        "office":return "LOCAL OFFICE"
        "studio":return "ART & WORK"
        "public":return "CIVIC SERVICE"
        _:return "AOKAWA HOMES"

func _tree(x:float,z:float,scale:float=1.0) -> void:
    # Reuse the project's already built original glTF foliage, not toy spheres.
    # Source is build_landscape_v10.py (three nonidentical leaf/branch shapes).
    var variants:Array[String]=["zelkova_full","katsura_warm","zelkova_narrow"]
    var seed:int=absi(roundi(x*19.0+z*7.0))
    var species:String=variants[seed%variants.size()]
    var resource:PackedScene=load("res://art/vegetation/%s.glb" % species) as PackedScene
    if resource==null:
        push_error("V32 QA must not substitute procedural sphere for missing imported foliage")
        return
    var tree:=Node3D.new()
    tree.name="V32AuthoredFoliage_%s_%d" % [species,seed]
    tree.position=Vector3(x,0,z)
    tree.rotation.y=float(seed%13)*.30
    tree.scale=Vector3.ONE*scale
    add_child(tree)
    tree.add_child(resource.instantiate())
    statistics["original_glb_foliage_instances"]=int(statistics.get(
        "original_glb_foliage_instances",0))+1

func _seat(x:float,z:float,angle:float=0.0) -> void:
    var root:=Node3D.new()
    root.position=Vector3(x,.05,z)
    root.rotation.y=angle
    add_child(root)
    _box(root,Vector3(0,.65,0),Vector3(1.9,.14,.6),"#907e65")
    _box(root,Vector3(0,1.0,.27),Vector3(1.9,.68,.12),"#8c7965")
    for sx in [-.77,.77]:
        _box(root,Vector3(sx,.34,0),Vector3(.095,.65,.095),"#535e5b")

func _park(park:Dictionary) -> void:
    var cx:float=float(park["x"]);var cz:float=float(park["z"])
    var w:float=float(park["w"]);var d:float=float(park["d"])
    var root:=Node3D.new()
    root.name="V32CommunityGreenAndPublicPath"
    add_child(root)
    _slab(root,cx,cz,w,d,"#55735e",.052)
    # Continuous public path from east-west foot lane z222 into park.
    _slab(root,cx,228,2.8,12.4,"#b9b5aa",.082)
    _slab(root,cx,cz,2.8,d-2,"#b7b2a8",.082)
    _slab(root,cx,cz+4,19,2.7,"#b7b2a8",.082)
    for p in [[-74.5,237.0],[-56,237],[-75,251],[-54.5,253.0],[-71,259],[-58.0,258.0]]:
        _tree(float(p[0]),float(p[1]),.88)
    _seat(-72,244,0)
    _seat(-58,249,PI)
    _seat(-65,254,PI*.5)
    _sign(root,"NORTH COMMUNITY GREEN",Vector3(cx,2.0,cz-10),36)
    statistics["parks"]=1

func _bus_stop(f:Dictionary) -> void:
    var root:=Node3D.new()
    root.name="V32WestSideBusShelter"
    root.position=Vector3(float(f["x"]),0,float(f["z"]))
    add_child(root)
    # All structure outside x=-11.5 sidewalk boundary; 5m walkway remains free.
    _slab(root,0,0,3.0,2.4,"#a3a59d",.072)
    for x in [-1.3,1.3]:
        for z in [-1.0,1.0]:
            _box(root,Vector3(float(x),1.25,float(z)),
                Vector3(.11,2.5,.11),"#4f6366")
    _box(root,Vector3(0,2.58,0),Vector3(3.15,.18,2.6),"#48565a")
    _box(root,Vector3(0,1.45,-1.05),Vector3(2.8,1.82,.07),"#657d81",.25)
    _sign(root,"BUS 02",Vector3(0,2.92,0),38)
    _seat(float(f["x"])-1.2,float(f["z"])+.3,PI*.5)
    statistics["bus_shelters"]=1

func _bikes(f:Dictionary) -> void:
    var root:=Node3D.new()
    root.name="V32PublicBikeDock"
    root.position=Vector3(float(f["x"]),0,float(f["z"]))
    add_child(root)
    for i in range(5):
        var z:float=(float(i)-2.0)*.78
        for x in [-.44,.44]:
            _box(root,Vector3(x,.48,z),
                Vector3(.10,.96,.11),"#687c79")
        _box(root,Vector3(0,.94,z),Vector3(.97,.10,.11),"#788b84")
    statistics["shared_bike_capacity"]=5

func _street_lamp(x:float,z:float) -> void:
    var root:=Node3D.new()
    root.position=Vector3(x,0,z)
    add_child(root)
    _box(root,Vector3(0,2.65,0),Vector3(.14,5.3,.14),"#626e70")
    _box(root,Vector3(-.36 if x>0 else .36,5.20,0),
        Vector3(.8,.12,.11),"#626e70")
    _box(root,Vector3(-.72 if x>0 else .72,5.10,0),
        Vector3(.41,.10,.33),"#d1d4c1",.40)

func _ready() -> void:
    var raw:String=FileAccess.get_file_as_string(DATA_PATH)
    var parsed:Variant=JSON.parse_string(raw)
    if not (parsed is Dictionary):
        push_error("V32 map JSON is invalid or unavailable")
        return
    var plan:Dictionary=parsed as Dictionary
    if str(plan.get("version",""))!="V0.32":
        push_error("V32 map data version mismatch")
        return
    name="V32NorthWalkableDistrictPreview"
    _floor(plan)
    _roads(plan)
    for lot in plan["lots"]:
        _building(lot as Dictionary)
    _park(plan["park"] as Dictionary)
    for f in plan["facilities"]:
        var facility:Dictionary=f as Dictionary
        match str(facility["type"]):
            "shelter":_bus_stop(facility)
            "bike_rack":_bikes(facility)
    # Keep real branched foliage away from all 11 authored door corridors.
    # Three differentiated shapes also reduce the oversized empty green gaps.
    for x in [-13.4,13.4]:
        for z in [97.0,178.5,230.0,265.0]:
            _tree(x,z,.78)
    for z in [110.0,129.0,194.0,242.0]:
        _street_lamp(-10.8,z)
        _street_lamp(10.8,z)
    statistics["v32_version"]="V0.32"
    statistics["geometry_pieces"]=_pieces
    statistics["visible_facade_windows"]=_windows
    statistics["exterior_only"]=true
    statistics["expansion_is_qa_only"]=true
    statistics["actual_scene_nodes"]=get_child_count()
