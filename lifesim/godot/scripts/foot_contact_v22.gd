extends RefCounted
class_name FootContactV22

# QA-only two-foot grounding of a rigged CC0 character.
# It corrects only the *rendered avatar* root height; physics, movement and
# work/save state remain V0.20. This is NOT true sole-mesh collision or IK.

static func _foot_position(rig: Skeleton3D, name: String) -> Vector3:
    var index: int = rig.find_bone(name)
    if index < 0:
        return Vector3(INF, INF, INF)
    return rig.global_transform * rig.get_bone_global_pose(index).origin

static func _foot_positions(rig: Skeleton3D) -> Array[Vector3]:
    return [_foot_position(rig, "Foot.L"), _foot_position(rig, "Foot.R")]

static func _find_shoes(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        if mesh.name.to_lower().contains("feet") and mesh.mesh != null:
            return mesh
    for child in node.get_children():
        var found: MeshInstance3D = _find_shoes(child)
        if found != null:
            return found
    return null

static func _static_mesh_floor(shoes: MeshInstance3D) -> float:
    var aabb: AABB = shoes.mesh.get_aabb()
    var low: float = INF
    for xx in [0.0, 1.0]:
        for yy in [0.0, 1.0]:
            for zz in [0.0, 1.0]:
                var p: Vector3 = aabb.position + aabb.size * Vector3(xx, yy, zz)
                low = minf(low, (shoes.global_transform * p).y)
    return low

static func setup(player: CityPlayer) -> Dictionary:
    var rig: Skeleton3D = player.rig
    var feet: Array[Vector3] = _foot_positions(rig)
    if not is_finite(feet[0].y) or not is_finite(feet[1].y):
        return {"ok":false, "error":"missing actual target foot bones"}
    var shoes: MeshInstance3D = _find_shoes(player.character_visual)
    if shoes == null:
        return {"ok":false, "error":"missing skinned shoe mesh; cannot assert sole height"}
    var static_mesh_bottom: float = _static_mesh_floor(shoes)
    var rest_ankle: float = minf(feet[0].y, feet[1].y)
    var offset: float = rest_ankle - static_mesh_bottom
    if not is_finite(offset) or offset < -0.25 or offset > 0.55:
        return {"ok":false, "error":"implausible bind shoe offset",
                "ankle_minus_mesh_bottom":offset}
    return {"ok":true, "sole_offset_from_ankle":offset,
        "shoe_bind_bottom_y":static_mesh_bottom,
        "lowest_rest_ankle_y":rest_ankle,
        "method":"bind shoe mesh AABB + actual two ankle bones; proxy, NOT skinned sole vertex"}

static func _ground_y(player: CityPlayer) -> float:
    var center: Vector3 = player.global_position
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        center + Vector3.UP * 2.5, center - Vector3.UP * 4.0, 1,
        [player.get_rid()])
    var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
    return float(hit["position"].y) if not hit.is_empty() else INF

static func lock_preview_height(player: CityPlayer, model: Dictionary) -> Dictionary:
    if not bool(model.get("ok", false)):
        return {"ok":false, "error":"invalid shoe calibration"}
    var ground: float = _ground_y(player)
    if not is_finite(ground):
        return {"ok":false, "error":"actual street collision ground ray not found"}
    var shoes_offset: float = float(model["sole_offset_from_ankle"])
    var original_feet: Array[Vector3] = _foot_positions(player.rig)
    var ankle_min: float = minf(original_feet[0].y, original_feet[1].y)
    var before: float = ankle_min - shoes_offset - ground
    var correction: float = -before
    # Cap protects from accidental 'correcting' a broken upside-down rig.
    if absf(correction) > 0.85:
        return {"ok":false, "error":"large root correction indicates bad rig",
            "requested_correction_m":snappedf(correction,0.001)}
    player.character_visual.position.y += correction
    var after_poses: Array[Vector3] = _foot_positions(player.rig)
    var adjusted_min: float = minf(after_poses[0].y,after_poses[1].y)
    var after: float = adjusted_min - shoes_offset - ground
    var horizontal_separation: float = Vector2(
        after_poses[0].x - after_poses[1].x,
        after_poses[0].z - after_poses[1].z).length()
    return {
        "ok":absf(after) < .025,
        "ground_world_y":snappedf(ground,.001),
        "before_proxy_sole_gap_m":snappedf(before,.001),
        "root_height_correction_m":snappedf(correction,.001),
        "after_proxy_sole_gap_m":snappedf(after,.001),
        "foot_ankle_horizontal_spread_m":snappedf(horizontal_separation,.001),
        "ankle_l_world_y":snappedf(after_poses[0].y,.001),
        "ankle_r_world_y":snappedf(after_poses[1].y,.001),
        "limitation":"one ankle-based approximate shoe proxy grounded, no per-foot IK or actual skinned sole surface verification"
    }
