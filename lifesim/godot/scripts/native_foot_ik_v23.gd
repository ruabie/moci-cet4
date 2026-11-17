extends RefCounted
class_name NativeFootIkV23

# Godot 4.7.2 TwoBoneIK3D test-only foot planting; not a production player
# module until real footage and visual acceptance. Foot sole is still a
# bind-pose mesh AABB proxy, NOT sampled skinned shoe vertices.
const HUMANOID: Dictionary = {
    "Root":"Root", "Hips":"Hips", "Spine":"Abdomen",
    "Chest":"Chest", "Neck":"Neck", "Head":"Head",
    "LeftShoulder":"Shoulder.L", "LeftUpperArm":"UpperArm.L",
    "LeftLowerArm":"LowerArm.L", "LeftHand":"Hand.L",
    "RightShoulder":"Shoulder.R", "RightUpperArm":"UpperArm.R",
    "RightLowerArm":"LowerArm.R", "RightHand":"Hand.R",
    "LeftUpperLeg":"UpperLeg.L", "LeftLowerLeg":"LowerLeg.L",
    "LeftFoot":"Foot.L", "RightUpperLeg":"UpperLeg.R",
    "RightLowerLeg":"LowerLeg.R", "RightFoot":"Foot.R"
}
const FOOT_TARGET_REACH_M: float = 0.62
const STANCE_CUTOFF_M: float = 0.08

static func _world_ankle(rig: Skeleton3D, side: String) -> Vector3:
    var idx: int = rig.find_bone("Foot." + side)
    if idx < 0:
        return Vector3(INF,INF,INF)
    return rig.global_transform * rig.get_bone_global_pose(idx).origin

static func _ground_at(player: CityPlayer, xz: Vector3) -> float:
    var query := PhysicsRayQueryParameters3D.create(
        xz + Vector3.UP * 2.0, xz - Vector3.UP * 3.0, 1, [player.get_rid()])
    var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
    return float(result["position"].y) if not result.is_empty() else INF

static func _ancestor(rig: Skeleton3D, child: int, parent: int) -> bool:
    var search: int = child
    for i in range(12):
        search = rig.get_bone_parent(search)
        if search < 0:
            return false
        if search == parent:
            return true
    return false

static func install(player: CityPlayer) -> Dictionary:
    var rig: Skeleton3D = player.rig
    if rig == null:
        return {"ok":false,"error":"no skinned target skeleton"}
    # The standard profile is used for *explicit semantic validation*.
    # Do not rename/rewrite the imported rig or claim rest-pose normalization.
    var profile := SkeletonProfileHumanoid.new()
    var bone_map := BoneMap.new()
    bone_map.profile = profile
    var known: Dictionary = {}
    for n in range(profile.get_bone_count()):
        known[str(profile.get_bone_name(n))] = true
    var matched: int = 0
    for semantic in HUMANOID:
        if not known.has(semantic):
            return {"ok":false,"error":"unexpected Godot 4.7 humanoid profile bone "+semantic}
        var source_name: String = str(HUMANOID[semantic])
        if rig.find_bone(source_name) < 0:
            return {"ok":false,"error":"target skeleton missing "+source_name}
        bone_map.set_skeleton_bone_name(StringName(semantic),StringName(source_name))
        if str(bone_map.get_skeleton_bone_name(StringName(semantic))) != source_name:
            return {"ok":false,"error":"BoneMap did not retain "+semantic}
        matched += 1
    if matched < 18:
        return {"ok":false,"error":"too few profile-mapped bones","matched":matched}
    for side in ["L","R"]:
        var root_bone: int = rig.find_bone("UpperLeg." + side)
        var middle: int = rig.find_bone("LowerLeg." + side)
        var end: int = rig.find_bone("Foot." + side)
        if root_bone < 0 or middle < 0 or end < 0:
            return {"ok":false,"error":"actual two-bone IK chain missing: "+side}
        if not _ancestor(rig,middle,root_bone) or not _ancestor(rig,end,middle):
            return {"ok":false,"error":"wrong skeleton leg hierarchy: "+side}
    var ik := TwoBoneIK3D.new()
    ik.name = "V23NativeTwoBoneIkPreview"
    rig.add_child(ik)
    ik.setting_count = 2
    ik.influence = 1.0
    ik.active = false  # source pose capture first; enable only after targets set
    var markers: Dictionary = {}
    var poles: Dictionary = {}
    for i in range(2):
        var side: String = "L" if i == 0 else "R"
        var marker := Marker3D.new()
        marker.name = "V23GroundFootTarget" + side
        player.add_child(marker)
        var pole := Marker3D.new()
        pole.name = "V23KneePole" + side
        player.add_child(pole)
        ik.set_root_bone_name(i, "UpperLeg."+side)
        ik.set_middle_bone_name(i, "LowerLeg."+side)
        ik.set_end_bone_name(i, "Foot."+side)
        ik.set_target_node(i, ik.get_path_to(marker))
        ik.set_pole_node(i, ik.get_path_to(pole))
        ik.set_pole_direction(i, SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z)
        markers[side] = marker
        poles[side] = pole
    return {
        "ok":true,"ik":ik,"targets":markers,"poles":poles,
        "profile":profile,"bone_map":bone_map,"mapped_humanoid":matched,
        "solver":"TwoBoneIK3D (Godot 4.7.2 native)",
        "foot_chain":["UpperLeg.L","LowerLeg.L","Foot.L",
                      "UpperLeg.R","LowerLeg.R","Foot.R"]
    }

static func _keep_stance(foot_world: Vector3, target_y: float) -> bool:
    return foot_world.y <= target_y + STANCE_CUTOFF_M

static func aim(player: CityPlayer, setup: Dictionary, shoe_offset: float,
        anchors: Dictionary) -> Dictionary:
    var rig: Skeleton3D = player.rig
    var measurements: Dictionary = {}
    for side in ["L","R"]:
        var ankle: Vector3 = _world_ankle(rig,side)
        var ground_y: float = _ground_at(player,ankle)
        if not is_finite(ground_y):
            return {"ok":false,"error":"real street physics ray missed: "+side}
        var shoe_y: float = ground_y + shoe_offset
        var stance: bool = _keep_stance(ankle,shoe_y)
        var target_xz: Vector3 = ankle
        if stance and anchors.has(side):
            var previous: Vector3 = anchors[side]
            target_xz.x = previous.x
            target_xz.z = previous.z
        if stance:
            anchors[side] = Vector3(target_xz.x,shoe_y,target_xz.z)
        else:
            anchors.erase(side)
        # A swinging foot remains above the street; IK only reaches down to
        # world ground when the clip is in stance, rather than glueing both.
        var target_y: float = shoe_y if stance else maxf(ankle.y,shoe_y+0.04)
        var marker: Marker3D = setup["targets"][side] as Marker3D
        marker.global_position = Vector3(target_xz.x,target_y,target_xz.z)
        var knee_idx: int = rig.find_bone("LowerLeg."+side)
        var knee: Vector3 = rig.global_transform * rig.get_bone_global_pose(knee_idx).origin
        var pole: Marker3D = setup["poles"][side] as Marker3D
        pole.global_position = knee + Vector3(0.0,0.0,-0.75)
        measurements[side] = {
            "stance":stance,"ground_y":ground_y,
            "before_target_error_m":ankle.distance_to(marker.global_position),
            "desired_ankle_y":target_y,
            "animated_ankle_y":ankle.y
        }
    return {"ok":true,"measurements":measurements}
