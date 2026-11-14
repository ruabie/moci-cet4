extends CharacterBody3D
class_name CityPlayer

# V0.4: hand-authored articulated stylized character. It is not a skinned GLB rig.
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const TURN_SPEED: float = 10.0
const MOUSE_SENSITIVITY: float = 0.0024

var camera_yaw: float = 0.30
var camera_pitch: float = -0.20
var camera_distance: float = 5.1
var camera: Camera3D
var character_visual: Node3D
var torso: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_elbow: Node3D
var right_elbow: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_knee: Node3D
var right_knee: Node3D
var anim_clock: float = 0.0
var walking: bool = false
var anim_weight: float = 0.0
var materials: Dictionary = {}

func _ready() -> void:
    name = "Player"
    collision_layer = 2
    collision_mask = 1
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.33
    capsule.height = 1.91
    collision.shape = capsule
    collision.position.y = 0.96
    add_child(collision)
    character_visual = Node3D.new()
    character_visual.name = "AvatarVisual"
    add_child(character_visual)
    _create_avatar()
    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.current = true
    camera.fov = 64.0
    camera.near = 0.08
    add_child(camera)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _update_camera(0.0)

func _mat(hex: String, roughness: float = 0.84, metallic: float = 0.0) -> StandardMaterial3D:
    var key := "%s_%s_%s" % [hex, roughness, metallic]
    if materials.has(key):
        return materials[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = roughness
    mat.metallic = metallic
    materials[key] = mat
    return mat

func _ellipsoid(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 16
    mesh.rings = 8
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = position
    part.scale = dimensions
    part.material_override = material
    parent.add_child(part)
    return part

func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = position
    part.material_override = material
    parent.add_child(part)

func _joint(parent: Node3D, location: Vector3, joint_name: String) -> Node3D:
    var n := Node3D.new()
    n.name = joint_name
    n.position = location
    parent.add_child(n)
    return n

func _create_avatar() -> void:
    # 1.94m avatar: rounded torso, hinged shoulders/knees, feet and hands.
    var jacket := _mat("#536a70")
    var jacket_light := _mat("#697e7e")
    var jacket_seam := _mat("#3b5359")
    var pants := _mat("#2e3e4b")
    var pants_light := _mat("#3d515e")
    var skin := _mat("#dcb495")
    var hair := _mat("#313437", 0.96)
    var shoes := _mat("#e9e5de")
    var sole := _mat("#6e7877")
    var strap := _mat("#34464b")
    torso = _joint(character_visual, Vector3(0, 0, 0), "UpperBody")
    _ellipsoid(torso, Vector3(0, 1.27, 0), Vector3(0.73, 0.73, 0.40), jacket)
    _ellipsoid(torso, Vector3(0, 1.00, 0.01), Vector3(0.55, 0.29, 0.35), pants)
    # Outer jacket placket, backpack and hood create useful silhouette from behind.
    _box(torso, Vector3(0, 1.30, -0.205), Vector3(0.037, 0.60, 0.03), jacket_seam)
    _ellipsoid(torso, Vector3(0, 1.33, 0.265), Vector3(0.56, 0.65, 0.22), strap)
    _ellipsoid(torso, Vector3(0, 1.64, 0.085), Vector3(0.56, 0.21, 0.38), jacket_light)
    _ellipsoid(torso, Vector3(0, 1.66, 0.012), Vector3(0.25, 0.25, 0.22), skin)
    _ellipsoid(torso, Vector3(0, 1.89, -0.025), Vector3(0.44, 0.48, 0.42), skin)
    _ellipsoid(torso, Vector3(0, 2.095, -0.005), Vector3(0.48, 0.22, 0.44), hair)
    _ellipsoid(torso, Vector3(0, 1.92, 0.163), Vector3(0.45, 0.27, 0.13), hair)
    for side in [-1.0, 1.0]:
        _ellipsoid(torso, Vector3(side * 0.225, 1.88, 0), Vector3(0.07, 0.12, 0.12), skin)
        _ellipsoid(torso, Vector3(side * 0.105, 1.93, -0.205), Vector3(0.055, 0.041, 0.025), hair)
    left_arm = _joint(torso, Vector3(-0.39, 1.53, 0.0), "LeftShoulder")
    right_arm = _joint(torso, Vector3(0.39, 1.53, 0.0), "RightShoulder")
    for arm in [left_arm, right_arm]:
        _ellipsoid(arm, Vector3(0, -0.22, 0), Vector3(0.24, 0.49, 0.25), jacket)
        _ellipsoid(arm, Vector3(0, -0.045, 0), Vector3(0.29, 0.25, 0.28), jacket_light)
    left_elbow = _joint(left_arm, Vector3(0, -0.44, 0), "LeftElbow")
    right_elbow = _joint(right_arm, Vector3(0, -0.44, 0), "RightElbow")
    for elbow in [left_elbow, right_elbow]:
        _ellipsoid(elbow, Vector3(0, -0.17, 0), Vector3(0.205, 0.40, 0.215), jacket_light)
        _ellipsoid(elbow, Vector3(0, -0.38, -0.01), Vector3(0.16, 0.15, 0.16), skin)
    left_leg = _joint(character_visual, Vector3(-0.165, 0.91, 0.0), "LeftHip")
    right_leg = _joint(character_visual, Vector3(0.165, 0.91, 0.0), "RightHip")
    for leg in [left_leg, right_leg]:
        _ellipsoid(leg, Vector3(0, -0.22, 0), Vector3(0.275, 0.48, 0.30), pants)
    left_knee = _joint(left_leg, Vector3(0, -0.44, 0), "LeftKnee")
    right_knee = _joint(right_leg, Vector3(0, -0.44, 0), "RightKnee")
    for knee in [left_knee, right_knee]:
        _ellipsoid(knee, Vector3(0, -0.18, 0), Vector3(0.23, 0.40, 0.26), pants_light)
        _ellipsoid(knee, Vector3(0, -0.36, -0.08), Vector3(0.27, 0.22, 0.42), shoes)
        _ellipsoid(knee, Vector3(0, -0.435, -0.08), Vector3(0.27, 0.08, 0.43), sole)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
        camera_pitch = clampf(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -0.55, 0.42)
    if event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(2.8, camera_distance - 0.40)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(8.5, camera_distance + 0.40)
    if event.is_action_pressed("ui_cancel"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis := Basis(Vector3.UP, camera_yaw)
    var desired := basis * Vector3(axis.x, 0, axis.y)
    var moving: bool = desired.length_squared() > 0.005
    var running: bool = Input.is_action_pressed("run") and moving
    var speed := RUN_SPEED if running else WALK_SPEED
    if moving:
        desired = desired.normalized()
        velocity.x = move_toward(velocity.x, desired.x * speed, delta * 22.0)
        velocity.z = move_toward(velocity.z, desired.z * speed, delta * 22.0)
        var angle := atan2(-desired.x, -desired.z)
        character_visual.rotation.y = lerp_angle(character_visual.rotation.y, angle, minf(1.0, delta * TURN_SPEED))
    else:
        velocity.x = move_toward(velocity.x, 0.0, delta * 24.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 24.0)
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    move_and_slide()
    walking = moving and is_on_floor()
    anim_weight = move_toward(anim_weight, 1.0 if walking else 0.0, delta * 7.5)
    if walking:
        anim_clock += delta * (12.0 if running else 8.0)
    var s := sin(anim_clock)
    var amp := (0.58 if running else 0.43) * anim_weight
    left_leg.rotation.x = s * amp
    right_leg.rotation.x = -s * amp
    left_knee.rotation.x = maxf(0.0, -s) * 0.72 * anim_weight
    right_knee.rotation.x = maxf(0.0, s) * 0.72 * anim_weight
    left_arm.rotation.x = -s * amp * 0.75
    right_arm.rotation.x = s * amp * 0.75
    left_elbow.rotation.x = -0.17 - maxf(0.0, s) * 0.25 * anim_weight
    right_elbow.rotation.x = -0.17 - maxf(0.0, -s) * 0.25 * anim_weight
    torso.rotation.x = lerpf(torso.rotation.x, 0.08 if running else 0.0, delta * 7.0)
    character_visual.position.y = absf(sin(anim_clock)) * (0.038 if running else 0.017) * anim_weight
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    if camera == null:
        return
    var pivot: Vector3 = global_position + Vector3.UP * 1.58
    var aim: Vector3 = pivot + Vector3(sin(camera_yaw) * camera_distance * cos(camera_pitch), camera_distance * (0.16 - sin(camera_pitch)), cos(camera_yaw) * camera_distance * cos(camera_pitch))
    if delta > 0.0:
        var query := PhysicsRayQueryParameters3D.create(pivot, aim, 1)
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            aim = pivot.lerp(hit["position"], 0.87)
    var smoothing: float = minf(1.0, delta * 15.0) if delta > 0.0 else 1.0
    camera.global_position = camera.global_position.lerp(aim, smoothing)
    camera.look_at(pivot, Vector3.UP)