extends SceneTree

# V0.22 is independent diagnostic proof: rest-basis retarget + shoe-ground
# proxy. Production procedural movement never replaced without art approval.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("V22 CONTACT FAIL: "+message)
    quit(1)

func _capture(label: String, camera: Camera3D, player: CityPlayer) -> bool:
    camera.global_position = player.global_position + Vector3(2.0, 2.0, -4.0)
    camera.look_at(player.global_position + Vector3.UP * 1.05)
    for tick in range(2):
        await process_frame
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width() < 720:
        return false
    return img.save_png(ProjectSettings.globalize_path("res://tests/v22_"+label+".png")) == OK

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var source: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var main: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source == null or main == null:
        _fail("missing pinned animation / main scene")
        return
    var original: Node = source.instantiate()
    var city: Node3D = main.instantiate() as Node3D
    root.add_child(city)
    await process_frame
    await physics_frame
    var player: CityPlayer = city.get_node_or_null("Player") as CityPlayer
    if player == null or player.rig == null or not player.animation_verified:
        _fail("real player rig absent")
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0,.2,-10.0)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = city.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var calibration: Dictionary = FootContactV22.setup(player)
    if not bool(calibration.get("ok", false)):
        _fail("shoe bind calibration: "+JSON.stringify(calibration))
        return
    var result: Dictionary = AnimationRetargetV22.install(original,player.rig,player)
    if not bool(result.get("ok", false)):
        _fail("rest axis retarget: "+JSON.stringify(result))
        return
    var driver: AnimationPlayer = result["player"] as AnimationPlayer
    var camera := Camera3D.new()
    camera.fov = 55.0
    city.add_child(camera)
    camera.current = true
    var poses: Dictionary = {}
    var correction_max: float = 0.0
    var clips: Array[String] = ["idle","walk","run"]
    for name in clips:
        var clip: Animation = driver.get_animation("v22/"+name)
        if clip == null or clip.length <= .25:
            _fail("missing real imported motion clip "+name)
            return
        var sample_metrics: Array[Dictionary] = []
        for moment in [0.12, .67]:
            # Reset to original visual root every capture; no accumulated Y
            # drift is allowed and the base physics capsule is never moved.
            player.character_visual.position.y = 0.0
            driver.play("v22/"+name)
            driver.seek(minf(clip.length * float(moment),clip.length-.02),true)
            # Freeze the sampled pose before physics-ray grounding, otherwise
            # AnimationPlayer advances while screenshots await process_frame
            # and its shoes no longer correspond to the saved contact metrics.
            driver.stop(true)
            await process_frame
            var grounded: Dictionary = FootContactV22.lock_preview_height(player,calibration)
            if not bool(grounded.get("ok",false)):
                _fail(name+" grounded pose: "+JSON.stringify(grounded))
                return
            var displacement: float = absf(float(grounded["root_height_correction_m"]))
            correction_max = maxf(correction_max, displacement)
            if float(grounded["foot_ankle_horizontal_spread_m"]) > 1.55:
                _fail(name+" feet splayed farther than 1.55m: "+JSON.stringify(grounded))
                return
            var label: String = name+("_a" if float(moment) < .5 else "_b")
            if not await _capture(label,camera,player):
                _fail("render screenshot "+label+" missing")
                return
            sample_metrics.append(grounded)
            driver.stop()
        poses[name] = sample_metrics
    var metrics: Dictionary = {
        "test":"Godot 4.7.2 source and destination bone-rest rotation frame corrections + approximate two-ankle shoe-ground contact",
        "source_clips":result["source_clips"],
        "shared_bones":result["shared_bones"],
        "mapped_rotation_tracks":result["tracks"],
        "shoe_calibration":calibration,
        "pose_metrics":poses,
        "max_root_correction_metres":snappedf(correction_max,.001),
        "screenshots":["v22_idle_a.png","v22_idle_b.png","v22_walk_a.png",
            "v22_walk_b.png","v22_run_a.png","v22_run_b.png"],
        "scope":"QA only; original game locomotion untouched",
        "limits":["no real continuous input/video","two ankle height proxies != actual skinned shoe sole","no individually planted foot IK","no Windows GPU performance or subjective art approval"]
    }
    var path: String = ProjectSettings.globalize_path("res://tests/v22_contact_metrics.json")
    var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        _fail("cannot write metrics")
        return
    file.store_string(JSON.stringify(metrics,"\t")+"\n")
    file.close()
    print("V22 CONTACT PASS: "+JSON.stringify(metrics))
    original.queue_free()
    city.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode",false)
    quit(0)
