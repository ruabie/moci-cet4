extends RefCounted
class_name CompatibleAnimV26

# V0.27: static/rest rotation fallback is ALLOWED ONLY if the exact pinned
# source GLB has independently proven the joint stays at rest in this clip.
# Godot often optimizes away redundant constant tracks; no arbitrary missing
# dynamic bone can be silently ignored.
const REST_AUDIT_FILE: String = "res://tests/v27_source_constant_rest.json"
const PINNED_SOURCE_BLOB: String = "473e59080288428d0b6da826ba19324d07b191f0"

static func _rest_fallback_proven(clip: String, bone: String) -> bool:
    if not FileAccess.file_exists(REST_AUDIT_FILE):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REST_AUDIT_FILE))
    if not (parsed is Dictionary):
        return false
    var proof: Dictionary = parsed as Dictionary
    if str(proof.get("source_git_blob","")) != PINNED_SOURCE_BLOB:
        return false
    var by_clip: Dictionary = proof.get("constant_rotation_bones_by_clip",{})
    # Proven by V0.27's exact Godot imported AnimationPlayer inventory:
    # the importer removes the "_Loop" suffix and shortens Jog_Fwd_Loop.
    # Never guess another clip's original identity; unlisted names fail closed.
    var imported_to_pinned: Dictionary = {
        "Idle":"Idle_Loop",
        "Walk":"Walk_Loop",
        "Jog_Fwd":"Jog_Fwd_Loop"
    }
    var original_name: String = str(imported_to_pinned.get(clip,""))
    if original_name=="":
        return false
    var accepted: Variant = by_clip.get(original_name,[])
    return accepted is Array and (accepted as Array).has(bone)

# Comparison-only full-body animation transfer from UAL1 into the Quaternius
# Universal Base Character. Preserve mapped pelvis POSITION as well as ROTATION.
# No game CityPlayer mutation, no automatic asset replacement.
static func install(source_scene: Node, dest_scene: Node3D) -> Dictionary:
    var source_rig: Skeleton3D=AnimationRetargetV22._find_skeleton(source_scene)
    var target_rig: Skeleton3D=AnimationRetargetV22._find_skeleton(dest_scene)
    var source_anim: AnimationPlayer=AnimationRetargetV22._find_animation_player(source_scene)
    if source_rig==null or target_rig==null or source_anim==null:
        return {"ok":false,"reason":"source/target imported rig or source clip player missing"}
    var shared:int=0
    var exact_parents:int=0
    for idx in range(source_rig.get_bone_count()):
        var name:String=str(source_rig.get_bone_name(idx))
        var target_idx:int=target_rig.find_bone(name)
        if target_idx>=0:
            shared+=1
            var source_parent:int=source_rig.get_bone_parent(idx)
            var target_parent:int=target_rig.get_bone_parent(target_idx)
            var sp:String=str(source_rig.get_bone_name(source_parent)) if source_parent>=0 else ""
            var tp:String=str(target_rig.get_bone_name(target_parent)) if target_parent>=0 else ""
            if sp==tp:
                exact_parents+=1
    if shared<60 or exact_parents<60:
        return {"ok":false,"reason":"not a shared humanoid hierarchy",
            "shared":shared,"exact_parents":exact_parents}
    var name_list:PackedStringArray=source_anim.get_animation_list()
    var selected:Dictionary={
        "idle":AnimationRetargetV22._select_name(name_list,["idle_loop","idle"]),
        "walk":AnimationRetargetV22._select_name(name_list,["walk_loop","walk"]),
        "jog":AnimationRetargetV22._select_name(name_list,["jog_fwd_loop","jog_fwd","jog","run"])
    }
    for key in selected:
        if str(selected[key])=="":
            return {"ok":false,"reason":"source clip not found: "+key,
                "available":Array(name_list)}
    var lib:=AnimationLibrary.new()
    var clip_tracks:Dictionary={}
    for key in ["idle","walk","jog"]:
        var clip:Animation=source_anim.get_animation(str(selected[key]))
        var rebuilt:=Animation.new()
        rebuilt.length=clip.length
        rebuilt.loop_mode=Animation.LOOP_LINEAR
        var counts:Dictionary={"rotation":0,"pelvis_translation":0}
        var critical_bones:Dictionary={}
        var critical_required:Array[String]=[
            "pelvis","spine_01","spine_03",
            "clavicle_l","upperarm_l","lowerarm_l",
            "clavicle_r","upperarm_r","lowerarm_r",
            "thigh_l","calf_l","foot_l",
            "thigh_r","calf_r","foot_r"
        ]
        for n in range(clip.get_track_count()):
            var type:int=clip.track_get_type(n)
            if type!=Animation.TYPE_ROTATION_3D and type!=Animation.TYPE_POSITION_3D:
                continue
            var original:NodePath=clip.track_get_path(n)
            if original.get_subname_count()==0:
                continue
            var bone:String=str(original.get_subname(0))
            if type==Animation.TYPE_POSITION_3D and bone!="pelvis":
                continue # other source bone translations are static
            var si:int=source_rig.find_bone(bone)
            var ti:int=target_rig.find_bone(bone)
            if si<0 or ti<0:
                continue
            var index:int=rebuilt.add_track(type)
            rebuilt.track_set_path(index,NodePath(str(dest_scene.get_path_to(target_rig))+":"+bone))
            rebuilt.track_set_interpolation_type(index,clip.track_get_interpolation_type(n))
            if type==Animation.TYPE_ROTATION_3D:
                var sr:Quaternion=source_rig.get_bone_rest(si).basis.get_rotation_quaternion()
                var dr:Quaternion=target_rig.get_bone_rest(ti).basis.get_rotation_quaternion()
                var sg:Quaternion=source_rig.get_bone_global_rest(si).basis.get_rotation_quaternion()
                var dg:Quaternion=target_rig.get_bone_global_rest(ti).basis.get_rotation_quaternion()
                var frame:Quaternion=(dg.inverse()*sg).normalized()
                for k in range(clip.track_get_key_count(n)):
                    var authored:Quaternion=clip.track_get_key_value(n,k)
                    var local_delta:Quaternion=(sr.inverse()*authored).normalized()
                    var adapted:Quaternion=(dr*frame*local_delta*frame.inverse()).normalized()
                    rebuilt.track_insert_key(index,clip.track_get_key_time(n,k),adapted)
                counts["rotation"]=int(counts["rotation"])+1
                if critical_required.has(bone):
                    critical_bones[bone]=true
            else:
                var src_origin:Vector3=source_rig.get_bone_rest(si).origin
                var dst_origin:Vector3=target_rig.get_bone_rest(ti).origin
                for k in range(clip.track_get_key_count(n)):
                    var authored:Vector3=clip.track_get_key_value(n,k)
                    # The Universal Base rig shares source axis orientation
                    # and near-identical proportions, checked by binary audit.
                    var shifted:Vector3=dst_origin+(authored-src_origin)
                    rebuilt.track_insert_key(index,clip.track_get_key_time(n,k),shifted)
                counts["pelvis_translation"]=int(counts["pelvis_translation"])+1
        var missing_critical:Array[String]=[]
        for required in critical_required:
            if not critical_bones.has(required):
                missing_critical.append(required)
        # Godot's actual imported source Idle has 55 rotation tracks; do not
        # demand 60 animated leaf bones when they are absent from SOURCE.
        # Enforce all important bilateral torso/arm/leg joint tracks instead.
        var rest_fallback:Array[String]=[]
        var rejected_missing:Array[String]=[]
        for missing in missing_critical:
            if _rest_fallback_proven(str(selected[key]),missing):
                # Target Skeleton3D starts in its own rest orientation; the
                # exact source has no meaningful animation for this bone.
                rest_fallback.append(missing)
            else:
                rejected_missing.append(missing)
        counts["verified_static_rest_fallback"]=rest_fallback
        counts["rejected_missing_dynamic_bones"]=rejected_missing
        if int(counts["rotation"])<50 or int(counts["pelvis_translation"])!=1 \
                or rejected_missing.size()>0:
            return {"ok":false,"reason":"critical dynamic bone unexpectedly missing: "+key,
                "counts":counts,"missing_source":missing_critical,
                "verified_static_rest_fallback":rest_fallback}
        lib.add_animation(key,rebuilt)
        clip_tracks[key]=counts
    var driver:=AnimationPlayer.new()
    driver.name="V26CompatibleRigAnimationPreview"
    dest_scene.add_child(driver)
    driver.root_node=NodePath("..")
    driver.add_animation_library("v26",lib)
    return {"ok":true,"player":driver,"clips":selected,
        "shared_bones":shared,"parent_matches":exact_parents,
        "track_counts":clip_tracks,
        "method":"full-body rotation retarget+pelvis translation, test only"}
