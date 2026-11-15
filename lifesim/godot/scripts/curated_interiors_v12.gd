extends CuratedInteriorsV11
class_name CuratedInteriorsV12

# Compact, zone-authored interiors. CC0 Kenney GLBs are deliberately reused in
# coherent layouts instead of scattering objects around a 14x14 empty hall.
# The former V11 class and its provenance ledger remain intact.
var functional_zones: Array[String] = []
var displayed_products: int = 0
var room_dimensions: Vector2 = Vector2.ZERO
var clear_entry_width: float = 2.35
const SURFACES: String = "res://art/interiors_v12/"

func _surface(name_part: String, tint: Color, rough: float = 0.76) -> StandardMaterial3D:
    var result := _material(tint, rough)
    var tex: Texture2D = load(SURFACES + name_part + ".png") as Texture2D
    if tex != null:
        result.albedo_texture = tex
        result.uv1_triplanar = true
        result.uv1_scale = Vector3(0.62, 0.62, 0.62)
    return result

func _panel(where: Vector3, size: Vector3, mat: Material, block: bool = false) -> void:
    _slab(where, size, mat, block)

func _sign(content: String, where: Vector3, size: int = 30, col: Color = Color("#f1ebe0")) -> void:
    var l := Label3D.new()
    l.name = "WallSign_" + content
    l.text = content
    var path := "res://art/fonts/NotoSansCJKsc-Regular.otf"
    if ResourceLoader.exists(path):
        l.font = load(path) as Font
    l.font_size = size
    l.pixel_size = 0.007
    l.modulate = col
    l.outline_size = 2
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = false
    l.position = where
    add_child(l)

func _shell(theme: String) -> void:
    var home: bool = theme == "home"
    var cafe: bool = theme == "cafe"
    var w: float = 9.0 if home else 11.8
    var d: float = 9.5 if home else 12.2
    var h: float = 3.65 if home else 4.25
    room_dimensions = Vector2(w, d)
    var hw: float = w * .5
    var hd: float = d * .5
    var wall := _surface("lime_plaster", Color("#f0ece3"))
    var timber := _surface("timber_floor", Color("#ffffff"), .67)
    var tile := _surface("porcelain_floor", Color("#ffffff"), .80)
    var ribbed := _surface("ribbed_panels", Color("#d9d8cc"), .72)
    var dark := _material(Color("#263b3a"), .53, .08)
    var brass := _material(Color("#ab9570"), .37, .52)
    var glass := _material(Color(0.66, 0.75, 0.72, .18), .13)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    var floor_m: Material = timber if home or cafe else tile
    _panel(Vector3(0, -.13, 0), Vector3(w, .25, d), floor_m, true)
    # A real ceiling shades the interior from outdoor sun. The third-person
    # camera stays underneath it (head clearance >= 3.65m); no ceiling collision.
    _panel(Vector3(0,h+.12,0),Vector3(w,.22,d),wall)
    # Three enclosing walls, each built as a continuous visual plane.
    _panel(Vector3(0, h/2, -hd), Vector3(w, h, .16), wall, true)
    _panel(Vector3(-hw, h/2, 0), Vector3(.16, h, d), wall, true)
    _panel(Vector3(hw, h/2, 0), Vector3(.16, h, d), wall, true)
    # A physically open center entry, glazed wings, and continuous door header.
    var side_w: float = (w-clear_entry_width)*.5
    for s in [-1.0, 1.0]:
        var sx: float = s * (clear_entry_width*.5 + side_w*.5)
        if home:
            _panel(Vector3(sx, h/2, hd), Vector3(side_w, h, .14), wall, true)
            _panel(Vector3(sx, h*.66, hd+.11), Vector3(side_w*.47, h*.47, .055), glass)
        else:
            _panel(Vector3(sx, h*.49, hd), Vector3(side_w, h*.89, .065), glass)
            _panel(Vector3(sx, .18, hd+.05), Vector3(side_w, .35, .17), dark)
        _panel(Vector3(s * clear_entry_width*.5, h*.47, hd+.04), Vector3(.075, h*.92, .14), dark)
        _panel(Vector3(s * (clear_entry_width+side_w)*.5, h*.47, hd+.04), Vector3(.075, h*.92, .14), dark)
    _panel(Vector3(0, h-.21, hd), Vector3(w, .43, .20), dark)
    _panel(Vector3(0, .11, hd+.13), Vector3(clear_entry_width, .07, .8), brass)
    # Continuous skirtings and ceiling trim hide mesh intersections and add scale.
    for z in [-hd+.16, hd-.20]:
        _panel(Vector3(0, .13, z), Vector3(w-.18, .24, .085), dark)
        _panel(Vector3(0, h-.16, z), Vector3(w-.20, .13, .14), brass)
    for x in [-hw+.16, hw-.16]:
        _panel(Vector3(x, .13, 0), Vector3(.085, .24, d-.20), dark)
        _panel(Vector3(x, h-.16, 0), Vector3(.14, .13, d-.20), brass)
    # Vertical ribbed feature wall has no visible cardboard-like repeating boxes.
    var rear_band: float = w*.62 if cafe else w*.35
    _panel(Vector3(-hw*.28 if cafe else hw*.42, h*.52, -hd+.13), Vector3(rear_band, h*.70, .065), ribbed)
    # The camera remains unobstructed; suspended light fixtures are deliberately sparse.
    for at in ([Vector3(-3.0, h-.48, -1.0), Vector3(2.9, h-.48, 1.7), Vector3(0, h-.5, -3.7)]
        if not home else [Vector3(-2, h-.55, 0), Vector3(2.0, h-.55, -2.7)]):
        var light := OmniLight3D.new()
        light.position = at
        light.light_color = Color("#ffe3bc") if home or cafe else Color("#edf3ec")
        light.light_energy = .80 if cafe else .68
        light.omni_range = 8.5
        light.shadow_enabled = false
        add_child(light)
    functional_zones.append("entrance")

func _pendant(where: Vector3, accent: Material) -> void:
    var cone := CylinderMesh.new()
    cone.top_radius = .16
    cone.bottom_radius = .29
    cone.height = .27
    cone.radial_segments = 24
    var mesh := MeshInstance3D.new()
    mesh.mesh = cone
    mesh.material_override = accent
    mesh.position = where
    add_child(mesh)
    _panel(where+Vector3(0,.32,0), Vector3(.025,.45,.025), accent)

func _artwork(where: Vector3, width: float, height: float, cafe: bool) -> void:
    var wood := _material(Color("#77644f"), .65)
    var image := _material(Color("#6b857c") if cafe else Color("#b18f72"), .87)
    _panel(where, Vector3(width, height, .08), wood)
    _panel(where+Vector3(0,0,.052), Vector3(width-.13,height-.13,.012),image)
    _panel(where+Vector3(-width*.18,height*.13,.07),Vector3(width*.32,.07,.014),_material(Color("#e2d7bf")))
    _panel(where+Vector3(width*.12,-height*.12,.07),Vector3(width*.40,.05,.014),_material(Color("#d8bb8e")))

func _display_goods(x: float, z: float, row_index: int, count: int = 9) -> void:
    # Handmade fixture/layout; food is real bundled CC0 GLB, not colored cubes.
    var models: Array[String] = ["soda-can", "soda-bottle", "carton-small", "sandwich", "bread", "burger", "croissant", "cake", "donut"]
    for i in range(count):
        var shelf_level: int = i % 3
        var index_col: int = int(i / 3)
        var offset: float = (float(index_col)-1.0)*.48
        var y: float = .42 + float(shelf_level)*.53
        var model_name: String = models[(i+row_index*2)%models.size()]
        _prop("food-kit", model_name, Vector3(x+offset,y,z), .21 if model_name != "soda-bottle" else .28)
        displayed_products += 1

func _cafe() -> void:
    _shell("cafe")
    var wood := _surface("timber_floor", Color("#baa689"))
    var dark := _material(Color("#263d3a"), .44)
    var brass := _material(Color("#b49a6a"), .35, .35)
    var ceramic := _surface("porcelain_floor", Color("#ddd9d3"))
    # Unified service counter with an integrated preparation area.
    _panel(Vector3(-2.0, .49, -3.35), Vector3(6.1, .97, 1.30), wood, true)
    _panel(Vector3(-2.0, 1.00, -3.35), Vector3(6.23, .10, 1.43), dark)
    _panel(Vector3(-1.95, .51, -2.60), Vector3(5.6, .70, .07), dark)
    for n in range(6):
        _panel(Vector3(-4.35+n*.91, .53, -2.56), Vector3(.025, .70, .06), brass)
    _prop("furniture-kit", "kitchencoffeemachine", Vector3(-3.6,1.06,-3.55), .57)
    _prop("furniture-kit", "kitchensink", Vector3(-4.75,.02,-4.9), .93, 0, true)
    _prop("furniture-kit", "kitchenfridgesmall", Vector3(4.8,.02,-4.7), 1.68, PI, true)
    _prop("furniture-kit", "bookcaseopen", Vector3(3.60,.02,-4.75), 2.35, PI, true)
    for i in range(10):
        var products: Array[String] = ["croissant", "cake", "donut", "cup-coffee", "cup-coffee"]
        _prop("food-kit", products[i % products.size()], Vector3(-3.4+i*.49,1.06,-2.98), .20)
        displayed_products += 1
    # One queue point and a 1.9m unobstructed path from door to counter.
    functional_zones.append("service-counter")
    _panel(Vector3(-.1, .018, 1.0), Vector3(1.65,.025,4.4),ceramic)
    # High-contrast signboard: text previously disappeared into ribbed wall.
    _panel(Vector3(-2.20,3.02,-5.79),Vector3(5.05,1.02,.075),dark)
    _sign("KAWA  COFFEE", Vector3(-2.2,3.23,-5.68),39,Color("#f6eee2"))
    _sign("ESPRESSO  ·  BAKE  ·  TEA", Vector3(-2.2,2.78,-5.67),24,Color("#e3c58f"))
    # Seating clusters are adjacent to windows and wall art; not in random rows.
    for table_at in [Vector3(-3.80,.03,1.1),Vector3(3.45,.03,1.55),Vector3(-3.6,.03,3.6)]:
        _prop("furniture-kit", "tableround", table_at, .79, 0, true)
        _prop("furniture-kit", "chaircushion", table_at+Vector3(-.72,0,.05),.90, PI*.5)
        _prop("furniture-kit", "chair", table_at+Vector3(.70,0,.05),.87,-PI*.5)
        _prop("food-kit", "cup-coffee", table_at+Vector3(0,.83,0), .20)
        displayed_products += 1
    _prop("furniture-kit", "loungesofa", Vector3(4.68,.03,-.48), 1.04,-PI/2,true)
    _prop("furniture-kit", "tablecoffee", Vector3(3.35,.03,-.53),.56,0,true)
    _prop("furniture-kit", "rugrounded", Vector3(3.75,.04,-.50), .035)
    _prop("furniture-kit", "pottedplant", Vector3(5.05,.03,4.65),1.65)
    _prop("furniture-kit", "lamproundfloor", Vector3(5.03,.03,2.6),1.68)
    _artwork(Vector3(4.35,2.45,-5.88),1.18,.95,true)
    _pendant(Vector3(-3.8,3.46,1.25),dark)
    _pendant(Vector3(3.45,3.46,1.52),dark)
    functional_zones.append("window-seating")
    functional_zones.append("lounge")

func _mart() -> void:
    _shell("mart")
    var graphite := _material(Color("#394844"), .55)
    var wood := _surface("timber_floor",Color("#cfc4ad"))
    var brass := _material(Color("#b7a77c"), .42)
    # Checkout anchored to left of entry, leaving open center route for player.
    _panel(Vector3(-4.02,.53,3.95),Vector3(2.65,1.04,1.25),graphite,true)
    _panel(Vector3(-4.02,1.08,3.95),Vector3(2.70,.08,1.40),wood)
    _prop("furniture-kit","computerscreen",Vector3(-4.48,1.14,3.8),.60,PI)
    _prop("furniture-kit","computerkeyboard",Vector3(-4.02,1.14,3.36),.08)
    _sign("AOI MART / 24H",Vector3(0,3.53,-5.97),36,Color("#36514a"))
    _sign("FOOD   ·   DRINKS   ·   DAILY",Vector3(0,3.05,-5.96),23,Color("#a18459"))
    # Four gondolas form two clearly legible aisles. Minimum entry corridor 2.35m.
    for n in range(4):
        var x: float = -3.15 if n%2==0 else 3.15
        var z: float = -1.6 if n<2 else 1.55
        _prop("furniture-kit","bookcaseopen",Vector3(x,.03,z),2.16,PI*.5,true)
        _display_goods(x,z,n,12)
    functional_zones.append("two-merchandise-aisles")
    # Refrigeration wall + snack endcaps give the store a populated rear boundary.
    for i in range(3):
        _prop("furniture-kit","kitchenfridgesmall",Vector3(-3.9+float(i)*2.2,.03,-4.6),1.9,PI,true)
        _prop("food-kit","soda-can",Vector3(-3.9+float(i)*2.2,1.8,-3.8),.19)
        displayed_products += 1
    _prop("furniture-kit","trashcan",Vector3(5.04,.03,4.91),.70)
    _prop("furniture-kit","pottedplant",Vector3(5.1,.03,-4.77),1.45)
    _panel(Vector3(0,.015,4.2),Vector3(2.35,.02,2.35),brass)
    functional_zones.append("checkout")
    functional_zones.append("refrigerated-goods")

func _home() -> void:
    _shell("home")
    var timber := _surface("timber_floor",Color("#b4a48e"))
    var paint := _surface("lime_plaster",Color("#e4e5d9"))
    var dark := _material(Color("#5d6f67"), .80)
    # Divide the 9x9.5 space into sleep / living / study / kitchenette.
    # The divider ends before the circulation lane, so the player never gets trapped.
    _panel(Vector3(-.7,1.50,-2.00),Vector3(.16,3.00,4.6),paint,true)
    _panel(Vector3(-3.05,.28,-2.12),Vector3(2.6,.55,.12),dark)
    _prop("furniture-kit","beddouble",Vector3(-3.12,.03,-3.34),.85,PI*.5,true)
    _prop("furniture-kit","tablecoffee",Vector3(-4.01,.03,-1.47),.58)
    _prop("furniture-kit","lamproundtable",Vector3(-4.01,.61,-1.47),.40)
    _prop("furniture-kit","bookcaseopenlow",Vector3(-3.94,.02,-.30),1.23,PI*.5,true)
    functional_zones.append("sleeping-nook")
    # Kitchen zone is limited to the rear-right corner with actual appliances.
    _panel(Vector3(2.55,.52,-4.00),Vector3(3.25,1.02,.76),timber,true)
    _prop("furniture-kit","kitchensink",Vector3(1.45,.03,-3.95),.94)
    _prop("furniture-kit","kitchenfridgesmall",Vector3(3.85,.03,-3.85),1.62,PI,true)
    _prop("furniture-kit","kitchenmicrowave",Vector3(2.77,1.06,-4.0),.43)
    _prop("furniture-kit","kitchencoffeemachine",Vector3(1.9,1.04,-4.0),.33)
    functional_zones.append("kitchenette")
    # Workstation/desk, softly separated from lounge by a low bookshelf.
    _prop("furniture-kit","desk",Vector3(3.2,.03,-.90),.99,PI*.5,true)
    _prop("furniture-kit","chairdesk",Vector3(2.55,.03,-.90),.92,-PI*.5)
    _prop("furniture-kit","laptop",Vector3(3.15,1.03,-.90),.27)
    functional_zones.append("workstation")
    _prop("furniture-kit","loungesofa",Vector3(-2.75,.03,2.30),1.00,PI,true)
    _prop("furniture-kit","tablecoffee",Vector3(-2.75,.03,3.42),.52)
    _prop("furniture-kit","rugrounded",Vector3(-2.55,.04,2.92),.034)
    _prop("furniture-kit","pottedplant",Vector3(3.89,.03,3.71),1.37)
    _prop("furniture-kit","lamproundfloor",Vector3(-4.0,.03,3.58),1.52)
    _artwork(Vector3(-2.5,2.47,-4.65),1.60,.92,false)
    functional_zones.append("living-room")
    _sign("HOME / 01",Vector3(2.7,2.88,-4.61),26,Color("#76857c"))

func build_shop(place: String) -> void:
    if place == "咖啡馆":
        _cafe()
    else:
        _mart()

func build_home(owned: Array) -> void:
    _home()
    for item in owned:
        add_purchased_item(str(item))

func add_purchased_item(item: String) -> void:
    # Keep all purchased items within the physically smaller apartment shell.
    match item:
        "desk_lamp":
            _prop("furniture-kit","lamproundtable",Vector3(3.3,1.03,-1.2),.44)
        "soft_rug":
            _prop("furniture-kit","rugrectangle",Vector3(1.8,.043,2.9),.032)
        "green_plant":
            _prop("furniture-kit","pottedplant",Vector3(-3.9,.03,.6),1.4)
        "bookshelf":
            _prop("furniture-kit","bookcaseclosedwide",Vector3(3.95,.03,1.5),1.87,-PI*.5,true)
        "computer":
            _prop("furniture-kit","computerscreen",Vector3(3.2,1.04,-.8),.45,PI*.5)
            _prop("furniture-kit","computerkeyboard",Vector3(2.9,1.04,-.5),.07)