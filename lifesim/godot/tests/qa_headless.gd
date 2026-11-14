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
    if CitySave.spend(state, 18) != true:
        fail("coffee payment rejected")
        return
    if "coffee" in state["owned_items"]:
        fail("consumable saved as permanent furniture")
        return
    if CitySave.spend(state, 1000000):
        fail("overspending accepted")
        return
    if state["balance"] != 732:
        fail("wrong payout balance")
        return
    var sanitized: Dictionary = CitySave.sanitize(state)
    if sanitized.is_empty() or sanitized["balance"] != 732:
        fail("sanitizer damaged valid save")
        return
    if not CitySave.sanitize({"version":1,"balance":-100,"owned_items":[],"position":[0,0,0],"completed_job_ids":[]}).is_empty():
        fail("negative balance save accepted")
        return
    # A save with an interior location must round-trip, not strand the player outdoors.
    state["at_home"] = true
    var checked_home: Dictionary = CitySave.sanitize(state)
    if checked_home.is_empty() or not checked_home["at_home"]:
        fail("apartment flag not preserved")
        return
    # Test actual JSON read/write and a corrupted main save falling back to backup.
    var qa_file: String = "user://qa_temp_%d.json" % Time.get_ticks_usec()
    var qa_backup: String = qa_file + ".bak"
    if not CitySave.write_save(state, qa_file, qa_backup):
        fail("unable to persist isolated QA save")
        return
    # The second valid save creates a reliable backup for recovery.
    if not CitySave.write_save(state, qa_file, qa_backup):
        fail("unable to create QA backup")
        return
    var loaded: Dictionary = CitySave.read_save(qa_file, qa_backup)
    if loaded["balance"] != 732 or not loaded["at_home"]:
        fail("reloaded save differs from written save")
        return
    var main_file: FileAccess = FileAccess.open(qa_file, FileAccess.WRITE)
    if main_file == null:
        fail("cannot simulate corrupt QA save")
        return
    main_file.store_string("{not valid json}")
    main_file.close()
    loaded = CitySave.read_save(qa_file, qa_backup)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_backup))
    if loaded.get("balance", -1) != 732 or not bool(loaded.get("at_home", false)):
        fail("corrupt QA save did not recover from backup")
        return
    ProjectSettings.set_setting("application/config/qa_mode", true)
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
    var visual: Node = avatar.get_node_or_null("AvatarVisual")
    if visual == null or visual.get_node_or_null("LeftHip/LeftKnee") == null or visual.get_node_or_null("RightHip/RightKnee") == null:
        fail("V0.4 articulated character nodes missing")
        return
    var district: Node = instance.get_node_or_null("AokawaDistrict")
    if district.get_node_or_null("AmbientResidents") == null:
        fail("V0.4 residents missing")
        return
    print("QA PASS: clock, spend, purchase, idempotent jobs, save, corrupt fallback, scene startup, articulated model and residents")
    instance.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)