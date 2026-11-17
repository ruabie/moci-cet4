extends RefCounted
class_name CompatibleAnimV26

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
        if int(counts["rotation"])<60 or int(counts["pelvis_translation"])!=1:
            return {"ok":false,"reason":"full-body motion lost tracks: "+key,
                "counts":counts}
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
