extends Node3D

const AUTOSAVE_SECONDS: float = 12.0
const INTERACTION_RADIUS: float = 5.5
const FONT_COLOR = Color("#edf3ec")
const FURNITURE: Array = [
    ["desk_lamp", "阅读灯", 120],
    ["soft_rug", "棉麻地毯", 180],
    ["green_plant", "绿植角", 240],
    ["bookshelf", "木书架", 390],
    ["computer", "桌面电脑", 620]
]

var city: CityBuilder
var player: CityPlayer
var state: Dictionary = {}
var sun: DirectionalLight3D
var ambient_env: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var localized_font: Font
var ui_clock: Label
var ui_balance: Label
var ui_hint: Label
var ui_notice: Label
var ui_place: Label
var ui_activity: Label
var overlay: PanelContainer
var gameplay_time: float = 0.0
var autosave_time: float = 0.0
var notice_time: float = 0.0
var job_mode: String = ""
var job_step: int = 0
var job_correct: int = 0
var job_seconds: float = -1.0
var dialogue_npc: int = -1
var shop_open: bool = false
var web_qa_mode: bool = false
var web_qa_tick: float = 0.0
var near_npc: int = -1
var journal_open: bool = false
var indoor_place: String = ""
var photo_preview: TextureRect
var photo_preview_time: float = 0.0
var photo_spots: Dictionary = {
    "river": Vector3(-18, 0, 47),
    "crossing": Vector3(0, 0, -23),
    "window": Vector3(13, 0, 16)
}
var job_pending_id: String = ""
var in_home: bool = false
var qa_mode: bool = false
var last_location: String = ""
var last_world_clock_second: int = -1
var current_interaction: String = ""
var poi: Dictionary = {
    "公寓": Vector3(-11.4, 0, 13),
    "便利店": Vector3(-11.4, 0, -14),
    "咖啡馆": Vector3(11.4, 0, -14),
    "生活商店": Vector3(11.4, 0, 15),
    "公园": Vector3(-11, 0, 48),
    "委托板": Vector3(-18, 0, 55),
    "河边取件箱": Vector3(12, 0, 47)
}

func _ready() -> void:
    _configure_input()
    qa_mode = bool(ProjectSettings.get_setting("application/config/qa_mode", false))
    state = CitySave.initial() if qa_mode else CitySave.read_save()
    in_home = bool(state.get("at_home", false))
    LifeContent.prepare_day(state, LifeContent.date_key())
    _create_world()
    _create_home()
    _create_business_interiors()
    _create_player()
    _create_ui()
    _initialize_web_qa()
    _update_sun()
    if not qa_mode:
        _save_progress()
    if CitySave.last_load_warning != "":
        _notify(CitySave.last_load_warning, 12.0)
    else:
        _notify("欢迎来到青川町。世界时间与你的设备同步。", 6.0)

func _initialize_web_qa() -> void:
    # Read-only diagnostics in ?qa=1 only: never expose mutating game actions.
    if not OS.has_feature("web"):
        return
    var query: String = str(JavaScriptBridge.eval("window.location.search", true))
    web_qa_mode = query.contains("qa=1")
    if web_qa_mode:
        _emit_web_qa()

func _emit_web_qa() -> void:
    if not web_qa_mode or player == null:
        return
    var snapshot: Dictionary = {
        "x": player.global_position.x,
        "y": player.global_position.y,
        "z": player.global_position.z,
        "balance": int(state.get("balance", 0)),
        "jobs_completed": int(state.get("jobs_completed", 0)),
        "interaction": current_interaction,
        "job_mode": job_mode,
        "job_step": job_step,
        "indoor": indoor_place,
        "at_home": in_home
    }
    # Only serialized numbers and strings are passed to the browser.
    var value: String = JSON.stringify(snapshot)
    JavaScriptBridge.eval("window.__LIFESIM_QA__ = Object.freeze({getState:function(){return Object.freeze(" + value + ");}});", true)

func _configure_input() -> void:
    var keys := {
        "move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "run": [KEY_SHIFT], "interact": [KEY_E], "job": [KEY_J],
        "buy": [KEY_B], "exit_interior": [KEY_Q],
        "parcel": [KEY_K], "photo": [KEY_P], "journal": [KEY_T], "rest": [KEY_R]
    }
    for action_name in keys:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        for code in keys[action_name]:
            var evt := InputEventKey.new()
            evt.physical_keycode = code
            InputMap.action_add_event(action_name, evt)

func _create_world() -> void:
    ambient_env = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky_material = ProceduralSkyMaterial.new()
    var sky_mat := sky_material
    sky_mat.sky_top_color = Color("#5b7890")
    sky_mat.sky_horizon_color = Color("#c3c7c3")
    sky_mat.ground_bottom_color = Color("#525c57")
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.ambient_light_energy = 0.18
    env.fog_enabled = true
    env.fog_light_color = Color("#859395")
    env.fog_density = 0.00185
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    ambient_env.environment = env
    add_child(ambient_env)
    sun = DirectionalLight3D.new()
    sun.name = "SunMoonLighting"
    sun.light_color = Color("#ffe2c2")
    sun.light_energy = 0.80
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 70.0
    add_child(sun)
    city = CityBuilder.new()
    city.name = "AokawaDistrict"
    add_child(city)

func _simple_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide: bool = false) -> void:
    var m := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    m.mesh = box
    m.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.89
    m.material_override = mat
    parent.add_child(m)
    if collide:
        var b := StaticBody3D.new()
        b.collision_layer = 1
        b.position = pos
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        b.add_child(col)
        parent.add_child(b)

func _create_home() -> void:
    var room := CuratedInteriorsV11.new()
    room.name = "ApartmentInterior"
    room.position = Vector3(0, 0, 150)
    room.scale = Vector3(0.78, 1.0, 0.78)
    add_child(room)
    room.build_home(state.get("owned_items", []))

func _create_business_interiors() -> void:
    for place in ["便利店", "咖啡馆"]:
        var room := CuratedInteriorsV11.new()
        room.name = "MartInterior" if place == "便利店" else "CafeInterior"
        room.position = Vector3(0, 0, 190 if place == "便利店" else 222)
        room.scale = Vector3(0.78, 1.0, 0.78)
        add_child(room)
        room.build_shop(place)

func _create_player() -> void:
    player = CityPlayer.new()
    var p: Array = state.get("position", [-8.1, 0.2, 8.0])
    var saved := Vector3(float(p[0]), float(p[1]), float(p[2]))
    player.position = saved if saved.distance_to(Vector3.ZERO) < 100.0 else Vector3(0, 0.2, 14)
    # User is not allowed to spawn inside the exterior of a building.
    if absf(player.position.x) > 85.0 or absf(player.position.z) > 85.0:
        player.position = Vector3(0, 0.2, 14)
    if in_home:
        player.position = Vector3(0, 0.2, 154)
    add_child(player)

func _hud_card(panel: PanelContainer) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.11, 0.14, 0.78)
    style.border_color = Color(0.65, 0.74, 0.77, 0.16)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 11
    style.corner_radius_top_right = 11
    style.corner_radius_bottom_left = 11
    style.corner_radius_bottom_right = 11
    panel.add_theme_stylebox_override("panel", style)

func _make_hud_label(parent: Control, content: String, font_size: int, color: Color = FONT_COLOR) -> Label:
    var l := Label.new()
    l.text = content
    if localized_font != null:
        l.add_theme_font_override("font", localized_font)
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(l)
    return l

func _create_ui() -> void:
    var font_path := "res://art/fonts/NotoSansCJKsc-Regular.otf"
    if ResourceLoader.exists(font_path):
        localized_font = load(font_path) as Font
    else:
        var system_font := SystemFont.new()
        system_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC"])
        localized_font = system_font
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    var header := PanelContainer.new()
    header.position = Vector2(20, 17)
    header.custom_minimum_size = Vector2(320, 0)
    root.add_child(header)
    _hud_card(header)
    var top_pad := MarginContainer.new()
    top_pad.add_theme_constant_override("margin_left", 16)
    top_pad.add_theme_constant_override("margin_right", 16)
    top_pad.add_theme_constant_override("margin_top", 10)
    top_pad.add_theme_constant_override("margin_bottom", 11)
    header.add_child(top_pad)
    var top_col := VBoxContainer.new()
    top_col.add_theme_constant_override("separation", 3)
    top_pad.add_child(top_col)
    _make_hud_label(top_col, "同频之城  /  青川町", 22)
    ui_clock = _make_hud_label(top_col, "同步设备时间…", 16, Color("#d3dcd6"))
    ui_balance = _make_hud_label(top_col, "城币  ¥800", 17, Color("#e8c890"))

    var bottom := PanelContainer.new()
    bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 20.0
    bottom.offset_right = -20.0
    bottom.offset_top = -102.0
    bottom.offset_bottom = -16.0
    root.add_child(bottom)
    _hud_card(bottom)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 11)
    margin.add_theme_constant_override("margin_bottom", 11)
    bottom.add_child(margin)
    var stack := VBoxContainer.new()
    margin.add_child(stack)
    ui_place = _make_hud_label(stack, "正在探索街区", 17, Color("#eed3aa"))
    ui_hint = _make_hud_label(stack, "WASD 移动  /  鼠标转向  /  Shift 跑步  /  E 互动  /  Esc 释放鼠标", 14)
    ui_notice = _make_hud_label(stack, "", 13, Color("#c7dcd1"))

    var side := PanelContainer.new()
    side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    side.offset_left = -320
    side.offset_right = -18
    side.offset_top = 20
    side.offset_bottom = 195
    root.add_child(side)
    _hud_card(side)
    var side_pad := MarginContainer.new()
    side_pad.add_theme_constant_override("margin_left", 13)
    side_pad.add_theme_constant_override("margin_right", 13)
    side_pad.add_theme_constant_override("margin_top", 12)
    side.add_child(side_pad)
    ui_activity = _make_hud_label(side_pad, "今日生活计划", 15)
    photo_preview = TextureRect.new()
    photo_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    photo_preview.offset_left = -220.0
    photo_preview.offset_right = -20.0
    photo_preview.offset_top = 210.0
    photo_preview.offset_bottom = 330.0
    photo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    photo_preview.visible = false
    photo_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(photo_preview)
    # UI does not take focus away from keyboard/mouse controls.
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if shop_open and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
            _purchase_furniture(int(event.physical_keycode) - int(KEY_1))
            return
        if job_mode != "" and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
            _job_answer(int(event.physical_keycode) - int(KEY_1) + 1)
            return
        if dialogue_npc >= 0 and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
            _dialogue_choice(int(event.physical_keycode) - int(KEY_1) + 1)
            return
    if shop_open and (event.is_action_pressed("interact") or event.is_action_pressed("exit_interior") or event.is_action_pressed("ui_cancel")):
        shop_open = false
        return
    if event.is_action_pressed("journal"):
        journal_open = not journal_open
        _notify("已%s生活日志，右侧查看。" % ("打开" if journal_open else "关闭"), 3.0)
        return
    if job_mode != "" or dialogue_npc >= 0:
        return
    if event.is_action_pressed("interact"):
        _interact()
    elif event.is_action_pressed("job"):
        _begin_job()
    elif event.is_action_pressed("buy"):
        _buy_item()
    elif event.is_action_pressed("parcel"):
        _parcel_pickup()
    elif event.is_action_pressed("photo"):
        _take_photo()
    elif event.is_action_pressed("rest"):
        _rest()
    elif event.is_action_pressed("exit_interior"):
        if in_home:
            _leave_home()
        elif indoor_place != "":
            _leave_business()

func _interact() -> void:
    if in_home:
        _leave_home()
        return
    if indoor_place != "":
        _leave_business()
        return
    match current_interaction:
        "公寓":
            _save_progress()
            in_home = true
            state["at_home"] = true
            player.velocity = Vector3.ZERO
            player.position = Vector3(0, 0.2, 154)
            _save_progress()
            _notify("回家了。按 R 休息，Q 或 E 返回街区。", 5.0)
        "便利店", "咖啡馆":
            _enter_business(current_interaction)
        "生活商店":
            _open_shop()
        "委托板":
            journal_open = true
            _notify("委托板：完成每日打工、交友、摄影；K 在便利店领取配送单。", 6.0)
        "河边取件箱":
            var candidate: Dictionary = state.duplicate(true)
            if LifeContent.finish_delivery(candidate, LifeContent.date_key()) and _commit_state(candidate):
                _notify("送件成功！配送报酬 +90 城币。", 6.0)
            else:
                _notify("取件箱：还没有需要投递的包裹。去便利店按 K 接单。", 5.0)
        "公园":
            _notify("河畔公园：R 休息，P 拍照，委托板可以查看今日生活计划。", 6.0)
        "居民":
            if near_npc >= 0:
                dialogue_npc = near_npc
                journal_open = false
                _notify("你遇到了%s，可以用数字键选择对话。" % LifeContent.RESIDENTS[near_npc], 5.0)
        _:
            _notify("靠近场所入口、居民或委托板，再按 E。", 3.0)

func _enter_business(place: String) -> void:
    if not _save_progress():
        return
    indoor_place = place
    player.velocity = Vector3.ZERO
    player.position = Vector3(0, 0.2, 192.5 if place == "便利店" else 224.5)
    _notify("已进入%s。按 J 体验工作，Q 或 E 离开。" % place, 6.0)

func _leave_business() -> void:
    var place: String = indoor_place
    indoor_place = ""
    player.velocity = Vector3.ZERO
    player.position = Vector3(-11.4, 0.2, -14) if place == "便利店" else Vector3(11.4, 0.2, -14)
    _save_progress()
    _notify("离开%s。" % place, 3.0)

func _leave_home() -> void:
    in_home = false
    state["at_home"] = false
    player.velocity = Vector3.ZERO
    player.position = Vector3(-10.7, 0.2, 13)
    _notify("已回到青川町街道。", 3.0)
    _save_progress()

func _begin_job() -> void:
    if job_mode != "" or in_home or current_interaction not in LifeContent.JOB_TASKS:
        return
    if int(state.get("energy", 0)) < 12:
        _notify("精力不足，回家或去公园按 R 休息。", 5.0)
        return
    job_mode = current_interaction
    job_step = 0
    job_correct = 0
    job_seconds = 45.0
    job_pending_id = "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
    journal_open = false
    _notify("%s工作开始！看右上方订单，用 1 / 2 / 3 作答。" % job_mode, 5.0)

func _job_answer(answer: int) -> void:
    if job_mode == "" or job_step >= 3:
        return
    var tasks: Array = LifeContent.JOB_TASKS[job_mode]
    if answer == int(tasks[job_step][2]):
        job_correct += 1
    job_step += 1
    if job_step < tasks.size():
        return
    var candidate: Dictionary = state.duplicate(true)
    var wage: int = LifeContent.job_finish(candidate, job_pending_id, job_mode, job_correct, LifeContent.date_key())
    var place: String = job_mode
    job_mode = ""
    job_seconds = -1.0
    if wage > 0 and _commit_state(candidate):
        _notify("%s工作完成：答对 %d/3，工资 +%d，首次工作另有目标奖励。" % [place, job_correct, wage], 7.0)
    else:
        _notify("工作未结算：检查存档权限或余额上限。", 6.0)

func _dialogue_choice(choice: int) -> void:
    if dialogue_npc < 0 or dialogue_npc >= LifeContent.RESIDENTS.size():
        dialogue_npc = -1
        return
    var resident: String = LifeContent.RESIDENTS[dialogue_npc]
    dialogue_npc = -1
    if choice == 1:
        var candidate: Dictionary = state.duplicate(true)
        var added: bool = LifeContent.talk(candidate, resident, LifeContent.date_key())
        if added and _commit_state(candidate):
            _notify("%s：%s  好感度 +1，心情 +5。" % [resident, _resident_line(resident)], 7.0)
        elif not added:
            _notify("%s：今天已经聊过了，明天再来看看吧。" % resident, 6.0)
    elif choice == 2:
        _notify("%s：%s" % [resident, _resident_hint(resident)], 7.0)
    else:
        _notify("你向%s挥手道别。" % resident, 3.0)

func _resident_line(resident: String) -> String:
    var lines: Dictionary = {
        "小遥": "下班后沿着河边走走，整个人都轻松了。",
        "拓海": "我在学做咖啡，奶泡真的不容易。",
        "晴子": "我把旧书换给邻居，认识了好多新朋友。",
        "阿诚": "今天送货走了好多路，发现一家新店。",
        "美咲": "正在拍青川町的街景，夜晚也很好看。",
        "木村": "偶尔停下看看公园，比埋头工作好多了。"
    }
    return str(lines.get(resident, "今天也有新的事情发生。"))

func _resident_hint(resident: String) -> String:
    if resident in ["小遥", "美咲", "木村"]:
        return "试试到公园和路口拍照，完成每日摄影目标。"
    return "便利店可以接配送订单，河边有个取件箱。"

func _parcel_pickup() -> void:
    if in_home or current_interaction != "便利店" or job_mode != "":
        _notify("到便利店门口或店内，按 K 领取配送委托。", 4.0)
        return
    var candidate: Dictionary = state.duplicate(true)
    if LifeContent.begin_delivery(candidate, LifeContent.date_key()) and _commit_state(candidate):
        _notify("已领包裹！沿街向北，到河边取件箱按 E，报酬 90。", 7.0)
    else:
        _notify("今天的配送已经接过，或尚未完成。查看 T 生活日志。", 5.0)

func _take_photo() -> void:
    if in_home or indoor_place != "":
        return
    for spot in photo_spots:
        if player.global_position.distance_to(photo_spots[spot]) < 5.0:
            var candidate: Dictionary = state.duplicate(true)
            if str(spot) in state.get("photo_spots", []):
                _notify("这处风景今天已经拍过了。", 4.0)
                return
            # A real photo is taken from the current 3D viewport and saved locally.
            var image: Image = get_viewport().get_texture().get_image()
            if image == null or image.is_empty():
                _notify("相机还没准备好，稍后再试。", 4.0)
                return
            var folder: String = "user://photos"
            DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
            var photo_file: String = "%s/%s_%d.png" % [folder, str(spot), Time.get_unix_time_from_system()]
            if image.save_png(photo_file) != OK:
                _notify("拍照保存失败，请检查浏览器本地存储。", 5.0)
                return
            if LifeContent.photo(candidate, str(spot), LifeContent.date_key()) and _commit_state(candidate):
                photo_preview.texture = ImageTexture.create_from_image(image)
                photo_preview.visible = true
                photo_preview_time = 5.0
                _notify("记录了一张街景照片（%d/2）。每日完成两处奖励 +25 城币。" % mini(2, state["photo_spots"].size()), 6.0)
            else:
                _notify("这处风景今天已经拍过了。", 4.0)
            return
    _notify("靠近公园河岸、路口或生活商店橱窗，再按 P 拍照。", 5.0)

func _rest() -> void:
    if not in_home and current_interaction != "公园":
        _notify("在家里或公园才能休息。", 3.0)
        return
    var candidate: Dictionary = state.duplicate(true)
    LifeContent.rest(candidate, in_home)
    if _commit_state(candidate):
        _notify("休息完成：精力 %d，心情 %d。" % [state["energy"], state["mood"]], 5.0)

func _open_shop() -> void:
    if in_home or indoor_place != "":
        return
    shop_open = true
    journal_open = false
    _notify("生活商店：在右侧菜单按数字购买家具，E 返回。", 5.0)

func _purchase_furniture(index: int) -> void:
    if not shop_open or index < 0 or index >= FURNITURE.size():
        return
    var product: Array = FURNITURE[index]
    var candidate: Dictionary = state.duplicate(true)
    if not CitySave.purchase(candidate, str(product[0]), int(product[2])):
        _notify("无法购买：余额不足，或已经拥有此件家具。", 4.0)
        return
    LifeContent.note(candidate, "买了%s，回家可以看到新家具。" % str(product[1]))
    if not _commit_state(candidate):
        _notify("保存失败，本次购买没有生效。", 5.0)
        return
    var room := get_node_or_null("ApartmentInterior") as CuratedInteriorsV11
    if room != null:
        room.add_purchased_item(str(product[0]))
    shop_open = false
    _notify("购买了%s，支付 %d 城币。回家看看新布置！" % [product[1], product[2]], 6.0)

func _buy_item() -> void:
    if in_home:
        return
    if current_interaction == "生活商店":
        _open_shop()
        return
    if current_interaction != "咖啡馆":
        return
    var candidate: Dictionary = state.duplicate(true)
    if not CitySave.spend(candidate, 18):
        _notify("余额不足，无法购买咖啡。", 4.0)
        return
    candidate["energy"] = mini(100, int(candidate.get("energy", 50)) + 8)
    candidate["mood"] = mini(100, int(candidate.get("mood", 50)) + 6)
    LifeContent.note(candidate, "在 KAWA COFFEE 喝了一杯咖啡。")
    if _commit_state(candidate):
        _notify("咖啡 -18 城币；精力 +8，心情 +6。", 5.0)
    else:
        _notify("消费存档失败，余额没有变化。", 5.0)

func _nearest_place() -> String:
    near_npc = -1
    if in_home:
        return ""
    if indoor_place != "":
        return indoor_place
    var result := ""
    var distance := INTERACTION_RADIUS
    for label in poi:
        var d: float = player.global_position.distance_to(poi[label])
        if d < distance:
            distance = d
            result = label
    if city != null:
        for i in range(city.npc_figures.size()):
            var resident: Node3D = city.npc_figures[i]
            var d: float = player.global_position.distance_to(resident.global_position)
            if resident.visible and d < minf(distance, 2.75):
                near_npc = i
                distance = d
                result = "居民"
    return result

func _notify(message: String, seconds: float = 4.0) -> void:
    if ui_notice != null:
        ui_notice.text = message
    notice_time = seconds

func _process(delta: float) -> void:
    gameplay_time += delta
    autosave_time += delta
    web_qa_tick += delta
    notice_time -= delta
    photo_preview_time -= delta
    if photo_preview != null and photo_preview_time <= 0.0:
        photo_preview.visible = false
    if notice_time <= 0.0 and ui_notice != null:
        ui_notice.text = ""
    current_interaction = _nearest_place()
    if shop_open and current_interaction != "生活商店":
        shop_open = false
    if in_home:
        ui_place.text = "你的公寓 · 私人生活空间"
        ui_hint.text = "R 休息  ·  Q / E 返回街道  ·  T 日志"
    elif indoor_place != "":
        ui_place.text = "室内 · %s" % indoor_place
        ui_hint.text = "J 工作  ·  B 消费  ·  K 接配送（便利店）  ·  Q / E 出门"
    elif current_interaction != "":
        ui_place.text = "附近：%s%s" % [current_interaction, (" · " + LifeContent.RESIDENTS[near_npc]) if near_npc >= 0 else ""]
        ui_hint.text = "E 互动 · J 工作 · K 配送 · B 购买 · P 拍照 · R 休息 · T 日志"
    else:
        ui_place.text = "青川町 · 一起过普通的每一天"
        ui_hint.text = "WASD 移动  ·  Shift 跑步  ·  E 互动  ·  T 今日目标  ·  P 摄影"
    if job_mode != "":
        job_seconds -= delta
        if job_seconds <= 0.0:
            job_mode = ""
            job_seconds = -1.0
            _notify("订单超时：本次未获得工资，可以重新尝试。", 6.0)
    if shop_open:
        ui_activity.text = "生活商店 / 选择家具\n1 阅读灯    120 城币\n2 棉麻地毯 180 城币\n3 绿植角    240 城币\n4 木书架    390 城币\n5 桌面电脑 620 城币\nE 返回  ·  已拥有 %d/5" % mini(5, state.get("owned_items", []).size())
    elif job_mode != "":
        var task: Array = LifeContent.JOB_TASKS[job_mode][job_step]
        ui_activity.text = "%s · 订单 %d/3
%s
%s
正确：%d   剩余：%d 秒" % [job_mode, job_step + 1, task[0], task[1], job_correct, maxi(0, int(job_seconds))]
    elif dialogue_npc >= 0:
        var resident: String = LifeContent.RESIDENTS[dialogue_npc]
        ui_activity.text = "与%s交谈
%s
1 聊聊近况（提升关系）
2 询问街区线索
3 告别" % [resident, _resident_line(resident)]
    elif journal_open:
        var entries: Array = state.get("journal", [])
        ui_activity.text = "生活日志 · T 关闭
%s" % ("
".join(entries.slice(0, 5)) if entries.size() > 0 else "今天还没有记录。")
    else:
        var delivery: String = "正在配送 → 河边取件箱" if state.get("delivery_active", false) else ("已完成" if LifeContent.completed(state, "delivery") else "便利店按 K 可接配送单")
        ui_activity.text = "今日生活计划 · T 查看日志
%s
配送：%s
精力 %d / 心情 %d" % [LifeContent.task_line(state), delivery, state.get("energy", 78), state.get("mood", 68)]
    ui_balance.text = "钱包：%d 城币  ｜  工作 %d 次  ·  送件 %d" % [state["balance"], state["jobs_completed"], state.get("deliveries", 0)]
    var clock_data := WorldClock.snapshot()
    ui_clock.text = WorldClock.display_text() + ("  夜间" if WorldClock.is_night() else "  白天")
    if clock_data["second"] != last_world_clock_second:
        last_world_clock_second = clock_data["second"]
        _update_sun()
        var candidate: Dictionary = state.duplicate(true)
        if LifeContent.prepare_day(candidate, LifeContent.date_key()):
            if _commit_state(candidate):
                _notify("新的一天开始了，今日计划已更新。", 6.0)
    if city != null:
        city.update_ambience(WorldClock.daylight(), gameplay_time)
    if autosave_time >= AUTOSAVE_SECONDS:
        autosave_time = 0.0
        _save_progress()
    if web_qa_mode and web_qa_tick >= 0.25:
        web_qa_tick = 0.0
        _emit_web_qa()

func _update_sun() -> void:
    if sun == null or ambient_env == null:
        return
    var now: Dictionary = WorldClock.snapshot()
    var hr: float = float(now["hour"]) + float(now["minute"]) / 60.0
    var daylight: float = WorldClock.daylight()
    var azimuth: float = (hr / 24.0) * TAU
    var elevation: float = maxf(-0.2, sin((hr - 6.0) / 12.0 * PI))
    sun.rotation = Vector3(-0.12 - elevation * 1.25, azimuth, 0.0)
    sun.light_energy = 0.035 + daylight * 0.83
    if sky_material != null:
        sky_material.sky_top_color = Color("#0a1624").lerp(Color("#7c98aa"), daylight)
        sky_material.sky_horizon_color = Color("#293c4a").lerp(Color("#c7c5b9"), daylight)
    sun.light_color = Color("#ffd0a3").lerp(Color("#fff1d9"), daylight)
    ambient_env.environment.ambient_light_energy = 0.11 + daylight * 0.14

func _commit_state(candidate: Dictionary) -> bool:
    if player != null and not in_home and indoor_place == "":
        candidate["position"] = [player.position.x, player.position.y, player.position.z]
    candidate["at_home"] = in_home
    if not qa_mode and not CitySave.write_save(candidate):
        return false
    state = candidate
    return true

func _save_progress() -> bool:
    if state.is_empty():
        return false
    if not _commit_state(state.duplicate(true)):
        _notify("存档失败。请检查本地存储权限。", 5.0)
        return false
    return true

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_progress()
        get_tree().quit()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _update_sun()
    elif what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()

func _exit_tree() -> void:
    if player != null:
        _save_progress()