extends WalkableMartV15
class_name WalkableMartV16

# V0.16: deliberately small, art-directed market. The physical doorway and
# external city coordinates remain those tested in V0.15. Bundled packaging
# textures are original fictional brands, not captures of commercial artwork.
const SKU_ROOT: String = "res://art/interiors_v16/"
const SKU_IDS: Array[String] = ["ocha", "coffee", "milk", "tea", "rice", "noodles", "juice", "cookies"]
var rack_count: int = 0
var stocked_sku_instances: int = 0
var lit_fixture_count: int = 0
var shelf_clear_center_width: float = 2.35
var _stock_batches: Dictionary = {}

func _vmat(rgb: String, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
    return _material(Color(rgb), rough, metal)

func _tiled(file_name: String, tint: String, rough: float = .78) -> StandardMaterial3D:
    var m: StandardMaterial3D = _vmat(tint, rough)
    m.albedo_texture = load(SKU_ROOT + file_name + ".png") as Texture2D
    m.uv1_triplanar = true
    m.uv1_scale = Vector3(.67,.67,.67)
    return m

func _shell(theme: String) -> void:
    if theme != "mart":
        super._shell(theme)
        return
    # Same physical envelope as V0.15; restrained, neutral exposure and
    # accent materials reduce the previous overbright showroom appearance.
    var w: float = 11.8
    var d: float = 12.2
    var h: float = 4.18
    var hw: float = w * .5
    var hd: float = d * .5
    room_dimensions = Vector2(w, d)
    clear_entry_width = shelf_clear_center_width
    var plaster: Material = _tiled("wall", "#bab8ad", .87)
    var floor_m: Material = _tiled("floor", "#bcc0b8", .86)
    var graphite: Material = _vmat("#303e3e", .67)
    var oak: Material = _tiled("oak", "#a7a396", .7)
    var ceiling: Material = _vmat("#b8b9b1", .91)
    var glass: StandardMaterial3D = _vmat("#9daaa9", .14)
    glass.albedo_color.a = .22
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    _panel(Vector3(0,-.13,0),Vector3(w,.25,d),floor_m,true)
    _panel(Vector3(0,h+.12,0),Vector3(w,.22,d),ceiling)
    _panel(Vector3(0,h*.5,-hd),Vector3(w,h,.17),plaster,true)
    _panel(Vector3(-hw,h*.5,0),Vector3(.17,h,d),plaster,true)
    _panel(Vector3(hw,h*.5,0),Vector3(.17,h,d),plaster,true)
    var side_w: float = (w-clear_entry_width)*.5
    for sign in [-1.0,1.0]:
        var sx: float = sign * (clear_entry_width*.5 + side_w*.5)
        _panel(Vector3(sx,h*.5,hd),Vector3(side_w,h*.91,.075),glass)
        _panel(Vector3(sx,.21,hd+.08),Vector3(side_w,.36,.17),graphite)
        _panel(Vector3(sign*clear_entry_width*.5,2.0,hd+.10),Vector3(.085,3.85,.14),graphite)
        _panel(Vector3(sign*(clear_entry_width*.5+side_w),2.0,hd+.10),Vector3(.09,3.85,.14),graphite)
        _panel(Vector3(sx,2.50,hd+.11),Vector3(side_w,.065,.15),oak)
    _panel(Vector3(0,h-.18,hd),Vector3(w,.38,.18),graphite)
    _panel(Vector3(0,.07,hd+.18),Vector3(clear_entry_width,.075,1.04),oak)
    _panel(Vector3(0,.40,-hd+.13),Vector3(w-.2,.81,.10),oak)
    _panel(Vector3(0,1.02,-hd+.13),Vector3(w-.2,.055,.13),graphite)
    for side in [-1.0,1.0]:
        _panel(Vector3(side*(hw-.11),.39,0),Vector3(.12,.79,d-.2),oak)
        _panel(Vector3(side*(hw-.12),.87,0),Vector3(.16,.045,d-.2),graphite)
    # Restrained, practical ceiling strips. Do not add unrestricted white OmniLight.
    for pos in [Vector3(-3.0,3.58,-2.5),Vector3(3.0,3.58,-2.5),Vector3(-3.0,3.58,2.0),Vector3(3.0,3.58,2.0)]:
        var lamp: OmniLight3D = OmniLight3D.new()
        lamp.position = pos
        lamp.light_color = Color("#f3dfbf")
        lamp.light_energy = .42
        lamp.omni_range = 5.8
        lamp.shadow_enabled = false
        add_child(lamp)
        _panel(pos+Vector3(0,.40,0),Vector3(1.7,.05,.19),_vmat("#d6ceb6",.56))
        lit_fixture_count += 1
    functional_zones.append("entrance")

func _rack(center: Vector3, frame: Material, deck: Material) -> void:
    # 1.48 m wide, 2.62 m deep, 1.64 m high, with 3 merchandised tiers.
    _panel(center+Vector3(0,.14,0),Vector3(1.45,.27,2.58),frame,true)
    _panel(center+Vector3(0,.82,0),Vector3(.075,1.36,2.54),frame)
    for level in [.48,.92,1.36]:
        _panel(center+Vector3(0,level,0),Vector3(1.48,.07,2.57),deck)
    for xoff in [-.68,.68]:
        for zoff in [-1.20,1.20]:
            _panel(center+Vector3(xoff,.85,zoff),Vector3(.05,1.47,.06),frame)
    rack_count += 1
    collidable_assets += 1

func _stock_item(sku: String, pos: Vector3, height: float, rotation_y: float) -> void:
    if not _stock_batches.has(sku):
        _stock_batches[sku] = []
    (_stock_batches[sku] as Array).append({"position":pos,"height":height,"yaw":rotation_y})
    stocked_sku_instances += 1
    displayed_products += 1

func _stock_rack(center: Vector3, salt: int) -> void:
    # Product bottoms sit on shelves; visible packages face the pedestrian side.
    for tier in range(3):
        var shelf: float = [.48,.92,1.36][tier]
        for side in range(2):
            var x: float = center.x + (-.41 if side == 0 else .41)
            for k in range(5):
                var sku: String = SKU_IDS[(salt*3+tier*2+k+side)%SKU_IDS.size()]
                var ph: float = .245 + .023*float((k+salt+tier)%3)
                var z: float = center.z - .94 + .47*float(k)
                _stock_item(sku,Vector3(x,shelf+.045+ph*.5,z),ph,PI*.5 if side==0 else -PI*.5)

func _stock_fridge(center_x: float, start: int) -> void:
    var casing: Material = _vmat("#3c4c51",.36,.26)
    var glass: StandardMaterial3D = _vmat("#617c81",.16)
    glass.albedo_color.a = .26
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var metal: Material = _vmat("#9da4a0",.36,.34)
    _panel(Vector3(center_x,1.11,-5.56),Vector3(2.22,2.20,.77),casing,true)
    _panel(Vector3(center_x,1.17,-5.13),Vector3(2.05,1.97,.045),glass)
    _panel(Vector3(center_x,1.18,-5.08),Vector3(.04,1.98,.08),metal)
    for shelf in [.47,.91,1.35,1.79]:
        _panel(Vector3(center_x,shelf,-5.23),Vector3(1.92,.035,.12),metal)
        for k in range(6):
            var ph: float = .22 + float((start+k)%2)*.035
            _stock_item(SKU_IDS[(start+k)%SKU_IDS.size()],Vector3(center_x-.80+k*.32,shelf+.022+ph*.5,-5.12),ph,0)
    collidable_assets += 1

func _finalize_stock() -> void:
    # At most 8 MultiMesh draw batches for the 160+ individual packages.
    # No per-item collision: only physical racks and fridge chassis block motion.
    for sku in SKU_IDS:
        if not _stock_batches.has(sku):
            continue
        var items: Array = _stock_batches[sku]
        if items.is_empty():
            continue
        var mat: StandardMaterial3D = _vmat("#ffffff",.82)
        mat.albedo_texture = load(SKU_ROOT + "pack_" + sku + ".png") as Texture2D
        var pack: BoxMesh = BoxMesh.new()
        pack.size = Vector3(.18,1.0,.12)
        pack.material = mat
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = pack
        mm.instance_count = items.size()
        for i in range(items.size()):
            var item: Dictionary = items[i]
            var transform: Transform3D = Transform3D(Basis(Vector3.UP,float(item["yaw"])),Vector3(item["position"]))
            transform.basis = transform.basis.scaled(Vector3(1.0,float(item["height"]),1.0))
            mm.set_instance_transform(i,transform)
        var actor: MultiMeshInstance3D = MultiMeshInstance3D.new()
        actor.name = "V16_Stock_" + sku
        actor.multimesh = mm
        actor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(actor)

func _mart() -> void:
    _shell("mart")
    var graphite: Material = _vmat("#34403f",.61)
    var walnut: Material = _tiled("oak","#877d6b",.67)
    var steel: Material = _vmat("#74817d",.54,.22)
    var amber: Material = _vmat("#ab8663",.55)
    var signage: Material = _vmat("#354c47",.61)
    # Integrated checkout at left; center path x[-1.17,+1.17] is never blocked.
    _panel(Vector3(-4.20,.50,4.20),Vector3(2.55,1.00,1.16),walnut,true)
    _panel(Vector3(-4.20,1.02,4.20),Vector3(2.70,.09,1.35),graphite)
    _panel(Vector3(-4.2,.53,3.59),Vector3(2.45,.71,.045),amber)
    _prop("furniture-kit","computerscreen",Vector3(-4.76,1.07,4.10),.41,PI)
    _prop("furniture-kit","computerkeyboard",Vector3(-4.31,1.07,3.83),.056)
    _prop("furniture-kit","trashcan",Vector3(-5.20,.02,5.0),.58)
    _panel(Vector3(0,3.22,-5.99),Vector3(5.15,.72,.035),signage)
    _sign("AOI  MART   /   24H",Vector3(0,3.32,-5.94),30,Color("#e9e2cf"))
    _sign("FOOD  ·  DRINKS  ·  DAILY",Vector3(0,2.85,-5.92),20,Color("#bb9e79"))
    functional_zones.append("checkout")
    # Two clear side lanes each side, and an unobstructed 2.35m center aisle.
    for center_x in [-3.05,3.05]:
        for j in range(2):
            var center: Vector3 = Vector3(center_x,0,-2.50+3.15*float(j))
            _rack(center,steel,walnut)
            _stock_rack(center,j+(0 if center_x<0 else 2))
    functional_zones.append("gondola-shelves")
    # Back wall refrigeration with glass framing and level-specific product lines.
    for i in range(3):
        _stock_fridge(-3.85+float(i)*3.85,i*2)
    functional_zones.append("refrigeration")
    # Small natural-scale front promo stand, off the physical center aisle.
    _panel(Vector3(3.93,.43,4.10),Vector3(1.65,.82,1.04),walnut,true)
    _panel(Vector3(3.93,.87,4.10),Vector3(1.70,.045,1.10),graphite)
    for i in range(8):
        _stock_item(SKU_IDS[(i+2)%SKU_IDS.size()],Vector3(3.32+float(i%4)*.40,1.03,3.93+float(int(i/4))*.33),.27,0)
    _panel(Vector3(3.87,2.48,5.85),Vector3(2.30,.27,.05),signage)
    _sign("今週のおすすめ",Vector3(3.89,2.58,5.76),21,Color("#e9dcc4"))
    _finalize_stock()
    functional_zones.append("seasonal-promo")
