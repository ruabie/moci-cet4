extends CharacterBody3D
class_name CityPlayer

# V0.5: a self-contained glTF 2.0 skinned character, animated through Skeleton3D.
# No external runtime asset/CDN dependency.
const AVATAR_SCENE: String = CharacterArtV18.PLAYER_FILE
const WALK_SPEED: float = 4.7
const RUN_SPEED: float = 7.5
const TURN_SPEED: float = 9.0
const MOUSE_SENSITIVITY: float = 0.0024

var camera_yaw: float = -1.23
var camera_pitch: float = -0.12
var camera_distance: float = 4.6
var camera: Camera3D
var camera_occlusion_radius: float = .23
var camera_collision_activations: int = 0
var camera_collision_shape: SphereShape3D
var camera_sweep_query: PhysicsShapeQueryParameters3D
var character_visual: Node3D
var rig: Skeleton3D
var anim_clock: float = 0.0
var anim_weight: float = 0.0
var walk_speed_ratio: float = 1.0
var animation_verified: bool = false

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
    animation_verified = true
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

func _pose(name: String, x: float, y: float = 0.0) -> void:
    CharacterArtV18.pose(rig, name, x, y)

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
    # Stride frequency scales with *actual* movement, minimizing foot sliding.
    if horizontal_speed > 0.08:
        anim_clock += delta * horizontal_speed * 1.48
    var s: float = sin(anim_clock)
    var power: float = anim_weight * (0.68 if running else 0.46)
    _pose("LeftThigh", s * power)
    _pose("RightThigh", -s * power)
    _pose("LeftShin", maxf(0.0, -s) * .76 * anim_weight)
    _pose("RightShin", maxf(0.0, s) * .76 * anim_weight)
    # Modular CC0 characters ship in T-pose. Rest the arms at the torso;
    # animate small opposite swings around that authored idle offset.
    _pose("LeftUpperArm", -1.13 - s * power * .28, -.08)
    _pose("RightUpperArm", -1.13 + s * power * .28, .08)
    _pose("LeftForeArm", -.16 - maxf(0.0,s) * .16 * anim_weight)
    _pose("RightForeArm", -.16 - maxf(0.0,-s) * .16 * anim_weight)
    _pose("Spine", 0.085 if running else 0.015, -s * .03 * anim_weight)
    _pose("Head", 0.0, s * .025 * anim_weight)
    _pose("LeftFoot", -s * power * .18)
    _pose("RightFoot", s * power * .18)
    character_visual.position.y = absf(s) * .025 * anim_weight
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
    camera.global_position = camera.global_position.lerp(aim, smoothing)
    camera.look_at(pivot + Vector3.UP * .02)