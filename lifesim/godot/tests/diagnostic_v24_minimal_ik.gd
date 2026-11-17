extends SceneTree

# Standalone engine-only diagnosis for V0.23's 0/12 unchanged ankle poses.
# No GLB, city, game economy or image processing is necessary.
# Measure IN SkeletonModifier3D.modification_processed, as the official Godot
# docs warn that later get_bone_global_pose reads can miss modifier results.
const OUTPUT: String = "res://tests/v24_minimal_ik_metrics.json"

func _initialize() -> void:
    call_deferred("_run")

func _finish(d: Dictionary, ok: bool) -> void:
    d["passed"] = ok
    var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(OUTPUT),FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(d,"\t")+"\n")
        file.close()
    if ok:
        print("V24 MINIMAL IK PASS: "+JSON.stringify(d))
        quit(0)
    else:
        printerr("V24 MINIMAL IK FAIL: "+JSON.stringify(d))
        quit(1)

func _run() -> void:
    var host := Node3D.new()
    host.name = "V24StandaloneRig"
    root.add_child(host)
    var skeleton := Skeleton3D.new()
    skeleton.name = "SyntheticLeg"
    host.add_child(skeleton)
    skeleton.add_bone("Hip")
    skeleton.add_bone("Knee")
    skeleton.add_bone("Ankle")
    skeleton.set_bone_parent(1,0)
    skeleton.set_bone_parent(2,1)
    skeleton.set_bone_rest(0,Transform3D(Basis(),Vector3(0,1.85,0)))
    skeleton.set_bone_rest(1,Transform3D(Basis(),Vector3(0,-.75,0)))
    skeleton.set_bone_rest(2,Transform3D(Basis(),Vector3(0,-.75,0)))
    skeleton.reset_bone_poses()
    skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
    var target := Marker3D.new()
    target.name = "Target"
    host.add_child(target)
    target.global_position = Vector3(.36,.59,-.08)
    var pole := Marker3D.new()
    pole.name = "Pole"
    host.add_child(pole)
    pole.global_position = Vector3(0,1.10,-1.0)
    var solver := TwoBoneIK3D.new()
    solver.name = "NativeIK"
    skeleton.add_child(solver)
    solver.setting_count = 1
    solver.active = false
    solver.influence = 1.0
    solver.set_root_bone_name(0,"Hip")
    solver.set_middle_bone_name(0,"Knee")
    solver.set_end_bone_name(0,"Ankle")
    solver.set_target_node(0,solver.get_path_to(target))
    solver.set_pole_node(0,solver.get_path_to(pole))
    solver.set_pole_direction(0,SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z)
    await process_frame

    var baseline: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(2).origin
    var initial_error: float = baseline.distance_to(target.global_position)
    var observations: Dictionary = {
        "engine":Engine.get_version_info().get("string","unknown"),
        "test":"synthetic 3-bone skeleton, native TwoBoneIK3D, manual Skeleton3D.advance, modifier signal read",
        "baseline_end_world":str(baseline),
        "target_world":str(target.global_position),
        "target_node_path":str(solver.get_target_node(0)),
        "pole_node_path":str(solver.get_pole_node(0)),
        "target_resolves":solver.get_node_or_null(solver.get_target_node(0))==target,
        "pole_resolves":solver.get_node_or_null(solver.get_pole_node(0))==pole,
        "initial_error_metres":snappedf(initial_error,.0001),
        "signal_count":0,"signal_min_error":999.0,"signal_best_end_world":"",
        "after_frame_error_metres":null,
        "solver_active":false,
        "manual_callback":true,
    }
    solver.modification_processed.connect(func() -> void:
        var ankle: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(2).origin
        var e: float = ankle.distance_to(target.global_position)
        observations["signal_count"] = int(observations["signal_count"])+1
        if e < float(observations["signal_min_error"]):
            observations["signal_min_error"] = snappedf(e,.0001)
            observations["signal_best_end_world"] = str(ankle)
    )
    solver.active = true
    observations["solver_active"] = solver.active
    for i in range(4):
        skeleton.advance(1.0/60.0)
        await process_frame
    var latest: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(2).origin
    observations["after_frame_error_metres"] = snappedf(latest.distance_to(target.global_position),.0001)
    observations["signal_min_error"] = snappedf(float(observations["signal_min_error"]),.0001)
    var success: bool = (
        bool(observations["target_resolves"]) and bool(observations["pole_resolves"])
        and int(observations["signal_count"])>0 and initial_error>.1
        and float(observations["signal_min_error"]) < initial_error-.04
    )
    _finish(observations,success)
