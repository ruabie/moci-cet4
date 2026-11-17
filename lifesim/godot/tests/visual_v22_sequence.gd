extends SceneTree

# 18 static-time samples from each *actual imported* Walk / Jog_Fwd clip.
# This is sequenced source animation, NOT proof of real-time Windows gameplay,
# smooth root motion or per-foot IK.
const SAMPLES: int = 18
func _initialize() -> void:
    call_deferred("_run")

func _fail(s: String) -> void:
    printerr("V22 SEQUENCE FAIL: "+s)
    quit(1)

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    var src: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var game: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if src == null or game == null:
        _fail("source animation/scene absent")
        return
    var source: Node = src.instantiate()
    var city: Node3D = game.instantiate() as Node3D
    root.add_child(city)
    await process_frame
    await physics_frame
    var player: CityPlayer = city.get_node_or_null("Player") as CityPlayer
    if player == null or player.rig == null:
        _fail("existing game player rig missing")
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0,.2,-10)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = city.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var calibrate: Dictionary = FootContactV22.setup(player)
    if not bool(calibrate.get("ok",false)):
        _fail("invalid bind-pose shoes "+JSON.stringify(calibrate))
        return
    var retarget: Dictionary = AnimationRetargetV22.install(source,player.rig,player)
    if not bool(retarget.get("ok",false)):
        _fail("retarget unavailable: "+JSON.stringify(retarget))
        return
    var driver: AnimationPlayer = retarget["player"] as AnimationPlayer
    var camera: Camera3D = Camera3D.new()
    city.add_child(camera)
    camera.current = true
    camera.fov = 52.0
    var all: Dictionary = {}
    var files: Array[String] = []
    for motion in ["walk","run"]:
        var clip: Animation = driver.get_animation("v22/"+motion)
        if clip == null or clip.length < .2:
            _fail("clip not retargeted "+motion)
            return
        var captures: Array[Dictionary] = []
        var last_height: float = INF
        var max_step: float = 0.0
        var min_height: float = INF
        var max_height: float = -INF
        for frame in range(SAMPLES):
            player.character_visual.position.y = 0.0
            driver.play("v22/"+motion)
            var sample_t: float = (float(frame)+.5)/float(SAMPLES)*clip.length
            driver.seek(sample_t, true)
            driver.stop(true) # Hold pose while rendering is slow under Mesa.
            await process_frame
            var grounded: Dictionary = FootContactV22.lock_preview_height(player,calibrate)
            if not bool(grounded.get("ok",false)):
                _fail(motion+" contact frame "+str(frame)+": "+JSON.stringify(grounded))
                return
            var offset: float = float(grounded["root_height_correction_m"])
            if last_height != INF:
                max_step = maxf(max_step,absf(offset-last_height))
            last_height = offset
            min_height = minf(min_height,offset)
            max_height = maxf(max_height,offset)
            camera.global_position = player.global_position + Vector3(1.4,1.65,-3.2)
            camera.look_at(player.global_position + Vector3.UP * 1.04)
            await process_frame
            var img: Image = root.get_viewport().get_texture().get_image()
            if img == null or img.get_width() < 720:
                _fail("no rendered viewport "+motion+" "+str(frame))
                return
            var filename: String = "v22_%s_seq_%02d.png" % [motion,frame]
            if img.save_png(ProjectSettings.globalize_path("res://tests/"+filename)) != OK:
                _fail("screenshot missing "+filename)
                return
            files.append(filename)
            captures.append({
                "sample_t_seconds":snappedf(sample_t,.001),
                "root_height_offset_m":offset,
                "residual_sole_gap_proxy_m":grounded["after_proxy_sole_gap_m"],
                "ankle_horizontal_spread_m":grounded["foot_ankle_horizontal_spread_m"]
            })
        all[motion] = {
            "samples":captures, "clip_duration_s":snappedf(clip.length,.001),
            "max_adjacent_root_y_delta_m":snappedf(max_step,.001),
            "root_offset_range_m":snappedf(max_height-min_height,.001),
            "max_offset_m":snappedf(max_height,.001),
            "min_offset_m":snappedf(min_height,.001),
        }
    var result: Dictionary = {
        "engine":"Godot 4.7.2",
        "test":"36 deterministic timeline samples of actual imported animation tracks on real player avatar with shoe-to-road proxy grounding",
        "motion":all,
        "screenshots":files,
        "sampling":"source clip timelines, not input-driven realtime, no guaranteed 60FPS",
        "production_locomotion_untouched":true,
        "limits":["one shoe proxy may touch ground while other skates","no IK",
            "camera/Windows gameplay unverified","source root clipping still visible"]
    }
    var file: FileAccess = FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v22_sequence_metrics.json"),FileAccess.WRITE)
    if file == null:
        _fail("cannot save animation sampling metrics")
        return
    file.store_string(JSON.stringify(result,"\t")+"\n")
    file.close()
    print("V22 SEQUENCE PASS: "+JSON.stringify({
        "frames":files.size(),
        "walk_height_range_m":all["walk"]["root_offset_range_m"],
        "run_height_range_m":all["run"]["root_offset_range_m"],
        "walk_step_max_m":all["walk"]["max_adjacent_root_y_delta_m"],
        "run_step_max_m":all["run"]["max_adjacent_root_y_delta_m"]
    }))
    source.queue_free()
    city.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode",false)
    quit(0)
