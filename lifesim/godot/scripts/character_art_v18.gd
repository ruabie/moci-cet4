extends RefCounted
class_name CharacterArtV18

const BASE: String = "res://art/characters/v18/"
const PLAYER_FILE: String = BASE + "player_casual.glb"
const RESIDENT_FILES: Array[String] = [
    BASE + "casual_female.glb",
    BASE + "worker_male.glb",
    BASE + "formal_female.glb",
    BASE + "suit_male.glb",
    BASE + "worker_female.glb",
    BASE + "casual_male.glb"
]
# Old procedural and new Quaternius joints have different names.
const ALIASES: Dictionary = {
    "LeftThigh": "UpperLeg.L", "RightThigh": "UpperLeg.R",
    "LeftShin": "LowerLeg.L", "RightShin": "LowerLeg.R",
    "LeftFoot": "Foot.L", "RightFoot": "Foot.R",
    "LeftUpperArm": "UpperArm.L", "RightUpperArm": "UpperArm.R",
    "LeftForeArm": "LowerArm.L", "RightForeArm": "LowerArm.R",
    "Spine": "Abdomen"
}

static func find_rig(node: Node) -> Skeleton3D:
    if node is Skeleton3D and has_bone(node as Skeleton3D, "LeftThigh"):
        return node as Skeleton3D
    for child in node.get_children():
        var found: Skeleton3D = find_rig(child)
        if found != null:
            return found
    return null

static func joint_name(rig: Skeleton3D, semantic: String) -> String:
    if rig == null:
        return ""
    if rig.find_bone(semantic) >= 0:
        return semantic
    var replacement: String = str(ALIASES.get(semantic, ""))
    if replacement != "" and rig.find_bone(replacement) >= 0:
        return replacement
    return ""

static func has_bone(rig: Skeleton3D, semantic: String) -> bool:
    return joint_name(rig, semantic) != ""

static func pose(rig: Skeleton3D, semantic: String, pitch: float, yaw: float = 0.0) -> void:
    var name: String = joint_name(rig, semantic)
    if name == "":
        return
    rig.set_bone_pose_rotation(rig.find_bone(name), Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch))

static func _measure(node: Node, root_model: Node3D, bounds: Dictionary) -> void:
    if node is MeshInstance3D:
        var inst := node as MeshInstance3D
        if inst.mesh != null:
            var t: Transform3D = root_model.global_transform.affine_inverse() * inst.global_transform
            var b: AABB = t * inst.mesh.get_aabb()
            bounds["low"] = minf(float(bounds["low"]), b.position.y)
            bounds["high"] = maxf(float(bounds["high"]), b.end.y)
    for child in node.get_children():
        _measure(child, root_model, bounds)

static func fit_to_height(model: Node3D, metres: float) -> float:
    var bounds: Dictionary = {"low": INF, "high": -INF}
    _measure(model, model, bounds)
    var low: float = float(bounds["low"])
    var high: float = float(bounds["high"])
    var raw_height: float = high - low
    if raw_height < 0.1 or raw_height > 50.0:
        push_error("V18 humanoid imported at implausible dimensions: " + str(raw_height))
        return -1.0
    var ratio: float = metres / raw_height
    model.scale = Vector3.ONE * ratio
    model.position.y = -low * ratio
    return metres
