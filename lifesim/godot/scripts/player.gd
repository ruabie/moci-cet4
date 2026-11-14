extends CharacterBody3D
class_name CityPlayer

const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const TURN_SPEED: float = 11.0
const MOUSE_SENSITIVITY: float = 0.0024

var camera_yaw: float = 0.0
var camera_pitch: float = -0.18
var camera_distance: float = 6.2
var camera: Camera3D
var camera_focus: Node3D
var character_visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var anim_clock: float = 0.0
var walking: bool = false

func _ready() -> void:
    name = "Player"
    collision_layer = 2
    collision_mask = 1
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.95
    add_child(collision)
    character_visual = Node3D.new()
    character_visual.name = "AvatarVisual"
    add_child(character_visual)
    _create_avatar()
    camera_focus = Node3D.new()
    camera_focus.position.y = 1.65
    add_child(camera_focus)
    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.current = true
    camera.fov = 67.0
    camera.near = 0.05
    add_child(camera)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _update_camera(0.0)

func _build_part(parent: Node3D, size: Vector3, position: Vector3, color: Color, roughness: float = 0.85) -> Node3D:
    var n := Node3D.new()
    n.position = position
    parent.add_child(n)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    mesh.material_override = m
    n.add_child(mesh)
    return n

func _create_avatar() -> void:
    # Prototype avatar with separate animated limbs; replace with rigged GLB in V0.4.
    _build_part(character_visual, Vector3(0.76, 0.90, 0.39), Vector3(0, 1.41, 0), Color("506a7a"))
    _build_part(character_visual, Vector3(0.51, 0.51, 0.48), Vector3(0, 2.11, 0), Color("eac6a0"))
    _build_part(character_visual, Vector3(0.55, 0.15, 0.51), Vector3(0, 2.40, 0), Color("2b2d34"))
    _build_part(character_visual, Vector3(0.68, 0.36, 0.40), Vector3(0, 0.89, 0), Color("304052"))
    left_arm = _build_part(character_visual, Vector3(0.23, 0.78, 0.24), Vector3(-0.49, 1.48, 0), Color("506a7a"))
    right_arm = _build_part(character_visual, Vector3(0.23, 0.78, 0.24), Vector3(0.49, 1.48, 0), Color("506a7a"))
    left_leg = _build_part(character_visual, Vector3(0.27, 0.77, 0.29), Vector3(-0.19, 0.40, 0), Color("303e4b"))
    right_leg = _build_part(character_visual, Vector3(0.27, 0.77, 0.29), Vector3(0.19, 0.40, 0), Color("303e4b"))
    _build_part(left_leg, Vector3(0.29, 0.17, 0.44), Vector3(0, -0.33, -0.05), Color("f5eee5"))
    _build_part(right_leg, Vector3(0.29, 0.17, 0.44), Vector3(0, -0.33, -0.05), Color("f5eee5"))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
        camera_pitch = clampf(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -0.68, 0.52)
    if event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(3.0, camera_distance - 0.5)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(9.0, camera_distance + 0.5)
    if event.is_action_pressed("ui_cancel"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis := Basis(Vector3.UP, camera_yaw)
    var desired := basis * Vector3(axis.x, 0.0, axis.y)
    var moving: bool = desired.length_squared() > 0.005
    var speed: float = RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
    if moving:
        desired = desired.normalized()
        velocity.x = move_toward(velocity.x, desired.x * speed, delta * 22.0)
        velocity.z = move_toward(velocity.z, desired.z * speed, delta * 22.0)
        # The avatar faces the movement vector. Godot forward is -Z.
        var target_angle: float = atan2(-desired.x, -desired.z)
        character_visual.rotation.y = lerp_angle(character_visual.rotation.y, target_angle, minf(1.0, delta * TURN_SPEED))
    else:
        velocity.x = move_toward(velocity.x, 0.0, delta * 24.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 24.0)
    velocity.y -= 18.0 * delta
    move_and_slide()
    walking = moving and is_on_floor()
    if walking:
        anim_clock += delta * (12.0 if Input.is_action_pressed("run") else 8.0)
    else:
        anim_clock = lerpf(anim_clock, 0.0, delta * 5.0)
    var sway: float = sin(anim_clock) * (0.47 if walking else 0.0)
    left_leg.rotation.x = sway
    right_leg.rotation.x = -sway
    left_arm.rotation.x = -sway * 0.65
    right_arm.rotation.x = sway * 0.65
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    if camera == null:
        return
    var pivot: Vector3 = global_position + Vector3.UP * 1.70
    var aim: Vector3 = pivot + Vector3(sin(camera_yaw) * camera_distance * cos(camera_pitch),
        camera_distance * (0.20 - sin(camera_pitch)), cos(camera_yaw) * camera_distance * cos(camera_pitch))
    # Camera collision against buildings/ground prevents view occlusion.
    if delta > 0.0:
        var query := PhysicsRayQueryParameters3D.create(pivot, aim, 1)
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            aim = pivot.lerp(hit["position"], 0.90)
    var lerp_value: float = minf(1.0, delta * 15.0) if delta > 0.0 else 1.0
    camera.global_position = camera.global_position.lerp(aim, lerp_value)
    camera.look_at(pivot, Vector3.UP)