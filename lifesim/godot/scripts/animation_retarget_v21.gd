extends RefCounted
class_name AnimationRetargetV21

# Non-destructive, QA-only CC0 clip retargeting pilot.
# Imported Godot 4 animation rotations include bind-rest rotation, so track
# values must be transferred as a delta relative to each source bone rest.
# The game must not install this player until scene, animation and art QA pass.
const MIN_SHARED_BONES: int = 30
# UAL1 Standard uses an Unreal-style humanoid skeleton, whereas the V0.18
# modular civilian pack uses the Blender-style Quaternius naming. Explicit
# semantic mapping is required; name equality alone matched just the head.
const HUMANOID_MAP: Dictionary = {
    "root":"Root", "pelvis":"Hips",
    "spine_01":"Abdomen", "spine_02":"Torso", "spine_03":"Chest",
    "neck_01":"Neck", "Head":"Head",
    "clavicle_l":"Shoulder.L", "upperarm_l":"UpperArm.L",
    "lowerarm_l":"LowerArm.L", "hand_l":"Hand.L",
    "clavicle_r":"Shoulder.R", "upperarm_r":"UpperArm.R",
    "lowerarm_r":"LowerArm.R", "hand_r":"Hand.R",
    "thigh_l":"UpperLeg.L", "calf_l":"LowerLeg.L", "foot_l":"Foot.L",
    "thigh_r":"UpperLeg.R", "calf_r":"LowerLeg.R", "foot_r":"Foot.R"
}

static func _target_bone(source_name: String) -> String:
    if HUMANOID_MAP.has(source_name):
        return str(HUMANOID_MAP[source_name])
    # The source has finger_01..03 + an unskinned leaf, while destination
    # exposes Finger2..4. Do not map leaf or extra source thumb joints.
    for part in ["index", "middle", "ring", "pinky", "thumb"]:
        for side in ["l", "r"]:
            for digit in range(1, 4):
                if part == "thumb" and digit == 3:
                    continue
                var source: String = "%s_%02d_%s" % [part, digit, side]
                if source_name == source:
                    var title: String = part.capitalize()
                    var target_number: int = digit + 1
                    return "%s%d.%s" % [title, target_number, side.to_upper()]
    return ""

static func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D and (node as Skeleton3D).get_bone_count() >= 35:
        return node as Skeleton3D
    for c in node.get_children():
        var found: Skeleton3D = _find_skeleton(c)
        if found != null:
            return found
    return null

static func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer and (node as AnimationPlayer).get_animation_list().size() >= 3:
        return node as AnimationPlayer
    for c in node.get_children():
        var found: AnimationPlayer = _find_animation_player(c)
        if found != null:
            return found
    return null

static func _select_name(names: PackedStringArray, match_words: Array[String]) -> String:
    for word in match_words:
        for name in names:
            if str(name).to_lower() == word:
                return str(name)
    for word in match_words:
        for name in names:
            if str(name).to_lower().contains(word):
                return str(name)
    return ""

static func _retarget_rotations(
        clip: Animation, source_rig: Skeleton3D, target_rig: Skeleton3D,
        owner: Node3D) -> Dictionary:
    var rewritten := Animation.new()
    rewritten.length = clip.length
    rewritten.loop_mode = Animation.LOOP_LINEAR
    var shared_tracks: int = 0
    var rejected: Array[String] = []
    var target_path: String = str(owner.get_path_to(target_rig))
    for track in range(clip.get_track_count()):
        if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
            continue
        var original_path: NodePath = clip.track_get_path(track)
        if original_path.get_subname_count() == 0:
            continue
        var bone_name: String = str(original_path.get_subname(0))
        var source_idx: int = source_rig.find_bone(bone_name)
        var target_name: String = _target_bone(bone_name)
        var target_idx: int = target_rig.find_bone(target_name) if target_name != "" else -1
        if source_idx < 0 or target_idx < 0:
            rejected.append(bone_name)
            continue
        var src_rest: Quaternion = source_rig.get_bone_rest(source_idx).basis.get_rotation_quaternion()
        var dst_rest: Quaternion = target_rig.get_bone_rest(target_idx).basis.get_rotation_quaternion()
        var index: int = rewritten.add_track(Animation.TYPE_ROTATION_3D)
        rewritten.track_set_path(index, NodePath(target_path + ":" + target_name))
        rewritten.track_set_interpolation_type(index, clip.track_get_interpolation_type(track))
        for key in range(clip.track_get_key_count(track)):
            var time: float = clip.track_get_key_time(track, key)
            var authored: Quaternion = clip.track_get_key_value(track, key)
            var motion: Quaternion = src_rest.inverse() * authored
            var mapped: Quaternion = (dst_rest * motion).normalized()
            rewritten.track_insert_key(index, time, mapped)
        shared_tracks += 1
    return {"clip": rewritten, "tracks": shared_tracks, "missing": rejected}

static func install(source_scene: Node, target_rig: Skeleton3D, target_owner: Node3D) -> Dictionary:
    var src_rig: Skeleton3D = _find_skeleton(source_scene)
    var src_player: AnimationPlayer = _find_animation_player(source_scene)
    if src_rig == null or src_player == null or target_rig == null:
        return {"ok":false, "reason":"missing actual animation player or skeleton"}
    var shared: int = 0
    for idx in range(src_rig.get_bone_count()):
        var source_name: String = str(src_rig.get_bone_name(idx))
        var dest_name: String = _target_bone(source_name)
        if dest_name != "" and target_rig.find_bone(dest_name) >= 0:
            shared += 1
    if shared < MIN_SHARED_BONES:
        return {"ok":false, "reason":"insufficient matching skeleton names", "shared":shared}
    var list: PackedStringArray = src_player.get_animation_list()
    var selected: Dictionary = {
        "idle": _select_name(list, ["idle_loop", "idle"]),
        "walk": _select_name(list, ["walk_fwd", "walk_loop", "walk"]),
        "run": _select_name(list, ["jog_fwd", "run_fwd", "sprint_fwd", "jog", "run"])
    }
    for key in selected:
        if selected[key] == "":
            return {"ok":false, "reason":"no required animation "+key,
                "available":Array(list), "shared":shared}
    var lib := AnimationLibrary.new()
    var track_counts: Dictionary = {}
    for key in ["idle", "walk", "run"]:
        var source_clip: Animation = src_player.get_animation(str(selected[key]))
        var result: Dictionary = _retarget_rotations(source_clip, src_rig, target_rig, target_owner)
        var tracks: int = int(result["tracks"])
        if tracks < 25:
            return {"ok":false, "reason":"too few mapped tracks for "+key,
                "tracks":tracks, "missing":result["missing"],"shared":shared}
        lib.add_animation(key, result["clip"])
        track_counts[key] = tracks
    var driver := AnimationPlayer.new()
    driver.name = "V21LicenseVerifiedAnimationPreview"
    target_owner.add_child(driver)
    driver.root_node = NodePath("..")
    driver.add_animation_library("v21", lib)
    return {"ok":true, "player":driver, "source_clips":selected,
        "shared_bones":shared, "tracks":track_counts,
        "note":"QA preview only. Foot planting, rest orientation, mesh quality and gameplay blending not yet approved."}
