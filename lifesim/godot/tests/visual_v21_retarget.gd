extends SceneTree

# V0.21 pilot: demonstrate imported, licensed clips on the existing CC0 avatar
# without changing production player locomotion or replacing V0.20 gameplay.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    printerr("V21 RETARGET FAIL: " + reason)
    quit(1)

func _capture(label: String, camera: Camera3D, player: CityPlayer) -> bool:
    camera.global_position = player.global_position + Vector3(2.0, 2.0, -4.0)
    camera.look_at(player.global_position + Vector3.UP * 1.05)
    for i in range(3):
        await process_frame
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width() < 720:
        return false
    var path: String = ProjectSettings.globalize_path("res://tests/v21_" + label + ".png")
    if img.save_png(path) != OK:
        return false
    print("V21 RETARGET CAPTURE PASS:", label)
    return true

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var source: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    if source == null:
        _fail("licensed UAL1 GLB missing (build-time admission required)")
        return
    var imported: Node = source.instantiate()
    if imported == null:
        _fail("UAL animation scene could not instantiate")
        return
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var scene: Node3D = packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame
    var player: CityPlayer = scene.get_node_or_null("Player") as CityPlayer
    if player == null or player.rig == null or not player.animation_verified:
        _fail("existing player skinned rig not initialized")
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0, 0.2, -10)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var result: Dictionary = AnimationRetargetV21.install(imported, player.rig, player)
    if not bool(result.get("ok", false)):
        _fail("retarget aborted: " + JSON.stringify(result))
        return
    var driver: AnimationPlayer = result["player"] as AnimationPlayer
    var leg_index: int = player.rig.find_bone(CharacterArtV18.joint_name(player.rig, "LeftThigh"))
    if leg_index < 0:
        _fail("left thigh absent from actual avatar")
        return
    var camera := Camera3D.new()
    camera.fov = 55.0
    scene.add_child(camera)
    camera.current = true
    var changes: Dictionary = {}
    for name in ["idle", "walk", "run"]:
        var clip: Animation = driver.get_animation("v21/" + name)
        if clip == null or clip.length < .2:
            _fail("source retarget clip too short: " + name)
            return
        driver.play("v21/" + name)
        driver.seek(0.12, true)
        var q1: Quaternion = player.rig.get_bone_pose_rotation(leg_index)
        if not await _capture(name + "_a", camera, player):
            _fail(name+" initial frame not generated")
            return
        driver.seek(minf(clip.length*.67, clip.length-.02), true)
        var q2: Quaternion = player.rig.get_bone_pose_rotation(leg_index)
        if not await _capture(name + "_b", camera, player):
            _fail(name+" later frame not generated")
            return
        changes[name] = snappedf(q1.angle_to(q2), .001)
        if name != "idle" and float(changes[name]) < .035:
            _fail("licensed clip did not move actual player thigh: "+name+" "+str(changes[name]))
            return
        driver.stop()
    var metrics := {
        "license":"CC0-1.0",
        "source_clips":result["source_clips"],
        "shared_bones":result["shared_bones"],
        "mapped_tracks":result["tracks"],
        "measured_thigh_pose_deltas":changes,
        "evidence":["v21_idle_a.png","v21_idle_b.png",
            "v21_walk_a.png","v21_walk_b.png","v21_run_a.png","v21_run_b.png"],
        "scope":"Test preview only: production V0.20 movement intentionally unchanged",
        "unverified":["human art acceptance","foot sole contact",
             "real-time gait sliding","camera occlusion","Windows RTX3060 performance"]
    }
    var file: FileAccess = FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v21_retarget_metrics.json"), FileAccess.WRITE)
    if file == null:
        _fail("cannot write metrics")
        return
    file.store_string(JSON.stringify(metrics, "\t")+"\n")
    file.close()
    print("V21 RETARGET PASS:", JSON.stringify(metrics))
    imported.queue_free()
    scene.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)
