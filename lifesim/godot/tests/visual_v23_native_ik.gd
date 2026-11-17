extends SceneTree

# Only production locomotion still uses V0.20 procedural motion. This test
# renders the CC0 V0.22 retarget using 4.7's native TwoBoneIK3D for both legs.
# It validates actual Skeleton3D ankle positions, not a fake zero error proxy.
const SAMPLES: int = 8
func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    printerr("V23 TWO-BONE IK FAIL: "+msg)
    quit(1)

func _world_ankle(rig: Skeleton3D, side: String) -> Vector3:
    var i: int = rig.find_bone("Foot."+side)
    return rig.global_transform * rig.get_bone_global_pose(i).origin

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    var source_scene: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var city_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source_scene == null or city_scene == null:
        _fail("pinned UAL animation / real city scene absent")
        return
    var source: Node = source_scene.instantiate()
    var city: Node3D = city_scene.instantiate() as Node3D
    root.add_child(city)
    await process_frame
    await physics_frame
    var player: CityPlayer = city.get_node_or_null("Player") as CityPlayer
    if player == null or player.rig == null or not player.animation_verified:
        _fail("real game avatar has no actual skin/bones")
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0.0,0.2,-10.0)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = city.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var calibration: Dictionary = FootContactV22.setup(player)
    if not bool(calibration.get("ok",false)):
        _fail("pinned target rig shoe calibration invalid: "+JSON.stringify(calibration))
        return
    var r: Dictionary = AnimationRetargetV22.install(source,player.rig,player)
    if not bool(r.get("ok",false)):
        _fail("prior CC0 retarget missing: "+JSON.stringify(r))
        return
    var driver: AnimationPlayer = r["player"] as AnimationPlayer
    # Determine one *fixed* avatar-root height from true idle on real road.
    # Do not lower/raise the entire body again for every walk/run phase.
    driver.play("v22/idle")
    driver.seek(0.12,true)
    driver.stop(true)
    await process_frame
    var idle_align: Dictionary = FootContactV22.lock_preview_height(player,calibration)
    if not bool(idle_align.get("ok",false)):
        _fail("actual idle shoe/road alignment missing: "+JSON.stringify(idle_align))
        return
    var fixed_root_y: float = player.character_visual.position.y
    if absf(fixed_root_y) > 0.85:
        _fail("invalid fixed-root calibration "+str(fixed_root_y))
        return

    var setup: Dictionary = NativeFootIkV23.install(player)
    if not bool(setup.get("ok",false)):
        _fail("Godot SkeletonProfileHumanoid/TwoBoneIK3D setup: "+JSON.stringify(setup))
        return
    var ik: TwoBoneIK3D = setup["ik"] as TwoBoneIK3D
    if ik.setting_count != 2 or int(setup["mapped_humanoid"]) < 18:
        _fail("native IK/BoneMap did not initialize")
        return
    var camera := Camera3D.new()
    camera.fov = 56.0
    city.add_child(camera)
    camera.current = true
    var result: Dictionary = {}
    var all_files: Array[String] = []
    var total_pre: float = 0.0
    var total_post: float = 0.0
    var stance_count: int = 0
    var significant_solved: int = 0
    for motion in ["walk","run"]:
        var clip: Animation = driver.get_animation("v22/"+motion)
        if clip == null or clip.length < .2:
            _fail("licensed imported clip missing "+motion)
            return
        var anchors: Dictionary = {}
        var track: Array[Dictionary] = []
        for frame in range(SAMPLES):
            # Source pose first (unmodified), apply IK AFTER the animation.
            ik.active = false
            player.character_visual.position.y = fixed_root_y
            driver.play("v22/"+motion)
            var t: float = (float(frame)+0.5)/float(SAMPLES)*clip.length
            driver.seek(t,true)
            driver.stop(true)
            await process_frame
            var feet_before: Dictionary = {
                "L":_world_ankle(player.rig,"L"),
                "R":_world_ankle(player.rig,"R")
            }
            var aim: Dictionary = NativeFootIkV23.aim(
                player,setup,float(calibration["sole_offset_from_ankle"]),anchors)
            if not bool(aim.get("ok",false)):
                _fail("target construction failed "+motion+"["+str(frame)+"] "+JSON.stringify(aim))
                return
            ik.active = true
            await process_frame
            await process_frame
            var after: Dictionary = {}
            for side in ["L","R"]:
                var foot: Vector3 = _world_ankle(player.rig,side)
                var target: Marker3D = setup["targets"][side] as Marker3D
                if not is_finite(foot.y) or foot.length()>1000.0:
                    _fail("IK produced nonfinite or exploding avatar ankle")
                    return
                var before_error: float = (feet_before[side] as Vector3).distance_to(target.global_position)
                var after_error: float = foot.distance_to(target.global_position)
                var is_stance: bool = bool(aim["measurements"][side]["stance"])
                if is_stance:
                    stance_count += 1
                    total_pre += before_error
                    total_post += after_error
                    if before_error > .035 and after_error < before_error-.015:
                        significant_solved += 1
                after[side] = {
                    "stance":is_stance,
                    "before_target_error_metres":snappedf(before_error,.003),
                    "after_target_error_metres":snappedf(after_error,.003),
                    "ankle_y":snappedf(foot.y,.003),
                    "target_y":snappedf(target.global_position.y,.003)
                }
            camera.global_position = player.global_position + Vector3(1.55,1.75,-3.25)
            camera.look_at(player.global_position+Vector3.UP*1.02)
            await process_frame
            var img: Image = root.get_viewport().get_texture().get_image()
            if img == null or img.get_width()<720:
                _fail("no V0.23 actual Godot screenshot")
                return
            var filename: String = "v23_%s_ik_%02d.png" % [motion,frame]
            if img.save_png(ProjectSettings.globalize_path("res://tests/"+filename)) != OK:
                _fail("failed to save "+filename)
                return
            all_files.append(filename)
            track.append({
                "frame":frame,"clip_second":snappedf(t,.003),
                "root_offset_y_metres":snappedf(player.character_visual.position.y,.003),
                "L":after["L"],"R":after["R"]
            })
        result[motion]={"clip_duration_seconds":snappedf(clip.length,.003),"samples":track}
    var mean_pre: float = total_pre/float(maxi(1,stance_count))
    var mean_post: float = total_post/float(maxi(1,stance_count))
    var metrics: Dictionary = {
        "engine":"Godot 4.7.2",
        "solver":"Godot native TwoBoneIK3D; separate left/right chains with independent stance target/pole",
        "humanoid_profile_bone_count":int(setup["mapped_humanoid"]),
        "shared_source_target_animation_bones":r["shared_bones"],
        "fixed_avatar_root_height_m":snappedf(fixed_root_y,.003),
        "observed_root_height_oscillation_m":0.0,
        "stance_samples":stance_count,
        "improved_stance_samples":significant_solved,
        "mean_ankle_target_error_before_m":snappedf(mean_pre,.003),
        "mean_ankle_target_error_after_m":snappedf(mean_post,.003),
        "clips":result,"screenshots":all_files,
        "limits":["Only imported clip timeline samples, not live movement/video",
            "Shoes use bind-AABB proxy, not skinned vertex contact",
            "No animation blending between walk/run/turn",
            "Knee bending and arm anatomy need subjective art review",
            "Windows RTX3060 and Chrome gameplay not measured",
            "V0.20 production movement not changed"]
    }
    var file: FileAccess = FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v23_native_ik_metrics.json"),FileAccess.WRITE)
    if file == null:
        _fail("cannot write V0.23 metrics")
        return
    file.store_string(JSON.stringify(metrics,"\t")+"\n")
    file.close()
    if stance_count < 3:
        _fail("no meaningful actual foot stance detected; metrics saved")
        return
    if significant_solved < 1 or mean_post >= mean_pre*.96:
        _fail("native IK did not measurably improve target foot error: pre="+str(mean_pre)+" post="+str(mean_post))
        return
    print("V23 NATIVE IK PASS: "+JSON.stringify({
        "images":all_files.size(),"profile_bones":setup["mapped_humanoid"],
        "stance_samples":stance_count,"improved":significant_solved,
        "mean_pre_m":snappedf(mean_pre,.003),"mean_post_m":snappedf(mean_post,.003),
        "fixed_root_y":snappedf(fixed_root_y,.003)
    }))
    source.queue_free()
    city.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode",false)
    quit(0)
