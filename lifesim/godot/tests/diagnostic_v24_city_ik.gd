extends SceneTree

# Test the REAL V0.23 character, retaining the exact IK solver/targets.
# Read ankle pose at the precise Godot SkeletonModifier3D.modification_processed
# signal. A late get_bone_global_pose outside signal is NOT the modified pose.
const SAMPLES_PER_MOTION: int = 5

func _initialize() -> void:
    call_deferred("_run")

func _foot(rig: Skeleton3D, side: String) -> Vector3:
    var index: int = rig.find_bone("Foot."+side)
    return rig.global_transform * rig.get_bone_global_pose(index).origin

func _save(d: Dictionary, success: bool) -> void:
    d["passed"] = success
    var file: FileAccess = FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v24_city_ik_metrics.json"), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(d,"\t")+"\n")
        file.close()
    if success:
        print("V24 CITY IK SIGNAL PASS: "+JSON.stringify(d["summary"]))
        quit(0)
    else:
        printerr("V24 CITY IK SIGNAL FAIL: "+JSON.stringify(d["summary"]))
        quit(1)

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    var media: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if media==null or packed==null:
        _save({"summary":{"reason":"source file or main scene absent"}},false)
        return
    var source: Node = media.instantiate()
    var city: Node3D = packed.instantiate() as Node3D
    root.add_child(city)
    await process_frame
    await physics_frame
    var player: CityPlayer = city.get_node_or_null("Player") as CityPlayer
    if player==null or player.rig==null:
        _save({"summary":{"reason":"real skinned CityPlayer absent"}},false)
        return
    player.set_physics_process(false)
    player.global_position = Vector3(0.0,.2,-10.0)
    player.velocity = Vector3.ZERO
    var hud: CanvasLayer = city.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible=false
    var calibration: Dictionary = FootContactV22.setup(player)
    if not bool(calibration.get("ok",false)):
        _save({"summary":{"reason":"V0.22 shoe calibration failed","data":calibration}},false)
        return
    var old: Dictionary = AnimationRetargetV22.install(source,player.rig,player)
    if not bool(old.get("ok",false)):
        _save({"summary":{"reason":"V0.22 real CC0 rig retarget failed","data":old}},false)
        return
    var driver: AnimationPlayer = old["player"] as AnimationPlayer
    driver.play("v22/idle")
    driver.seek(.12,true)
    driver.stop(true)
    await process_frame
    var root_align: Dictionary = FootContactV22.lock_preview_height(player,calibration)
    if not bool(root_align.get("ok",false)):
        _save({"summary":{"reason":"idle road-ground alignment failed","data":root_align}},false)
        return
    var fixed_root_height: float = player.character_visual.position.y
    var installed: Dictionary = NativeFootIkV23.install(player)
    if not bool(installed.get("ok",false)):
        _save({"summary":{"reason":"V0.23 IK install failed","data":installed}},false)
        return
    var rig: Skeleton3D = player.rig
    var ik: TwoBoneIK3D = installed["ik"] as TwoBoneIK3D
    rig.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
    var watching: Dictionary = {
        "armed":false, "signal_count":0, "signal_errors":{}, "signal_positions":{}
    }
    ik.modification_processed.connect(func() -> void:
        if not bool(watching["armed"]):
            return
        watching["signal_count"]=int(watching["signal_count"])+1
        var errors: Dictionary = {}
        var positions: Dictionary = {}
        for side in ["L","R"]:
            var foot: Vector3 = _foot(rig,side)
            var target: Marker3D = installed["targets"][side] as Marker3D
            errors[side]=foot.distance_to(target.global_position)
            positions[side]=str(foot)
        watching["signal_errors"]=errors
        watching["signal_positions"]=positions
    )
    var samples: Array[Dictionary] = []
    var hits: int=0
    var improved: int=0
    var stance_hits: int=0
    var sum_before: float=0.0
    var sum_in_signal: float=0.0
    var sum_after_frame: float=0.0
    for motion in ["walk","run"]:
        var animation: Animation = driver.get_animation("v22/"+motion)
        if animation==null or animation.length<=.2:
            _save({"summary":{"reason":"missing actual licensed clip "+motion}},false)
            return
        var anchors: Dictionary={}
        for n in range(SAMPLES_PER_MOTION):
            ik.active=false
            player.character_visual.position.y=fixed_root_height
            driver.play("v22/"+motion)
            var t: float=(float(n)+.5)*animation.length/float(SAMPLES_PER_MOTION)
            driver.seek(t,true)
            driver.stop(true)
            await process_frame
            var before: Dictionary={"L":_foot(rig,"L"),"R":_foot(rig,"R")}
            var aim: Dictionary=NativeFootIkV23.aim(player,installed,
                float(calibration["sole_offset_from_ankle"]),anchors)
            if not bool(aim.get("ok",false)):
                _save({"summary":{"reason":"real road target failed","data":aim}},false)
                return
            for side in ["L","R"]:
                var node: Marker3D=installed["targets"][side] as Marker3D
                var np: NodePath=ik.get_target_node(0 if side=="L" else 1)
                if ik.get_node_or_null(np)!=node:
                    _save({"summary":{"reason":"IK target path did not resolve","side":side,"path":str(np)}},false)
                    return
            watching["armed"]=true
            watching["signal_count"]=0
            watching["signal_errors"]={}
            watching["signal_positions"]={}
            ik.active=true
            rig.advance(1.0/60.0)
            await process_frame
            watching["armed"]=false
            var event_count: int=int(watching["signal_count"])
            var late: Dictionary={"L":_foot(rig,"L"),"R":_foot(rig,"R")}
            var pair: Dictionary={}
            for side in ["L","R"]:
                var target: Marker3D=installed["targets"][side] as Marker3D
                var baseline: float=(before[side] as Vector3).distance_to(target.global_position)
                var live: float=float(watching["signal_errors"].get(side,INF))
                var after: float=(late[side] as Vector3).distance_to(target.global_position)
                var stance: bool=bool(aim["measurements"][side]["stance"])
                if stance and event_count>0:
                    stance_hits+=1
                    sum_before+=baseline
                    sum_in_signal+=live
                    sum_after_frame+=after
                    if live+0.01<baseline:
                        improved+=1
                pair[side]={
                    "stance":stance,"before_m":snappedf(baseline,.004),
                    "within_signal_m":snappedf(live,.004),
                    "after_frame_m":snappedf(after,.004),
                    "target_y_m":snappedf(target.global_position.y,.004)
                }
            hits+=event_count
            samples.append({"clip":motion,"sample":n,"time_s":snappedf(t,.004),
                "signal_count":event_count,"feet":pair})
    var denom: float=float(maxi(1,stance_hits))
    var mean_before: float=sum_before/denom
    var mean_inside: float=sum_in_signal/denom
    var mean_late: float=sum_after_frame/denom
    var summary: Dictionary={
        "engine":Engine.get_version_info().get("string","unknown"),
        "source":"Actual Quaternius UAL1 clips retargeted to existing LifeSim CityPlayer; V0.23 native TwoBoneIK3D",
        "signal_events":hits,"sample_pairs":samples.size(),
        "stance_foot_samples":stance_hits,"stance_foot_improvements":improved,
        "mean_error_before_m":snappedf(mean_before,.004),
        "mean_error_within_signal_m":snappedf(mean_inside,.004),
        "mean_error_after_frame_m":snappedf(mean_late,.004),
        "fixed_visual_root_y_m":snappedf(fixed_root_height,.004),
        "modifier_mode":"Manual; Skeleton3D.advance(1/60) with modifier signal capture",
        "not_proven":["rendered mesh foot sole contact","real-time game gait","Windows GPU","foot-skate-free locomotion","natural arm/knee anatomy"]
    }
    var all: Dictionary={"summary":summary,"samples":samples,
        "interpretation":"Use within_signal_m only as IK solver result, never the after-frame reading."}
    # This does NOT silently lower V0.23's former 4% gate. Require at least
    # 2 stance samples to improve by 1cm and 10% mean within-signal reduction.
    var passed: bool = hits>=samples.size() and stance_hits>=3 and improved>=2         and mean_inside<mean_before*.90
    _save(all,passed)
