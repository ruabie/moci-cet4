extends CuratedInteriorsV12
class_name CuratedInteriorsV13

# V0.13 art-direction test: one tightly staged cafe, authored as a coherent
# interior instead of filling a giant hall with unrelated low-poly props.
# Other locations deliberately retain their V0.12 behavior and save contract.
const QROOT: String = "res://art/third_party/quaternius_house/"
const ART: String = "res://art/interiors_v13/"
var quaternius_assets: int = 0
var branded_details: int = 0
var art_lights: int = 0
var finish_systems: int = 0
var clear_aisle_width: float = 2.1

func _finish(name_part: String, tint: Color, rough: float = .76) -> StandardMaterial3D:
    var m := _material(tint, rough)
    var tex_path := ART + name_part + "_base.png"
    if ResourceLoader.exists(tex_path):
        m.albedo_texture = load(tex_path) as Texture2D
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(.78, .78, .78)
        var norm_path := ART + name_part + "_normal.png"
        if ResourceLoader.exists(norm_path):
            m.normal_enabled = true
            m.normal_texture = load(norm_path) as Texture2D
            m.normal_scale = .29
    finish_systems += 1
    return m

func _qprop(item: String, where: Vector3, desired_height: float, yaw: float = 0.0, solid: bool = false) -> Node3D:
    var path := QROOT + item + ".glb"
    var scene := load(path) as PackedScene
    if scene == null:
        push_error("V13 missing licensed Quaternius asset: " + path)
        return null
    var pivot := Node3D.new()
    pivot.name = "ArtDirection_" + item + "_" + str(quaternius_assets)
    pivot.position = where
    pivot.rotation.y = yaw
    pivot.set_meta("author", "Quaternius")
    pivot.set_meta("license", "CC0-1.0")
    add_child(pivot)
    var model := scene.instantiate() as Node3D
    if model == null:
        push_error("V13 failed instancing Quaternius " + item)
        return null
    pivot.add_child(model)
    var b: AABB = _bounds(model, model)
    var factor: float = desired_height / maxf(b.size.y, .06)
    model.scale = Vector3.ONE * factor
    model.position = Vector3(-b.position.x-b.size.x*.5, -b.position.y, -b.position.z-b.size.z*.5) * factor
    quaternius_assets += 1
    placed_assets += 1
    if solid:
        var obstacle := StaticBody3D.new()
        obstacle.collision_layer = 1
        obstacle.position = Vector3(0, desired_height*.44, 0)
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(clampf(b.size.x*factor*.72,.25,2.4),maxf(.3,desired_height*.87),clampf(b.size.z*factor*.72,.25,2.1))
        shape.shape = box
        obstacle.add_child(shape)
        pivot.add_child(obstacle)
        collidable_assets += 1
    return pivot

func _light_at(at: Vector3, color: Color, energy: float, radius: float) -> void:
    var light := OmniLight3D.new()
    light.name = "WarmPractical_" + str(art_lights)
    light.position = at
    light.light_color = color
    light.light_energy = energy
    light.omni_range = radius
    light.shadow_enabled = false
    add_child(light)
    art_lights += 1

func _detail_box(at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> void:
    _panel(at, size, mat, solid)
    branded_details += 1

func _shell(theme: String) -> void:
    if theme != "cafe":
        super._shell(theme)
        return
    # One clearly scaled 82 sqm neighborhood cafe with a central 2.1 m aisle.
    var w: float = 9.4
    var d: float = 8.8
    var h: float = 3.55
    var hw: float = w*.5
    var hd: float = d*.5
    room_dimensions = Vector2(w, d)
    clear_entry_width = clear_aisle_width
    var plaster := _finish("plaster", Color("#e3ddd1"), .92)
    var parquet := _finish("walnut", Color("#f3e8d8"), .55)
    var tile := _finish("terrazzo", Color("#e9dfd0"), .74)
    var oak := _finish("walnut", Color("#bca58c"), .62)
    var walnut := _material(Color("#57483b"), .48)
    var ink := _material(Color("#243632"), .56)
    var bronze := _material(Color("#9c7654"), .38, .36)
    var cream := _material(Color("#efe8d8"), .94)
    var glass := _material(Color(.62,.73,.73,.20), .12)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    # Concrete base, recessed tile threshold, and room-specific parquet.
    _panel(Vector3(0,-.14,0),Vector3(w,.27,d),parquet,true)
    _panel(Vector3(0,-.002,3.56),Vector3(2.12,.018,1.55),tile)
    _panel(Vector3(0,.005,-3.45),Vector3(w-.32,.025,1.58),tile)
    # Continuous plaster shell; true opening at the 2.1 m entrance.
    _panel(Vector3(0,h/2,-hd),Vector3(w,h,.17),plaster,true)
    _panel(Vector3(-hw,h/2,0),Vector3(.17,h,d),plaster,true)
    _panel(Vector3(hw,h/2,0),Vector3(.17,h,d),plaster,true)
    _panel(Vector3(0,h+.08,0),Vector3(w+.12,.18,d+.10),cream)
    for s in [-1.0,1.0]:
        var pw: float = (w-clear_aisle_width)*.5
        var cx: float = s*(clear_aisle_width*.5+pw*.5)
        _panel(Vector3(cx,h*.49,hd),Vector3(pw,h*.89,.052),glass)
        _detail_box(Vector3(cx,.16,hd+.015),Vector3(pw,.30,.18),walnut)
        _detail_box(Vector3(cx,h-.22,hd+.02),Vector3(pw,.12,.16),bronze)
        _detail_box(Vector3(s*clear_aisle_width*.5,h*.47,hd+.08),Vector3(.085,h*.91,.13),bronze)
        _detail_box(Vector3(s*(clear_aisle_width*.5+pw),h*.47,hd+.08),Vector3(.085,h*.91,.13),bronze)
        _detail_box(Vector3(cx,1.85,hd+.077),Vector3(pw,.055,.10),bronze)
        _detail_box(Vector3(cx,2.76,hd+.077),Vector3(pw,.055,.10),bronze)
    _detail_box(Vector3(0,h-.16,hd+.08),Vector3(w,.24,.19),ink)
    _detail_box(Vector3(0,.09,hd+.40),Vector3(clear_aisle_width,.095,.86),bronze)
    # Deep dado and timber wall paneling: furniture meets the architecture.
    for side in [-1.0,1.0]:
        _detail_box(Vector3(side*(hw-.09),.56,0),Vector3(.06,1.11,d-.16),oak)
        _detail_box(Vector3(side*(hw-.12),1.16,0),Vector3(.115,.06,d-.20),bronze)
        _detail_box(Vector3(side*(hw-.10),h-.18,0),Vector3(.10,.17,d-.18),cream)
    _detail_box(Vector3(0,.55,-hd+.12),Vector3(w-.20,1.10,.095),oak)
    _detail_box(Vector3(0,1.12,-hd+.12),Vector3(w-.21,.07,.11),bronze)
    _detail_box(Vector3(0,h-.18,-hd+.13),Vector3(w-.20,.15,.14),cream)
    # Ceiling beams and restrained downlights, not huge exposed slabs.
    for z in [-3.28, .45, 3.15]:
        _detail_box(Vector3(0,h-.15,z),Vector3(w-.30,.14,.14),oak)
    for point in [Vector3(-3.0,3.12,-1.8),Vector3(2.0,3.10,-2.6),Vector3(-3.0,3.04,2.10),Vector3(3.05,3.03,2.15)]:
        _light_at(point,Color("#ffe6c4"),.85,6.3)
    _light_at(Vector3(.2,2.8,3.10),Color("#d8e6e4"),.43,5.4)
    _exterior_window_view()
    functional_zones.append("glazed-entrance")

func _cafe() -> void:
    _shell("cafe")
    var oak := _finish("walnut",Color("#ac9277"),.59)
    var ter := _finish("terrazzo",Color("#d4c7b7"),.69)
    var bronze := _material(Color("#ad8960"),.35,.4)
    var ink := _material(Color("#20312c"),.51)
    var cream := _material(Color("#e7ddc8"),.92)
    var linen := _finish("linen", Color("#d1bba7"), .89)
    # Fully joined bar with coherent vertical rhythm and a raised stone counter.
    _detail_box(Vector3(-1.64,.52,-3.56),Vector3(5.72,1.00,1.15),oak,true)
    _detail_box(Vector3(-1.64,1.035,-3.56),Vector3(5.98,.11,1.38),ter)
    _detail_box(Vector3(-1.60,.10,-2.95),Vector3(5.66,.12,.10),bronze)
    for n in range(17):
        _detail_box(Vector3(-4.37+float(n)*.339,.51,-2.966),Vector3(.048,.79,.042),bronze)
    _detail_box(Vector3(-1.30,2.60,-4.26),Vector3(5.80,1.15,.08),ink)
    _sign("K A W A    /    珈 琲", Vector3(-1.35,2.86,-4.16),32,Color("#f4ebd7"))
    _sign("COFFEE  ·  BAKE  ·  SLOW DAY",Vector3(-1.32,2.47,-4.14),18,Color("#dabf94"))
    # A framed menu and integrated backbar shelves with real GLB vessels.
    for level in [1.45,1.93,2.39]:
        _detail_box(Vector3(3.30,level,-4.13),Vector3(2.30,.06,.38),oak)
    _detail_box(Vector3(3.31,1.64,-4.28),Vector3(2.57,1.92,.075),linen)
    _prop("furniture-kit","kitchencoffeemachine",Vector3(-3.52,1.10,-3.45),.54)
    _prop("furniture-kit","kitchenblender",Vector3(-2.69,1.11,-3.51),.38)
    _prop("furniture-kit","kitchenfridgesmall",Vector3(4.08,.02,-3.72),1.53,PI,true)
    _qprop("Shelf_Large",Vector3(3.38,.02,-3.94),2.14,PI,true)
    for k in range(9):
        var foods: Array[String] = ["croissant","donut","cup-coffee","cake","bread"]
        _prop("food-kit",foods[k%foods.size()],Vector3(-3.89+float(k)*.45,1.12,-2.95),.13)
        displayed_products += 1
    for k in range(8):
        _prop("food-kit","cup-coffee",Vector3(2.52+float(k%4)*.49,1.53+float(int(k/4))*.49,-3.98),.15)
        displayed_products += 1
    # A deliberately furnished seating strip; two independent social groupings.
    _qprop("Couch_Medium2",Vector3(-3.79,.03,-.92),.84, PI*.5,true)
    _qprop("Table_RoundSmall2",Vector3(-2.40,.03,-.85),.70,0,true)
    _qprop("Chair_2",Vector3(-1.37,.02,-.85),.87,-PI*.5,true)
    _qprop("Table_RoundSmall2",Vector3(2.47,.03,-.80),.71,0,true)
    _qprop("Chair_3",Vector3(3.63,.03,-.74),.87,PI*.5,true)
    _qprop("Chair_2",Vector3(2.38,.02,-1.85),.88,PI,true)
    _qprop("Couch_Small2",Vector3(-3.67,.03,2.10),.78,PI*.5,true)
    _qprop("Table_RoundSmall2",Vector3(-2.33,.03,2.13),.72,0,true)
    _qprop("Chair_2",Vector3(-1.32,.03,2.13),.88,-PI*.5,true)
    _qprop("Table_RoundSmall2",Vector3(2.47,.03,2.03),.71,0,true)
    _qprop("Chair_3",Vector3(3.54,.02,2.00),.88,PI*.5,true)
    _qprop("Chair_2",Vector3(2.40,.02,1.11),.88,PI,true)
    for table in [Vector3(-2.4,.73,-.85),Vector3(2.47,.73,-.80),Vector3(-2.33,.73,2.13),Vector3(2.47,.73,2.03)]:
        _prop("food-kit","cup-coffee",table,.18)
        displayed_products += 1
    _qprop("Houseplant_4",Vector3(-4.03,.03,3.45),1.25)
    _qprop("Houseplant_4",Vector3(4.04,.03,3.42),1.10)
    _qprop("Light_Floor2",Vector3(-4.12,.02,.48),1.65)
    _qprop("Bookshelf",Vector3(4.16,.03,-2.06),1.64,PI*.5,true)
    # Low art on both wall sides gives the room a lived-in scale.
    _artwork(Vector3(-2.70,2.48,-4.32),.76,.69,true)
    for z in [-1.1,1.48]:
        _detail_box(Vector3(-4.55,2.27,z),Vector3(.10,.99,1.28),ink)
        _detail_box(Vector3(-4.486,2.27,z),Vector3(.02,.84,1.13),linen)
    for x in [-2.70,2.45]:
        _qprop("Light_Ceiling1",Vector3(x,2.79,.66),.38)
        _pendant(Vector3(x,3.00,.66),bronze)
    # A little ceramic threshold and planter at the glass frontage.
    _detail_box(Vector3(-3.65,.065,3.77),Vector3(.64,.10,.63),ter)
    _qprop("Houseplant_4",Vector3(-3.65,.12,3.77),.66)
    functional_zones.append("counter-service")
    functional_zones.append("window-banquette")
    functional_zones.append("reading-corner")
    functional_zones.append("table-seating")

func _exterior_window_view() -> void:
    # View-through-glass dressing for the current instanced cafe interior.
    # This is *not* claimed as continuous exterior navigation. Visual only.
    var sidewalk := _finish("terrazzo", Color("#c4c6c1"), .92)
    var wall := _finish("plaster",Color("#aab1ac"), .91)
    var brick := _material(Color("#837968"), .91)
    var asphalt := _material(Color("#4d5657"), .97)
    var frames := _material(Color("#3f5150"), .56, .12)
    var window := _material(Color("#657779"), .15, .08)
    var accent := _material(Color("#a28463"), .67)
    # Ground plane must be continuous from the door sill to the street.
    _panel(Vector3(0,-.13,6.20),Vector3(13.6,.21,3.65),sidewalk)
    _panel(Vector3(0,-.12,8.04),Vector3(13.6,.21,.18),accent)
    _panel(Vector3(0,-.23,12.0),Vector3(30,.17,7.9),asphalt)
    _panel(Vector3(0,-.135,16.22),Vector3(30,.20,1.6),sidewalk)
    # One unified opposite facade; recesses and rooflines give distance cues.
    _panel(Vector3(0,4.20,18.4),Vector3(20,8.4,.38),wall)
    _panel(Vector3(0,8.43,18.34),Vector3(20.4,.35,.58),brick)
    _panel(Vector3(0,.58,18.15),Vector3(20,1.16,.20),brick)
    for x in [-6.9,-3.25,.4,4.05,7.7]:
        for y in [2.64,5.63]:
            _panel(Vector3(x,y,18.16),Vector3(1.8,2.12,.09),frames)
            _panel(Vector3(x,y,18.07),Vector3(1.57,1.88,.07),window)
            _panel(Vector3(x,y,17.99),Vector3(.05,1.93,.11),accent)
            _panel(Vector3(x,y,17.98),Vector3(1.63,.045,.11),accent)
    # Shop curtain glow and modest tree soften the geometric background.
    _panel(Vector3(0,1.45,18.03),Vector3(3.1,2.75,.09),frames)
    _panel(Vector3(0,1.45,17.94),Vector3(2.82,2.47,.06),_material(Color("#c3ac85"),.91))
    _panel(Vector3(0,3.31,17.98),Vector3(4.6,.59,.25),accent)
    _light_at(Vector3(0,2.65,5.0),Color("#d0e8f0"),.36,6.4)
    var tree: PackedScene = load("res://art/vegetation/zelkova_narrow.glb") as PackedScene
    if tree != null:
        var plant := tree.instantiate() as Node3D
        plant.name="CafeWindowStreetTree"
        plant.position=Vector3(-3.75,.01,9.2)
        plant.scale=Vector3.ONE*.82
        add_child(plant)
    branded_details += 4