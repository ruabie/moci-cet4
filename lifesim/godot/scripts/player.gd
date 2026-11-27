extends CharacterBody3D
class_name CityPlayer

# V0.5: a self-contained glTF 2.0 skinned character, animated through Skeleton3D.
# No external runtime asset/CDN dependency.
const AVATAR_SCENE: String = CharacterArtV18.PLAYER_FILE
const WALK_SPEED: float = 4.7
const RUN_SPEED: float = 7.5
const TURN_SPEED: float = 9.0
const MOUSE_SENSITIVITY: float = 0.0024
# V0.20: a full two-step gait cycle per travelled distance, not per frame.
const GAIT_CYCLE_METRES: float = 2.30

var camera_yaw: float = -1.23
var camera_pitch: float = -0.12
var camera_distance: float = 4.6
var camera: Camera3D
var camera_occlusion_radius: float = .23
var camera_collision_activations: int = 0
var camera_collision_shape: SphereShape3D
var camera_sweep_query: PhysicsShapeQueryParameters3D
var character_visual: Node3D
# V0.40: local third-person render only. Physical avatar collision/rig remain.
# Fades the original skinned mesh at very short camera radius to prevent
# the model's face/hair covering the entire picture at a real solid wall.
var avatar_render_meshes: Array[MeshInstance3D] = []
var avatar_fade_materials: Array[Dictionary] = []
var avatar_camera_fade: float = 0.0
const CAMERA_FADE_OUTER_RADIUS: float = 1.25
const CAMERA_FADE_INNER_RADIUS: float = 0.48
var rig: Skeleton3D
var anim_clock: float = 0.0
var anim_weight: float = 0.0
var walk_speed_ratio: float = 1.0
var animation_verified: bool = false
var resting_foot_height: float = 0.0
var gait_foot_lift: float = 0.0  # Signed visual-root height offset (negative lowers floating ankles).
var physics_tick_counter: int = 0
var gait_stride_phase: float = 0.0

func _ready() -> void:
    name = "Player"
    collision_layer = 2
    collision_mask = 1
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.33
    capsule.height = 1.96
    collision.shape = capsule
    collision.position.y = 0.98
    add_child(collision)
    character_visual = Node3D.new()
    character_visual.name = "AvatarVisual"
    add_child(character_visual)
    var imported_scene: PackedScene = load(AVATAR_SCENE)
    if imported_scene == null:
        push_error("Missing authored glTF character: " + AVATAR_SCENE)
        return
    var avatar: Node3D = imported_scene.instantiate() as Node3D
    if avatar == null:
        push_error("glTF character did not import as a 3D scene")
        return
    avatar.name = "V18QuaterniusCivilian"
    # The upstream FBX-converted CC0 rig points local +Z; our game walks -Z.
    avatar.rotation.y = PI
    character_visual.add_child(avatar)
    var height: float = CharacterArtV18.fit_to_height(avatar, 1.80)
    if height < 1.7:
        push_error("V18 avatar scale normalization failed")
        return
    rig = CharacterArtV18.find_rig(avatar)
    if rig == null or rig.get_bone_count() < 40:
        push_error("Rigged avatar requires at least 15 Skeleton3D bones")
        return
    for required_bone in ["Hips", "Spine", "Chest", "Head", "LeftUpperArm", "RightUpperArm", "LeftThigh", "RightThigh", "LeftShin", "RightShin"]:
        if not CharacterArtV18.has_bone(rig, required_bone):
            push_error("glTF character is missing bone " + required_bone)
            return
    # Capture only the current local player's original imported avatar meshes.
    # We never hide buildings, walls, NPCs, physics shapes, or animation rig.
    _collect_avatar_render_meshes(character_visual)
    if avatar_render_meshes.is_empty():
        push_error("V40 near-camera visibility needs original skinned avatar geometry")
    animation_verified = true
    resting_foot_height = _lowest_foot_height_relative_to_body()
    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.current = true
    camera.fov = 63.0
    camera.near = 0.08
    add_child(camera)
    # Reuse the sweep shape/query rather than allocating 60 collision shapes/sec.
    camera_collision_shape = SphereShape3D.new()
    camera_collision_shape.radius = camera_occlusion_radius
    camera_sweep_query = PhysicsShapeQueryParameters3D.new()
    camera_sweep_query.shape = camera_collision_shape
    camera_sweep_query.collision_mask = 1
    camera_sweep_query.exclude = [get_rid()]
    # Browsers permit Pointer Lock only after a real mouse gesture.
    if not OS.has_feature("web"):
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _update_camera(0.0)

# Godot Web uses the Compatibility renderer. GeometryInstance3D.transparency
# is silently ignored there (unlike Forward+). Use actual per-surface ORIGINAL
# StandardMaterial3D alpha duplicates, and safely hide ONLY the local skinned
# avatar's MeshInstance3D when the camera retreats inside the player's head.
# Neither solution touches collider, Skeleton3D, other NPCs nor building meshes.
func _collect_avatar_render_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        avatar_render_meshes.append(mesh_instance)
        mesh_instance.visible = true
        if mesh_instance.mesh != null:
            if mesh_instance.material_override is BaseMaterial3D:
                _register_avatar_fade_material(mesh_instance, -1, mesh_instance.material_override)
            else:
                for surface_index in range(mesh_instance.mesh.get_surface_count()):
                    var old_override: Material = mesh_instance.get_surface_override_material(surface_index)
                    var source: Material = old_override
                    if source == null:
                        source = mesh_instance.mesh.surface_get_material(surface_index)
                    if source is BaseMaterial3D:
                        _register_avatar_fade_material(mesh_instance, surface_index, source, old_override)
    for child in node.get_children():
        _collect_avatar_render_meshes(child)


func _register_avatar_fade_material(
        mesh_instance: MeshInstance3D, surface: int, base: Material,
        original_override: Material = null) -> void:
    # Clone only the local player's material. Do NOT mutate a shared GLB
    # resource, since that would fade every NPC using the original asset.
    var original: BaseMaterial3D = base as BaseMaterial3D
    if original == null:
        return
    var faded: BaseMaterial3D = original.duplicate() as BaseMaterial3D
    if faded == null:
        return
    faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    avatar_fade_materials.append({
        "mesh":mesh_instance, "surface":surface,
        "original_override":original_override if surface >= 0 else base,
        "material":faded, "base_alpha":original.albedo_color.a
    })


func _update_avatar_camera_fade(actual_radius_m: float) -> void:
    var x: float = clampf(
        (CAMERA_FADE_OUTER_RADIUS - actual_radius_m)
        / (CAMERA_FADE_OUTER_RADIUS - CAMERA_FADE_INNER_RADIUS),
        0.0, 1.0)
    avatar_camera_fade = x * x * (3.0 - 2.0 * x)
    # At radius <0.48m the camera is literally inside the face/hair geometry:
    # disable only this local model's GPU draw, never gameplay collision.
    # At normal third-person distance the original unmodified GLB surfaces
    # are fully restored, avoiding the slow transparency render pipeline.
    for mesh_instance in avatar_render_meshes:
        if is_instance_valid(mesh_instance):
            mesh_instance.visible = avatar_camera_fade < .995
    for binding in avatar_fade_materials:
        var mesh_instance: MeshInstance3D = binding["mesh"] as MeshInstance3D
        if mesh_instance == null or not is_instance_valid(mesh_instance):
            continue
        var surface_index: int = int(binding["surface"])
        var original: Material = binding["original_override"] as Material
        var replacement: Material = original
        if avatar_camera_fade > .001 and avatar_camera_fade < .999:
            var faded: BaseMaterial3D = binding["material"] as BaseMaterial3D
            var albedo: Color = faded.albedo_color
            albedo.a = float(binding["base_alpha"]) * (1.0 - avatar_camera_fade)
            faded.albedo_color = albedo
            replacement = faded
        if surface_index < 0:
            mesh_instance.material_override = replacement
        else:
            mesh_instance.set_surface_override_material(surface_index, replacement)


func _pose(name: String, x: float, y: float = 0.0) -> void:
    CharacterArtV18.pose(rig, name, x, y)

func _lowest_foot_height_relative_to_body() -> float:
    # Foot *bones* are ankle references, not shoe sole collision samples.
    # Recording them in the idle bind pose avoids assuming a fixed model origin.
    if rig == null or character_visual == null:
        return 0.0
    var lowest: float = INF
    for semantic in ["LeftFoot", "RightFoot"]:
        var bone_name: String = CharacterArtV18.joint_name(rig, semantic)
        if bone_name == "":
            continue
        var foot_index: int = rig.find_bone(bone_name)
        var foot_world: Vector3 = rig.global_transform * rig.get_bone_global_pose(foot_index).origin
        lowest = minf(lowest, foot_world.y - global_position.y - character_visual.position.y)
    return lowest if lowest != INF else 0.0

func foot_clearance_vs_idle() -> float:
    # Negative means at least one ankle reference is below its idle reference.
    return _lowest_foot_height_relative_to_body() + gait_foot_lift - resting_foot_height

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
        camera_pitch = clampf(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -0.56, 0.39)
    if event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(2.7, camera_distance - 0.35)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(8.0, camera_distance + 0.35)
    if event.is_action_pressed("ui_cancel"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
    physics_tick_counter += 1
    var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis := Basis(Vector3.UP, camera_yaw)
    var desired: Vector3 = basis * Vector3(axis.x, 0, axis.y)
    var moving: bool = desired.length_squared() > 0.005
    var running: bool = Input.is_action_pressed("run") and moving
    var top_speed: float = RUN_SPEED if running else WALK_SPEED
    if moving:
        desired = desired.normalized()
        velocity.x = move_toward(velocity.x, desired.x * top_speed, delta * 16.0)
        velocity.z = move_toward(velocity.z, desired.z * top_speed, delta * 16.0)
        var facing: float = atan2(-desired.x, -desired.z)
        character_visual.rotation.y = lerp_angle(character_visual.rotation.y, facing, minf(1.0, delta * TURN_SPEED))
    else:
        velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    move_and_slide()
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    var stride_weight: float = clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0) if is_on_floor() else 0.0
    anim_weight = move_toward(anim_weight, stride_weight, delta * 5.0)
    # V0.19 completed a full cycle over ~4.25m, despite a ~1.8m avatar.
    # Shortening distance-per-cycle reduces unrealistic drifting shoes.
    if horizontal_speed > 0.08 and is_on_floor():
        anim_clock += delta * horizontal_speed * TAU / GAIT_CYCLE_METRES
    gait_stride_phase = fposmod(anim_clock, TAU)
    var s: float = sin(gait_stride_phase)
    var swing_left: float = maxf(0.0, -s)
    var swing_right: float = maxf(0.0, s)
    var power: float = anim_weight * (0.77 if running else 0.58)
    _pose("LeftThigh", s * power)
    _pose("RightThigh", -s * power)
    # Alternate knee flexion during swing; the stance leg stays comparatively
    # straight. Keep knee bends nonnegative to avoid hyperextension.
    _pose("LeftShin", swing_left * 0.91 * anim_weight)
    _pose("RightShin", swing_right * 0.91 * anim_weight)
    _pose("LeftUpperArm", -1.13 - s * power * 0.45, -.08)
    _pose("RightUpperArm", -1.13 + s * power * 0.45, .08)
    _pose("LeftForeArm", -.16 - swing_right * .24 * anim_weight)
    _pose("RightForeArm", -.16 - swing_left * .24 * anim_weight)
    _pose("Spine", 0.072 if running else 0.022, -s * .045 * anim_weight)
    _pose("Head", 0.0, s * .028 * anim_weight)
    _pose("LeftFoot", -s * power * .22 - swing_left * .12 * anim_weight)
    _pose("RightFoot", s * power * .22 - swing_right * .12 * anim_weight)

    # V0.20.1: a high ankle above the idle reference is ALSO an error
    # (floating shoes). Allow at most 5.5cm visual-root descent while the
    # collider remains fixed. This is a bounded, diagnostic two-foot floor
    # approximation, NOT exact mesh-sole contact or proper IK.
    var correction: float = clampf(
        resting_foot_height - _lowest_foot_height_relative_to_body(), -0.055, 0.105
    )
    if correction > gait_foot_lift:
        gait_foot_lift = correction  # Correct floor penetration immediately.
    else:
        gait_foot_lift = move_toward(gait_foot_lift, correction, delta * 2.4)
    character_visual.position.y = gait_foot_lift
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    if camera == null:
        return
    var pivot: Vector3 = global_position + Vector3.UP * 1.56
    var aim: Vector3 = pivot + Vector3(sin(camera_yaw) * camera_distance * cos(camera_pitch), camera_distance * (0.12 - sin(camera_pitch)), cos(camera_yaw) * camera_distance * cos(camera_pitch))
    if delta > 0.0:
        # Sphere sweep is safer than a single ray: it keeps the camera near-plane
        # from clipping through narrow door frames and interior walls.
        camera_sweep_query.transform = Transform3D(Basis(), pivot)
        camera_sweep_query.motion = aim - pivot
        var sweep: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(camera_sweep_query)
        if sweep.size() >= 2 and sweep[0] < 0.999:
            var distance_factor: float = clampf(sweep[0] - .035, .05, 1.0)
            aim = pivot.lerp(aim, distance_factor)
            camera_collision_activations += 1
    # A camera backing into a wall must retract immediately; returning outward
    # can ease in slowly. Never interpolate through an obstructing surface.
    var current_radius: float = pivot.distance_to(camera.global_position)
    var desired_radius: float = pivot.distance_to(aim)
    var smoothing: float = minf(1.0, delta * (34.0 if desired_radius < current_radius else 5.5)) if delta > 0.0 else 1.0
    var candidate: Vector3 = camera.global_position.lerp(aim, smoothing)
    if delta > 0.0:
        # V39 real occlusion QA proved a transition-frame bug: although
        # aim is collision-checked, smoothing FROM the previous camera
        # point can sweep THROUGH a solid wall. Re-test the FINAL candidate
        # from the unobstructed character pivot and clamp BEFORE display.
        # No walls are hidden, and all original world collision stays on.
        camera_sweep_query.transform = Transform3D(Basis(), pivot)
        camera_sweep_query.motion = candidate - pivot
        var final_safe: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(camera_sweep_query)
        if final_safe.size() >= 2 and final_safe[0] < 0.999:
            var safe_fraction: float = clampf(final_safe[0] - .045, 0.0, 1.0)
            candidate = pivot.lerp(candidate, safe_fraction)
            camera_collision_activations += 1
    camera.global_position = candidate
    camera.look_at(pivot + Vector3.UP * .02)
    _update_avatar_camera_fade(pivot.distance_to(camera.global_position))