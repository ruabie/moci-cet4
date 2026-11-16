extends WalkableMartV16
class_name WalkableMartV17

# Real-depth 3-bay refrigerator: backs, shelves, framed glass and merchandise.
# Existing entrance, checkout, work, save and MultiMesh racks remain inherited.
var open_refrigerator_bays: int = 0
var refrigerated_skus: int = 0
var cold_led_strips: int = 0
var finish_surfaces: int = 0

func _art_finish(kind: String, tint: String) -> StandardMaterial3D:
    var mat: StandardMaterial3D = _vmat(tint,.83)
    var base: String = "res://art/interiors_v17/" + kind
    if ResourceLoader.exists(base + "_base.png"):
        mat.albedo_texture = load(base + "_base.png") as Texture2D
        mat.uv1_triplanar = true
        mat.uv1_scale = Vector3(.82,.82,.82)
    if ResourceLoader.exists(base + "_normal.png"):
        mat.normal_enabled = true
        mat.normal_texture = load(base + "_normal.png") as Texture2D
        mat.normal_scale = .17
    finish_surfaces += 1
    return mat

func _shell(theme: String) -> void:
    super._shell(theme)
    if theme != "mart":
        return
    var tile: Material = _art_finish("ivory_tile","#f4eee3")
    var plaster: Material = _art_finish("warm_plaster","#f5f1e9")
    var timber: Material = _art_finish("ash_wood","#e4cab1")
    var bronze: Material = _vmat("#9d8b72",.43,.26)
    _panel(Vector3(0,.020,0),Vector3(11.56,.021,11.94),tile)
    _panel(Vector3(0,2.12,-5.989),Vector3(11.55,3.58,.018),plaster)
    for side in [-1.0,1.0]:
        _panel(Vector3(side*5.788,2.15,0),Vector3(.023,3.55,11.86),plaster)
        _panel(Vector3(side*5.764,.38,0),Vector3(.029,.70,11.65),timber)
        _panel(Vector3(side*5.749,.76,0),Vector3(.032,.043,11.62),bronze)
    _panel(Vector3(0,3.944,0),Vector3(11.48,.021,11.88),plaster)
    for x in [-5.56,5.56]:
        _panel(Vector3(x,3.87,0),Vector3(.11,.16,11.70),timber)
    for z in [-5.67,5.67]:
        _panel(Vector3(0,3.87,z),Vector3(11.16,.15,.13),timber)
    for child in get_children():
        if child is OmniLight3D:
            var omni := child as OmniLight3D
            omni.light_color = Color("#fff0d8")
            omni.light_energy = .56
            omni.omni_range = 6.1

func _stock_fridge(center_x: float, start: int) -> void:
    # V16's full dark solid box has been removed. +Z faces the shop aisle.
    var casing: Material = _vmat("#334349",.50,.19)
    var liner: Material = _vmat("#d8dbd5",.71,.04)
    var metal: Material = _vmat("#acb1ab",.39,.52)
    var trim: Material = _vmat("#526769",.48,.27)
    var glass: StandardMaterial3D = _vmat("#e1eee8",.09)
    glass.albedo_color.a = .11
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    var led: StandardMaterial3D = _vmat("#ffffff",.30)
    led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    led.emission_enabled = true
    led.emission = Color("#d8ecf7")
    led.emission_energy_multiplier = .80
    # Only the plinth is a solid collision shape; the cavity is open.
    _panel(Vector3(center_x,1.16,-5.93),Vector3(2.14,2.29,.075),liner)
    _panel(Vector3(center_x,.145,-5.51),Vector3(2.20,.29,.89),casing,true)
    _panel(Vector3(center_x,2.33,-5.51),Vector3(2.20,.19,.91),casing)
    _panel(Vector3(center_x,2.18,-5.00),Vector3(2.20,.18,.09),trim)
    for side in [-1.0,1.0]:
        _panel(Vector3(center_x+side*1.073,1.28,-5.51),Vector3(.074,2.06,.83),casing)
        _panel(Vector3(center_x+side*1.085,1.22,-5.012),Vector3(.068,2.04,.087),metal)
        _panel(Vector3(center_x+side*.971,1.26,-5.80),Vector3(.028,1.94,.032),led)
        cold_led_strips += 1
    for tier in [.46,.92,1.38,1.84]:
        _panel(Vector3(center_x,tier,-5.55),Vector3(1.97,.041,.67),metal)
        _panel(Vector3(center_x,tier-.046,-5.19),Vector3(1.90,.05,.03),trim)
        for k in range(6):
            var sku: String = SKU_IDS[(start+k+int(tier*5))%SKU_IDS.size()]
            var height: float = .218+.018*float((start+k)%2)
            _stock_item(sku,Vector3(center_x-.78+float(k)*.312,tier+.030+height*.5,-5.37),height,0.0)
            refrigerated_skus += 1
    for side in [-1.0,1.0]:
        _panel(Vector3(center_x+side*.535,1.23,-5.009),Vector3(1.035,1.94,.016),glass)
        _panel(Vector3(center_x+side*.535,2.18,-5.000),Vector3(1.045,.035,.034),metal)
        _panel(Vector3(center_x+side*.035,1.23,-4.951),Vector3(.023,.77,.043),metal)
    var cold := OmniLight3D.new()
    cold.name = "ColdCabinet_%d" % open_refrigerator_bays
    cold.position = Vector3(center_x,1.70,-5.52)
    cold.light_color = Color("#dcebf0")
    cold.light_energy = .28
    cold.omni_range = 2.0
    cold.shadow_enabled = false
    add_child(cold)
    open_refrigerator_bays += 1
    collidable_assets += 1
