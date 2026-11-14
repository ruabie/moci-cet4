extends SceneTree

# Run (with Godot 4.7.x available):
# godot --headless --path . --script res://tests/qa_headless.gd

func _initialize() -> void:
    call_deferred("run_contracts")

func fail(reason: String) -> void:
    printerr("QA FAIL: ", reason)
    quit(1)

func run_contracts() -> void:
    var now: Dictionary = WorldClock.snapshot()
    var actual_unix: int = int(Time.get_unix_time_from_system())
    if absi(actual_unix - int(now["unix"])) > 90:
        fail("WorldClock not within 90s of device UTC")
        return
    var state := CitySave.initial()
    if state["balance"] != 800:
        fail("incorrect initial balance")
        return
    if CitySave.purchase(state, "desk_lamp", 120) != true:
        fail("purchase rejected")
        return
    if state["balance"] != 680:
        fail("purchase charged wrong amount")
        return
    if CitySave.purchase(state, "desk_lamp", 120):
        fail("duplicate permanent item was charged")
        return
    if CitySave.purchase(state, "luxury_apartment", 900000):
        fail("overdraft purchase accepted")
        return
    if not CitySave.pay_job_once(state, "job-001", 70):
        fail("job didn't settle")
        return
    if CitySave.pay_job_once(state, "job-001", 70):
        fail("duplicate job paid twice")
        return
    if state["balance"] != 750:
        fail("wrong payout balance")
        return
    var sanitized: Dictionary = CitySave.sanitize(state)
    if sanitized.is_empty() or sanitized["balance"] != 750:
        fail("sanitizer damaged valid save")
        return
    if not CitySave.sanitize({"version":1,"balance":-100,"owned_items":[],"position":[0,0,0],"completed_job_ids":[]}).is_empty():
        fail("negative balance save accepted")
        return
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        fail("main scene failed to load")
        return
    var instance: Node = scene.instantiate()
    root.add_child(instance)
    await process_frame
    await physics_frame
    var avatar: Node = instance.get_node_or_null("Player")
    if avatar == null:
        fail("player not created")
        return
    if instance.get_node_or_null("AokawaDistrict") == null:
        fail("3D district missing")
        return
    print("QA PASS: clock, purchase, idempotent jobs, save schema, scene startup")
    instance.queue_free()
    quit(0)
