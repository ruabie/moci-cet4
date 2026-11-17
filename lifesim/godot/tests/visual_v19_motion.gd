extends SceneTree

# V0.19 diagnostic: real input-driven locomotion frames, never a substitute for
# a human walking/turning video or Windows GPU benchmark.
const PREFIX: String = "v19_"

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("V19 MOTION FAIL: " + message)
    Input.action_release("move_forward")
    Input.action_release("move_right")
    quit(1)

func _take_picture(label: String, camera: Camera3D, player: CityPlayer) -> bool:
    camera.global_position = player.global_position + Vector3(1.8, 1.95, -4.5)
    camera.look_at(player.global_position + Vector3.UP * 1.06, Vector3.UP)
    for frame in range(3):
        await process_frame
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width() < 720 or img.get_height() < 400:
        return false
    var path: String = ProjectSettings.globalize_path("res://tests/" + PREFIX + label + ".png")
    if img.save_png(path) != OK:
        return false
    print("V19 MOTION CAPTURE PASS: " + label)
    return true

func _step_physics(ticks: int) -> void:
    for i in range(ticks):
        await physics_frame

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("scene absent")
        return
    var scene: Node3D = packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame

    var player: CityPlayer = scene.get_node_or_null("Player") as CityPlayer
    if player == null or not player.animation_verified or player.rig == null:
        _fail("real skinned player not initialized")
        return
    var left_thigh: int = player.rig.find_bone(CharacterArtV18.joint_name(player.rig, "LeftThigh"))
    var right_thigh: int = player.rig.find_bone(CharacterArtV18.joint_name(player.rig, "RightThigh"))
    if left_thigh < 0 or right_thigh < 0:
        _fail("locomotion bones absent")
        return
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var camera := Camera3D.new()
    camera.fov = 55.0
    scene.add_child(camera)
    camera.current = true

    player.global_position = Vector3(0.0, 0.2, -10.0)
    player.velocity = Vector3.ZERO
    player.camera_yaw = 0.0
    await _step_physics(5)
    var origin: Vector3 = player.global_position

    # Both frames come from held real input and actual _physics_process; the
    # stance change is numerically asserted, not merely labelled as movement.
    Input.action_press("move_forward")
    await _step_physics(14)
    var pose_a: Quaternion = player.rig.get_bone_pose_rotation(left_thigh)
    if not await _take_picture("walking_early", camera, player):
        _fail("early walking PNG absent")
        return
    await _step_physics(22)
    var pose_b: Quaternion = player.rig.get_bone_pose_rotation(left_thigh)
    var stance_delta: float = pose_a.angle_to(pose_b)
    var displacement: float = player.global_position.distance_to(origin)
    if displacement < 1.4 or stance_delta < 0.12:
        _fail("no measurable gait change: travel=%s, thigh delta=%s" % [displacement, stance_delta])
        return
    if not await _take_picture("walking_late", camera, player):
        _fail("late walking PNG absent")
        return

    # A forward-to-right input change must turn the actual visual model, not
    # just the collision body or camera. This does not prove absence of foot sliding.
    Input.action_release("move_forward")
    var before_turn: float = player.character_visual.rotation.y
    Input.action_press("move_right")
    await _step_physics(23)
    var turn_delta: float = absf(wrapf(player.character_visual.rotation.y - before_turn, -PI, PI))
    if turn_delta < 0.45:
        _fail("visible character did not turn with input: " + str(turn_delta))
        return
    if not await _take_picture("turning", camera, player):
        _fail("turn PNG absent")
        return

    Input.action_release("move_right")
    await _step_physics(23)
    var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
    if speed > 0.30 or player.anim_weight > 0.15:
        _fail("stop did not settle: velocity=%s, gait weight=%s" % [speed, player.anim_weight])
        return
    if not await _take_picture("stopped", camera, player):
        _fail("stopped PNG absent")
        return

    var proof: Dictionary = {
        "engine": "Godot 4.7.2",
        "test": "actual input-driven V0.19 movement and turn",
        "player_displacement_metres": snappedf(displacement, 0.001),
        "left_thigh_phase_angle_radians": snappedf(stance_delta, 0.001),
        "turn_angle_radians": snappedf(turn_delta, 0.001),
        "stop_horizontal_speed": snappedf(speed, 0.001),
        "stop_animation_weight": snappedf(player.anim_weight, 0.001),
        "screenshots": ["v19_walking_early.png", "v19_walking_late.png", "v19_turning.png", "v19_stopped.png"],
        "limits": ["no recorded video", "not independently art-approved", "Mesa software renderer != Windows GPU"]
    }
    var path: String = ProjectSettings.globalize_path("res://tests/v19_motion_metrics.json")
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _fail("motion metrics JSON could not be written")
        return
    file.store_string(JSON.stringify(proof, "\t") + "\n")
    file.close()
    print("V19 MOTION PASS: displacement=%s, left thigh delta=%s, turn=%s" % [displacement, stance_delta, turn_delta])
    scene.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)
