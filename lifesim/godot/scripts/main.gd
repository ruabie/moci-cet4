extends Node3D

const AUTOSAVE_SECONDS: float = 12.0
const INTERACTION_RADIUS: float = 5.5
const JOB_SECONDS: float = 12.0
const JOB_REWARD: int = 70
const FONT_COLOR = Color("#edf3ec")

var city: CityBuilder
var player: CityPlayer
var state: Dictionary = {}
var sun: DirectionalLight3D
var ambient_env: WorldEnvironment
var sky_material: ProceduralSkyMaterial
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
var job_time_left: float = -1.0
var job_pending_id: String = ""
var in_home: bool = false
var last_location: String = ""
var last_world_clock_second: int = -1
var current_interaction: String = ""
var poi: Dictionary = {
    "公寓": Vector3(-11.4, 0, 13),
    "便利店": Vector3(-11.4, 0, -14),
    "咖啡馆": Vector3(11.4, 0, -14),
    "生活商店": Vector3(11.4, 0, 15),
    "公园": Vector3(-11, 0, 48)
}

func _ready() -> void:
    _configure_input()
    state = CitySave.read_save()
    _create_world()
    _create_home()
    _create_player()
    _create_ui()
    _update_sun()
    if CitySave.last_load_warning != "":
        _notify(CitySave.last_load_warning, 12.0)
    else:
        _notify("欢迎来到青川町。世界时间与你的设备同步。", 6.0)

func _configure_input() -> void:
    var keys := {
        "move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "run": [KEY_SHIFT], "interact": [KEY_E], "job": [KEY_J],
        "buy": [KEY_B], "exit_interior": [KEY_Q]
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
    sky_mat.sky_top_color = Color("#5a83a6")
    sky_mat.sky_horizon_color = Color("#d7c7ac")
    sky_mat.ground_bottom_color = Color("#525c57")
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.ambient_light_energy = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    ambient_env.environment = env
    add_child(ambient_env)
    sun = DirectionalLight3D.new()
    sun.name = "SunMoonLighting"
    sun.light_color = Color("#ffe2c2")
    sun.light_energy = 1.5
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
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
    # Separate spatial interior ensures no black-screen scene swaps or data loss.
    var room := Node3D.new()
    room.name = "ApartmentInterior"
    room.position = Vector3(0, 0, 150)
    add_child(room)
    _simple_box(room, Vector3(0, -0.14, 0), Vector3(16, 0.26, 15), Color("#b6a997"), true)
    _simple_box(room, Vector3(-8.1, 3.1, 0), Vector3(0.2, 6.2, 15), Color("#f2ece2"), true)
    _simple_box(room, Vector3(8.1, 3.1, 0), Vector3(0.2, 6.2, 15), Color("#eee5da"), true)
    _simple_box(room, Vector3(0, 3.1, -7.6), Vector3(16, 6.2, 0.2), Color("#e5d9cb"), true)
    _simple_box(room, Vector3(0, 3.1, 7.6), Vector3(16, 6.2, 0.2), Color("#f0e8db"), true)
    _simple_box(room, Vector3(-3.0, 0.55, -3.4), Vector3(4.0, 1.1, 2.7), Color("#c7b8aa"))
    _simple_box(room, Vector3(-3.0, 1.13, -3.6), Vector3(4.0, 0.19, 2.6), Color("#f2eee9"))
    _simple_box(room, Vector3(2.5, 0.84, -3.6), Vector3(2.4, 0.12, 1.3), Color("#8c705a"))
    _simple_box(room, Vector3(2.5, 0.43, -3.6), Vector3(2.2, 0.75, 0.10), Color("#6a564c"))
    _simple_box(room, Vector3(4.2, 1.2, -7.45), Vector3(3.8, 2.2, 0.1), Color("#69899a"))
    if "desk_lamp" in state.get("owned_items", []):
        _simple_box(room, Vector3(2.5, 1.45, -3.6), Vector3(0.28, 0.95, 0.28), Color("#e5ca89"))
    var light := OmniLight3D.new()
    light.position = Vector3(0, 4.7, 0)
    light.light_color = Color("#ffe8c2")
    light.light_energy = 1.9
    light.omni_range = 17
    room.add_child(light)

func _create_player() -> void:
    player = CityPlayer.new()
    var p: Array = state.get("position", [0.0, 1.0, 14.0])
    var saved := Vector3(float(p[0]), float(p[1]), float(p[2]))
    player.position = saved if saved.distance_to(Vector3.ZERO) < 100.0 else Vector3(0, 0.2, 14)
    # User is not allowed to spawn inside the exterior of a building.
    if absf(player.position.x) > 85.0 or absf(player.position.z) > 85.0:
        player.position = Vector3(0, 0.2, 14)
    add_child(player)

func _make_hud_label(parent: Control, content: String, font_size: int, color: Color = FONT_COLOR) -> Label:
    var l := Label.new()
    l.text = content
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    parent.add_child(l)
    return l

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    var header := PanelContainer.new()
    header.position = Vector2(20, 17)
    header.custom_minimum_size = Vector2(340, 0)
    root.add_child(header)
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
    bottom.offset_top = -112.0
    bottom.offset_bottom = -20.0
    root.add_child(bottom)
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
    side.offset_bottom = 95
    root.add_child(side)
    var side_pad := MarginContainer.new()
    side_pad.add_theme_constant_override("margin_left", 13)
    side_pad.add_theme_constant_override("margin_right", 13)
    side_pad.add_theme_constant_override("margin_top", 12)
    side.add_child(side_pad)
    ui_activity = _make_hud_label(side_pad, "正在体验 3D 街区原型", 15)
    # UI does not take focus away from keyboard/mouse controls.
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _interact()
    elif event.is_action_pressed("job"):
        if current_interaction == "便利店" and job_time_left < 0.0 and not in_home:
            job_time_left = JOB_SECONDS
            job_pending_id = "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
            _notify("收银兼职开始：完成 12 秒店内工作可获得 70 城币。", 5.0)
    elif event.is_action_pressed("buy"):
        _buy_item()
    elif event.is_action_pressed("exit_interior") and in_home:
        _leave_home()

func _interact() -> void:
    if in_home:
        _leave_home()
        return
    match current_interaction:
        "公寓":
            in_home = true
            player.velocity = Vector3.ZERO
            player.position = Vector3(0, 0.2, 154)
            _notify("回家了。按 Q 或 E 返回街区。", 4.0)
        "便利店":
            _notify("AOI MART 营业中：按 J 开始简单收银兼职。", 4.0)
        "咖啡馆":
            _notify("KAWA COFFEE：按 B 购买咖啡（18 城币）。", 4.0)
        "生活商店":
            _notify("生活商店：按 B 购买公寓台灯（120 城币）。", 5.0)
        "公园":
            _notify("河畔公园。你可以在这里休息、散步，暂时没有强制任务。", 5.0)
        "路人":
            var hour: int = int(WorldClock.snapshot()["hour"])
            _notify("路人：%s" % ("今天也要记得好好休息。" if hour >= 18 else "这条街早晨的咖啡很不错。"), 5.0)
        _:
            _notify("靠近商店、公寓或公园入口，再按 E 互动。", 3.0)

func _leave_home() -> void:
    in_home = false
    player.velocity = Vector3.ZERO
    player.position = Vector3(-10.7, 0.2, 13)
    _notify("已回到青川町街道。", 3.0)
    _save_progress()

func _buy_item() -> void:
    if in_home:
        return
    var item: String = ""
    var cost: int = 0
    var name_cn: String = ""
    if current_interaction == "生活商店":
        item = "desk_lamp"
        cost = 120
        name_cn = "台灯"
    elif current_interaction == "咖啡馆":
        item = "coffee_%d" % Time.get_ticks_usec()
        cost = 18
        name_cn = "咖啡"
    else:
        return
    if CitySave.purchase(state, item, cost):
        _save_progress()
        _notify("已购买%s，支付 %d 城币。" % [name_cn, cost], 4.0)
        if item == "desk_lamp":
            # Rebuild the room visual locally without duplicating the floor.
            var room := get_node_or_null("ApartmentInterior")
            if room != null:
                _simple_box(room, Vector3(2.5, 1.45, -3.6), Vector3(0.28, 0.95, 0.28), Color("#e5ca89"))
    else:
        _notify("无法购买：余额不足，或已经拥有这件家具。", 4.0)

func _nearest_place() -> String:
    if in_home:
        return ""
    var result := ""
    var distance := INTERACTION_RADIUS
    for label in poi:
        var d: float = player.global_position.distance_to(poi[label])
        if d < distance:
            distance = d
            result = label
    if city != null and city.npc_figures.size() > 0:
        for resident in city.npc_figures:
            if resident.visible and player.global_position.distance_to(resident.global_position) < minf(distance, 2.5):
                result = "路人"
                distance = 2.5
    return result

func _notify(message: String, seconds: float = 4.0) -> void:
    if ui_notice != null:
        ui_notice.text = message
    notice_time = seconds

func _process(delta: float) -> void:
    gameplay_time += delta
    autosave_time += delta
    notice_time -= delta
    if notice_time <= 0.0 and ui_notice != null:
        ui_notice.text = ""
    current_interaction = _nearest_place()
    if in_home:
        ui_place.text = "你的公寓 · 自由布置的私人空间"
        ui_hint.text = "Q / E 返回街道  ·  Esc 释放鼠标"
    elif current_interaction != "":
        ui_place.text = "附近：%s" % current_interaction
        ui_hint.text = "E 互动  ·  便利店 J 打工  ·  咖啡馆/生活商店 B 购买"
    else:
        ui_place.text = "青川町 · 自由探索"
        ui_hint.text = "WASD 移动  ·  鼠标转向  ·  Shift 跑步  ·  E 互动  ·  Esc 释放鼠标"
    if job_time_left >= 0.0:
        job_time_left -= delta
        ui_activity.text = "便利店兼职进行中  %02d 秒" % maxi(0, int(ceil(job_time_left)))
        if job_time_left <= 0.0:
            job_time_left = -1.0
            if CitySave.pay_job_once(state, job_pending_id, JOB_REWARD):
                _save_progress()
                _notify("兼职完成！工资 +70 城币。", 5.0)
            else:
                _notify("结算未通过，避免重复领取工资。", 5.0)
    else:
        ui_activity.text = "工作 · 购物 · 漫游 · 生活"
    ui_balance.text = "钱包：%d 城币  ｜  已工作 %d 次" % [state["balance"], state["jobs_completed"]]
    var clock_data := WorldClock.snapshot()
    ui_clock.text = WorldClock.display_text() + ("  夜间" if WorldClock.is_night() else "  白天")
    if clock_data["second"] != last_world_clock_second:
        last_world_clock_second = clock_data["second"]
        _update_sun()
    if city != null:
        city.update_ambience(WorldClock.daylight(), gameplay_time)
    if autosave_time >= AUTOSAVE_SECONDS:
        autosave_time = 0.0
        _save_progress()

func _update_sun() -> void:
    if sun == null or ambient_env == null:
        return
    var now: Dictionary = WorldClock.snapshot()
    var hr: float = float(now["hour"]) + float(now["minute"]) / 60.0
    var daylight: float = WorldClock.daylight()
    var azimuth: float = (hr / 24.0) * TAU
    var elevation: float = maxf(-0.2, sin((hr - 6.0) / 12.0 * PI))
    sun.rotation = Vector3(-0.12 - elevation * 1.25, azimuth, 0.0)
    sun.light_energy = 0.03 + daylight * 1.25
    if sky_material != null:
        sky_material.sky_top_color = Color("#0a1624").lerp(Color("#5a83a6"), daylight)
        sky_material.sky_horizon_color = Color("#293c4a").lerp(Color("#d7c7ac"), daylight)
    sun.light_color = Color("#ffd0a3").lerp(Color("#fff2de"), daylight)
    ambient_env.environment.ambient_light_energy = 0.23 + daylight * 0.68

func _save_progress() -> void:
    # Do not write a null player or the faraway interior coordinate.
    if player == null or in_home:
        return
    state["position"] = [player.position.x, player.position.y, player.position.z]
    if not CitySave.write_save(state):
        _notify("存档失败。请检查本地存储权限。", 5.0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_progress()
        get_tree().quit()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _update_sun()
    elif what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()

func _exit_tree() -> void:
    if player != null and not in_home:
        _save_progress()
