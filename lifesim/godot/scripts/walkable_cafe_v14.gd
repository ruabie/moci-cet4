extends CuratedInteriorsV13
class_name WalkableCafeV14

# V0.14: Same physical world as the street. No fake exterior view, no teleport.
# Local +Z points through the open 2.1 m cafe door toward the sidewalk.
const HALF_WIDTH: float = 4.7
const HALF_DEPTH: float = 4.4
const DOOR_HALF: float = 1.05
var entry_events: int = 0

func _exterior_window_view() -> void:
    # The real Aokawa street is directly outside the glass.
    pass

func is_inside_world(world_point: Vector3) -> bool:
    var p: Vector3 = to_local(world_point)
    return absf(p.x) < HALF_WIDTH - 0.36 and p.z > -HALF_DEPTH + 0.22 and p.z < HALF_DEPTH - 0.20 and p.y > -0.20 and p.y < 3.40

func is_door_approach(world_point: Vector3) -> bool:
    var p: Vector3 = to_local(world_point)
    return absf(p.x) < DOOR_HALF - 0.12 and p.z >= HALF_DEPTH - 0.25 and p.z < HALF_DEPTH + 3.8

func street_door_world() -> Vector3:
    return to_global(Vector3(0, 0.2, HALF_DEPTH + 0.8))

func interior_probe_world() -> Vector3:
    return to_global(Vector3(0, 0.2, HALF_DEPTH - 1.15))
