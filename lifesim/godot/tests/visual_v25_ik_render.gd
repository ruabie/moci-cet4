extends SceneTree

# V0.25: image-backed verification of Godot's NATIVE IK actually deforming
# the *rendered* skinned CC0 LifeSim avatar, not just a transient bone pose.
# Do not integrate into CityPlayer until a human reviews these paired images.
const PHASES: Array[float] = [0.12, 0.36, 0.61, 0.86]
const MIN_SIGNAL_PAIRS: int = 8

func _initialize() -> void:
    call_deferred("_run")

func _ankle(rig: Skeleton3D, side: String) -> Vector3:
    var index: int = rig.find_bone("Foot."+side)
    return rig.global_transform * rig.get_bone_global_pose(index).origin

func _fail(message: String, observed: Dictionary = {}) -> void:
    printerr("V25 IK RENDER FAIL: "+message+" "+JSON.stringify(observed))
    _write_report({"ok":false, "error":message, "observed":observed})
    quit(1)

func _write_report(report: Dictionary) -> void:
    var target: String = ProjectSettings.globalize_path(
        "res://tests/v25_ik_render_metrics.json")
    var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
    if file == null:
        printerr("V25 IK RENDER FAIL: unable to write metrics file")
        return
    file.store_string(JSON.stringify(report,"\t")+"\n")
    file.close()

func _capture(label: String) -> bool:
    # Snapshot at the graphics draw boundary. A later bone query (as found in
    # V0.24) is not valid evidence for whether the skin WAS rendered correctly.
    await RenderingServer.frame_post_draw
    var im: Image = root.get_viewport().get_texture().get_image()
    if im == null or im.get_width()<720 or im.get_height()<400:
        return false
    return im.save_png(
        ProjectSettings.globalize_path("res://tests/v25_"+label+".png"))==OK

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    var source_scene: PackedScene = load(
        "res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var city_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source_scene==null or city_scene==null:
        _fail("missing real pinned CC0 animation or game scene")
        return
    var imported: Node = source_scene.instantiate()
    var city: Node3D = city_scene.instantiate() as Node3D
    root.add_child(city)
    await process_frame
    await physics_frame
    var player: CityPlayer = city.get_node_or_null("Player") as CityPlayer
    if player == null or player.rig == null or not player.animation_verified:
        _fail("actual skinned LifeSim player did not initialize")
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0.0,.2,-10.0)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = city.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible=false
    var shoes: Dictionary = FootContactV22.setup(player)
    if not bool(shoes.get("ok",false)):
        _fail("shoe mesh / ankle bind proxy unavailable",shoes)
        return
    var retarget: Dictionary = AnimationRetargetV22.install(
        imported,player.rig,player)
    if not bool(retarget.get("ok",false)):
        _fail("CC0 retarget failed",retarget)
        return
    var anim: AnimationPlayer = retarget["player"] as AnimationPlayer
    anim.play("v22/idle")
    anim.seek(.12,true)
    anim.stop(true)
    await process_frame
    var alignment: Dictionary = FootContactV22.lock_preview_height(player,shoes)
    if not bool(alignment.get("ok",false)):
        _fail("real road physics collision alignment failed",alignment)
        return
    var fixed_root: float=player.character_visual.position.y
    if absf(fixed_root)>.85:
        _fail("fixed avatar root out of plausible range",{"root":fixed_root})
        return
    var installed: Dictionary = NativeFootIkV23.install(player)
    if not bool(installed.get("ok",false)):
        _fail("native Godot IK setup failed",installed)
        return
    var rig: Skeleton3D=player.rig
    var ik: TwoBoneIK3D=installed["ik"] as TwoBoneIK3D
    rig.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
    var camera:=Camera3D.new()
    camera.fov=51.0
    city.add_child(camera)
    camera.global_position=player.global_position+Vector3(1.24,1.64,-2.75)
    camera.look_at(player.global_position+Vector3.UP*1.06)
    camera.current=true
    var signal_info: Dictionary={
        "enabled":false,"count":0,"positions":{},"errors":{}
    }
    ik.modification_processed.connect(func() -> void:
        if not bool(signal_info["enabled"]):
            return
        signal_info["count"]=int(signal_info["count"])+1
        var solved: Dictionary={}
        var errs: Dictionary={}
        for side in ["L","R"]:
            var ankle: Vector3=_ankle(rig,side)
            var target: Marker3D=installed["targets"][side] as Marker3D
            solved[side]=str(ankle)
            errs[side]=ankle.distance_to(target.global_position)
        signal_info["positions"]=solved
        signal_info["errors"]=errs
    )
    var samples: Array[Dictionary]=[]
    var filenames: Array[String]=[]
    var callback_samples:int=0
    var stance_samples:int=0
    var solved_stance_samples:int=0
    var anchors: Dictionary={}
    for motion in ["walk","run"]:
        anchors.clear()
        var clip: Animation=anim.get_animation("v22/"+motion)
        if clip==null or clip.length<=.2:
            _fail("missing licensed imported movement "+motion)
            return
        for i in range(PHASES.size()):
            ik.active=false
            player.character_visual.position.y=fixed_root
            anim.play("v22/"+motion)
            var time: float=float(PHASES[i])*clip.length
            anim.seek(time,true)
            anim.stop(true)
            await process_frame
            # Capture the *same* exact animated pose before IK.
            rig.advance(1.0/60.0)
            var neutral_name: String="%s_%02d_off" % [motion,i]
            if not await _capture(neutral_name):
                _fail("Godot viewport failed to render raw pose "+neutral_name)
                return
            filenames.append("v25_"+neutral_name+".png")
            var before: Dictionary={
                "L":_ankle(rig,"L"),"R":_ankle(rig,"R")
            }
            var aiming: Dictionary=NativeFootIkV23.aim(
                player,installed,float(shoes["sole_offset_from_ankle"]),anchors)
            if not bool(aiming.get("ok",false)):
                _fail("actual ground IK target creation failed",aiming)
                return
            var foot_checks: Dictionary={}
            for side in ["L","R"]:
                var target: Marker3D=installed["targets"][side] as Marker3D
                foot_checks[side]={
                    "stance":bool(aiming["measurements"][side]["stance"]),
                    "pre_ik_error_m":(before[side] as Vector3).distance_to(target.global_position)
                }
            signal_info["enabled"]=true
            signal_info["count"]=0
            signal_info["positions"]={}
            signal_info["errors"]={}
            ik.active=true
            # A prior OFF-state render also advanced this skeleton. Wait for
            # the *next engine frame* before running manual modifier advance;
            # the V0.24 passing test performed just one advance each frame.
            await process_frame
            rig.advance(1.0/60.0)
            signal_info["enabled"]=false
            var count:int=int(signal_info["count"])
            if count<1:
                _fail("native modifier did not fire in actual city player",{
                    "motion":motion,"phase":i,
                    "ik_active":ik.active,"solver_in_tree":ik.is_inside_tree(),
                    "setting_count":ik.setting_count,
                    "modifier_mode":rig.modifier_callback_mode_process
                })
                return
            callback_samples+=1
            var after_name: String="%s_%02d_on" % [motion,i]
            if not await _capture(after_name):
                _fail("Godot viewport failed to render IK pose "+after_name)
                return
            filenames.append("v25_"+after_name+".png")
            for side in ["L","R"]:
                var post:float=float(signal_info["errors"].get(side,INF))
                foot_checks[side]["signal_ankle_error_m"]=post
                foot_checks[side]["solved_world"]=signal_info["positions"].get(side,"")
                if bool(foot_checks[side]["stance"]):
                    stance_samples+=1
                    if post<float(foot_checks[side]["pre_ik_error_m"])-.012:
                        solved_stance_samples+=1
            samples.append({
                "motion":motion, "phase_index":i,
                "t_seconds":snappedf(time,.004),
                "fixed_render_root_y_m":snappedf(fixed_root,.004),
                "signal_count":count,"foot_check":foot_checks,
                "control_image":"v25_"+neutral_name+".png",
                "ik_render_image":"v25_"+after_name+".png"
            })
    var summary: Dictionary={
        "godot":Engine.get_version_info().get("string","unknown"),
        "skinned_avatar":"Actual CC0 Quaternius LifeSim CityPlayer with rendered existing clothing and shoe mesh",
        "native_ik":"Godot 4.7 TwoBoneIK3D; source/target rest retarget V0.22",
        "actual_paired_render_samples":samples.size(),
        "modifier_callback_sample_count":callback_samples,
        "stance_foot_samples":stance_samples,
        "solved_stance_samples":solved_stance_samples,
        "avatar_root_height_m":snappedf(fixed_root,.004),
        "camera":"Fixed. No zoom or reset between off/on pairs.",
        "render_comparison":"Same exact animation time and camera; actual OpenGL3 viewport screenshots, not generated pictures",
        "limits":["No real-time player input yet","No true skinned mesh sole physics contact measurement",
            "No arm-pose cleanup","No Windows RTX3060 frame-rate tests",
            "A target-error value alone cannot establish convincing leg art"]
    }
    var good:bool=callback_samples>=MIN_SIGNAL_PAIRS and stance_samples>=2         and solved_stance_samples>=1
    var report: Dictionary={"ok":good,"summary":summary,
        "samples":samples,"screenshots":filenames}
    _write_report(report)
    if not good:
        printerr("V25 IK RENDER FAIL: missing solver evidence "+JSON.stringify(summary))
        quit(1)
        return
    print("V25 IK RENDER PASS: "+JSON.stringify(summary))
    imported.queue_free()
    city.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode",false)
    quit(0)
