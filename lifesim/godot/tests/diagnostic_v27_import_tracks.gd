extends SceneTree

# Actual Godot 4.7 imported AnimationPlayer track inventory vs pinned GLB.
# If a zero-motion rest rotation is optimized out, prove this in the engine
# instead of silently removing an art-quality gate.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    if source==null:
        printerr("V27 GODOT TRACK INVENTORY FAIL: no imported UAL source")
        quit(1)
        return
    var actor: Node3D=source.instantiate() as Node3D
    root.add_child(actor)
    await process_frame
    var rig: Skeleton3D=AnimationRetargetV22._find_skeleton(actor)
    var ap: AnimationPlayer=AnimationRetargetV22._find_animation_player(actor)
    if rig==null or ap==null:
        printerr("V27 GODOT TRACK INVENTORY FAIL: imported rig/player unavailable")
        quit(1)
        return
    var report: Dictionary={
        "skeleton_bones":rig.get_bone_count(),
        "spine_01_exists_in_skeleton":rig.find_bone("spine_01")>=0,
        "clips":{},"interpretation":"Imported GDScript Animation track inventory, compare with v27_source_constant_rest.json"}
    var supported: bool=rig.get_bone_count()==65 and rig.find_bone("spine_01")>=0
    for motion in ["Idle_Loop","Walk_Loop","Jog_Fwd_Loop"]:
        var clip: Animation=ap.get_animation(motion)
        if clip==null:
            printerr("V27 GODOT TRACK INVENTORY FAIL: missing imported "+motion)
            quit(1)
            return
        var bones: Dictionary={}
        var type_counts: Dictionary={}
        for i in range(clip.get_track_count()):
            var kind:int=clip.track_get_type(i)
            var path:NodePath=clip.track_get_path(i)
            var n:String=str(path.get_subname(0)) if path.get_subname_count()>0 else ""
            if not bones.has(n):
                bones[n]=[]
            (bones[n] as Array).append({"type":kind,"path":str(path),"keys":clip.track_get_key_count(i)})
            var label:String=str(kind)
            type_counts[label]=int(type_counts.get(label,0))+1
        var spine: Array=bones.get("spine_01",[])
        var rotates:int=0
        var pelvis_moves:int=0
        for track in bones.get("spine_01",[]):
            if int(track["type"])==Animation.TYPE_ROTATION_3D:
                rotates+=1
        for track in bones.get("pelvis",[]):
            if int(track["type"])==Animation.TYPE_POSITION_3D:
                pelvis_moves+=1
        report["clips"][motion]={
            "total_imported_tracks":clip.get_track_count(),
            "type_counts":type_counts,
            "imported_spine_01_tracks":spine,
            "imported_spine_01_rotations":rotates,
            "imported_pelvis_position_tracks":pelvis_moves,
            "bone_names_present":bones.keys(),
            "upperarm_l":bones.get("upperarm_l",[]),
            "calf_l":bones.get("calf_l",[])
        }
        supported=supported and pelvis_moves==1 and bones.has("upperarm_l") and bones.has("calf_l")
    var path:String=ProjectSettings.globalize_path("res://tests/v27_godot_import_tracks.json")
    var file:FileAccess=FileAccess.open(path,FileAccess.WRITE)
    if file==null:
        printerr("V27 GODOT TRACK INVENTORY FAIL: unable to save report")
        quit(1)
        return
    file.store_string(JSON.stringify(report,"\t")+"\n")
    file.close()
    if supported:
        print("V27 GODOT TRACK INVENTORY PASS: "+JSON.stringify({
            "skeleton_bones":rig.get_bone_count(),
            "idle_spine_rotations":report["clips"]["Idle_Loop"]["imported_spine_01_rotations"],
            "jog_spine_rotations":report["clips"]["Jog_Fwd_Loop"]["imported_spine_01_rotations"],
            "walk_tracks":report["clips"]["Walk_Loop"]["total_imported_tracks"],
            "pelvis_translation_tracks":report["clips"]["Jog_Fwd_Loop"]["imported_pelvis_position_tracks"]
        }))
        quit(0)
    else:
        printerr("V27 GODOT TRACK INVENTORY FAIL: "+JSON.stringify(report))
        quit(1)
