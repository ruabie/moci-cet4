extends CuratedInteriorsV13
class_name WalkableMartV15

# One physical building, no separate teleport room. Local +Z faces the road.
# Dimensions are tied to CuratedInteriorsV12._shell("mart") rather than arbitrary
# camera zones, so the room state changes only after crossing the real doorway.
const HALF_WIDTH: float = 5.9
const HALF_DEPTH: float = 6.1
const DOOR_HALF: float = 1.175
var entry_events: int = 0

func is_inside_world(world_point: Vector3) -> bool:
    var p: Vector3 = to_local(world_point)
    return absf(p.x) < HALF_WIDTH - .18 and p.z > -HALF_DEPTH + .14 and p.z < HALF_DEPTH - .15 and p.y > -.20 and p.y < 4.0

func street_door_world() -> Vector3:
    return to_global(Vector3(0, .2, HALF_DEPTH + .85))

func interior_probe_world() -> Vector3:
    return to_global(Vector3(0, .2, HALF_DEPTH - 1.5))

func is_door_approach(world_point: Vector3) -> bool:
    var p: Vector3 = to_local(world_point)
    return absf(p.x) < DOOR_HALF - .15 and p.z >= HALF_DEPTH - .2 and p.z < HALF_DEPTH + 3.8
