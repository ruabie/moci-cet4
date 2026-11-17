extends SceneTree

# Real Godot physics/input sequences; no synthetic posing for screenshots.
# Frames/GIF are diagnostic only, NOT a Windows test or final visual approval.
const FRAME_COUNT: int = 20
const TICKS_PER_FRAME: int = 3

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    Input.action_release("move_forward")
    printerr("V20 GAIT FAIL: " + message)
    quit(1)

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene_res: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene_res == null:
        _fail("main scene absent")
        return
    var scene: Node3D = scene_res.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame
    var player: CityPlayer = scene.get_node_or_null("Player") as CityPlayer
    if player == null or not player.animation_verified:
        _fail("actual skinned player did not initialize")
        return
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var camera := Camera3D.new()
    camera.fov = 55.0
    scene.add_child(camera)
    camera.current = true
    player.global_position = Vector3(0.0, .2, -10.0)
    player.camera_yaw = 0.0
    player.velocity = Vector3.ZERO
    for tick in range(8):
        await physics_frame

    var origin: Vector3 = player.global_position
    var initial_phase: float = player.anim_clock
    var lowest_clearance: float = INF
    var highest_clearance: float = -INF
    var highest_visual_lift: float = -INF
    var left_poses: Array[float] = []
    var clearances: Array[float] = []
    var frame_list: Array[String] = []

    var thigh_index: int = player.rig.find_bone(CharacterArtV18.joint_name(player.rig, "LeftThigh"))
    if thigh_index < 0:
        _fail("left-thigh bone absent")
        return
    Input.action_press("move_forward")
    for frame in range(FRAME_COUNT):
        for tick in range(TICKS_PER_FRAME):
            await physics_frame
        var clearance: float = player.foot_clearance_vs_idle()
        clearances.append(snappedf(clearance, 0.001))
        lowest_clearance = minf(lowest_clearance, clearance)
        highest_clearance = maxf(highest_clearance, clearance)
        highest_visual_lift = maxf(highest_visual_lift, player.gait_foot_lift)
        var q: Quaternion = player.rig.get_bone_pose_rotation(thigh_index)
        left_poses.append(snappedf(q.get_angle(), 0.001))

        # Track the subject relative to its actual physics position, same
        # framing throughout all captured poses (no screenshot staging).
        camera.global_position = player.global_position + Vector3(2.0, 2.15, -4.7)
        camera.look_at(player.global_position + Vector3.UP * 1.12, Vector3.UP)
        await process_frame
        var image: Image = root.get_viewport().get_texture().get_image()
        if image == null or image.get_width() < 720:
            _fail("render viewport missing at " + str(frame))
            return
        var filename: String = "v20_gait_%02d.png" % frame
        var path: String = ProjectSettings.globalize_path("res://tests/" + filename)
        if image.save_png(path) != OK:
            _fail("PNG write failed " + filename)
            return
        frame_list.append(filename)
    Input.action_release("move_forward")

    var distance: float = player.global_position.distance_to(origin)
    var radians: float = player.anim_clock - initial_phase
    var stats: Dictionary = {
        "source": "Godot 4.7.2 physics process + actual held move_forward",
        "capture_frames": FRAME_COUNT,
        "physics_ticks_per_capture": TICKS_PER_FRAME,
        "horizontal_travel_metres": snappedf(distance, 0.001),
        "gait_phase_advance_rad": snappedf(radians, 0.001),
        "cycle_distance_metres": CityPlayer.GAIT_CYCLE_METRES,
        "lowest_ankle_clearance_vs_idle_metres": snappedf(lowest_clearance, 0.001),
        "highest_ankle_clearance_vs_idle_metres": snappedf(highest_clearance, 0.001),
        "max_visual_floor_lift_metres": snappedf(highest_visual_lift, 0.001),
        "ankle_clearances": clearances,
        "thigh_pose_angles": left_poses,
        "frames": frame_list,
        "limitations": [
            "ankle bone != exact shoe mesh sole",
            "diagnostic Linux software rendering, not real Windows GPU",
            "still requires subjective animation and foot skate assessment"
        ]
    }
    var json_path: String = ProjectSettings.globalize_path("res://tests/v20_gait_metrics.json")
    var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
    if file == null:
        _fail("metrics file cannot open")
        return
    file.store_string(JSON.stringify(stats, "\t") + "\n")
    file.close()
    if distance < 2.8 or radians < TAU * 1.2:
        _fail("distance/phase not advancing: travel=%s phase=%s" % [distance, radians])
        return
    if lowest_clearance < -0.12:
        _fail("ankle below idle ground reference: " + str(lowest_clearance))
        return
    if highest_visual_lift > 0.11:
        _fail("visual root lifted too far: " + str(highest_visual_lift))
        return
    print("V20 GAIT PASS: distance=%s phase=%s clearance_min=%s lift_max=%s" % [
        distance, radians, lowest_clearance, highest_visual_lift
    ])
    scene.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)
