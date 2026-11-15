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
    # V0.6 daily life contracts: old saves, one-time rewards, real world movement destinations.
    var old_save: Dictionary = CitySave.initial()
    for key in ["day_key", "daily_done", "npc_talked_today", "photo_spots", "friends", "journal", "skills", "energy", "mood", "jobs_today", "deliveries", "delivery_active"]:
        old_save.erase(key)
    var old_read: Dictionary = CitySave.sanitize(old_save)
    if old_read.is_empty() or int(old_read["balance"]) != 800:
        fail("v0.5 save cannot migrate to v0.6")
        return
    var life: Dictionary = CitySave.initial()
    var day: String = "2026-11-15"
    LifeContent.prepare_day(life, day)
    if not LifeContent.talk(life, "小遥", day) or LifeContent.talk(life, "小遥", day):
        fail("npc repeated social reward")
        return
    if int(life["balance"]) != 830 or int(life["friends"].get("小遥", 0)) != 1:
        fail("social payout/relationship incorrect")
        return
    if not LifeContent.photo(life, "river", day) or LifeContent.photo(life, "river", day) or not LifeContent.photo(life, "crossing", day):
        fail("photography duplicate/multi-spot contract failed")
        return
    if int(life["balance"]) != 855 or not LifeContent.completed(life, "photos"):
        fail("photography daily reward incorrect")
        return
    if not LifeContent.begin_delivery(life, day) or LifeContent.begin_delivery(life, day):
        fail("delivery can be picked up twice")
        return
    if not LifeContent.finish_delivery(life, day) or LifeContent.finish_delivery(life, day):
        fail("delivery paid twice")
        return
    if int(life["balance"]) != 945:
        fail("delivery wage incorrect")
        return
    var wage: int = LifeContent.job_finish(life, "v06-test-job", "便利店", 3, day)
    if wage != 80 or LifeContent.job_finish(life, "v06-test-job", "便利店", 3, day) != 0:
        fail("real job payout / idempotence incorrect")
        return
    if int(life["balance"]) != 1050 or int(life["jobs_completed"]) != 1:
        fail("daily work bonus wrong")
        return
    if not CitySave.sanitize(life).has("journal"):
        fail("new life fields lost in save")
        return
    if not LifeContent.prepare_day(life, "2026-11-16") or LifeContent.completed(life, "delivery") or not LifeContent.begin_delivery(life, "2026-11-16"):
        fail("daily reset regression")
        return
    if LifeContent.prepare_day(life, "2026-11-14"):
        fail("backdated device clock triggered repeated daily rewards")
        return
    var home: Dictionary = CitySave.initial()
    if not CitySave.purchase(home, "soft_rug", 180) or not CitySave.purchase(home, "green_plant", 240):
        fail("furniture purchase failed")
        return
    if CitySave.purchase(home, "soft_rug", 180) or int(home["balance"]) != 380:
        fail("furniture repeat purchase / balance regression")
        return
    home["mood"] = 30
    LifeContent.rest(home, true)
    if int(home["mood"]) != 44:
        fail("furniture comfort had no effect on apartment rest")
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
    var avatar: CityPlayer = instance.get_node_or_null("Player") as CityPlayer
    if avatar == null:
        fail("player not created")
        return
    if instance.get_node_or_null("AokawaDistrict") == null:
        fail("3D district missing")
        return
    var visual: Node = avatar.get_node_or_null("AvatarVisual")
    if visual == null or not avatar.animation_verified:
        fail("V0.5 authored skinned avatar not initialized")
        return
    if avatar.rig == null or avatar.rig.get_bone_count() < 15:
        fail("V0.5 Skeleton3D missing or unrigged")
        return
    for required_name in ["LeftThigh", "RightThigh", "LeftShin", "RightShin"]:
        if avatar.rig.find_bone(required_name) < 0:
            fail("V0.5 missing locomotion bone: " + required_name)
            return
    # Exercise actual physics movement and animated bone pose rather than
    # passing only because a Skeleton3D node exists.
    var initial_pos: Vector3 = avatar.global_position
    Input.action_press("move_forward")
    for step in range(12):
        await physics_frame
    Input.action_release("move_forward")
    var travelled: float = avatar.global_position.distance_to(initial_pos)
    if travelled < 0.10:
        fail("V0.5.1 input did not move player, displacement: %f" % travelled)
        return
    var thigh_idx: int = avatar.rig.find_bone("LeftThigh")
    var pose: Quaternion = avatar.rig.get_bone_pose_rotation(thigh_idx)
    if absf(pose.get_angle()) < 0.01:
        fail("V0.5.1 locomotion didn't update skinned left thigh")
        return
    var district: Node = instance.get_node_or_null("AokawaDistrict")
    if district.get_node_or_null("Authored_AOI_MART__·__24H/V08TexturedEnvelopeAndInterior") == null:
        fail("V0.8 integrated mart model missing")
        return
    if district.get_node_or_null("V10DistantUrbanBackdrop") == null:
        fail("V0.10 differentiated skyline is not loaded")
        return
    var authored_trees: int = 0
    for detail in district.get_children():
        if str(detail.name).begins_with("V10StreetscapeTree_"):
            authored_trees += 1
    if authored_trees < 12:
        fail("V0.10 vegetation count too low: %d" % authored_trees)
        return
    if district.get_node_or_null("Authored_KAWA_COFFEE/V09CuratedCafeAndInterior") == null:
        fail("V0.9 curated cafe mesh missing from live 3D world")
        return
    for address in ["Authored_SLOW_LIVING", "Authored_青川公寓"]:
        if district.get_node_or_null(address + "/V08TexturedEnvelopeAndInterior") == null:
            fail("V0.8 integrated facade missing: " + address)
            return
    if district.get_node_or_null("AmbientResidents") == null:
        fail("V0.4 residents missing")
        return
    if district.get_node_or_null("LifeQuestBoard") == null or district.get_node_or_null("RiversideParcelLocker") == null:
        fail("V0.6 task board and delivery destination missing")
        return
    if instance.get_node_or_null("MartInterior") == null or instance.get_node_or_null("CafeInterior") == null:
        fail("V0.6 store interiors missing")
        return
    var cafe_v11: CuratedInteriorsV11 = instance.get_node_or_null("CafeInterior") as CuratedInteriorsV11
    var mart_v11: CuratedInteriorsV11 = instance.get_node_or_null("MartInterior") as CuratedInteriorsV11
    var home_v11: CuratedInteriorsV11 = instance.get_node_or_null("ApartmentInterior") as CuratedInteriorsV11
    if cafe_v11 == null or mart_v11 == null or home_v11 == null:
        fail("V0.11 furnished interiors not instantiated")
        return
    if cafe_v11.placed_assets < 20 or mart_v11.placed_assets < 20 or home_v11.placed_assets < 10:
        fail("V0.11 imported furniture missing")
        return
    if cafe_v11.collidable_assets < 5 or mart_v11.collidable_assets < 5:
        fail("V0.11 furniture collision missing")
        return
    var block: LicensedBlockV11 = district.get_node_or_null("V11LicensedNeighborhood") as LicensedBlockV11
    if block == null or block.building_count < 6 or block.model_count < 12:
        fail("V0.11 licensed district GLBs not loaded")
        return
    if district.npc_rigs.size() != district.npc_figures.size():
        fail("V0.5.1 NPC bone rigs do not match resident count")
        return
    for npc_rig in district.npc_rigs:
        if npc_rig == null or npc_rig.get_bone_count() < 15:
            fail("V0.5.1 unrigged resident")
            return
    print("QA PASS: V0.8 integrated facade and clock, old-save migration, daily quest idempotence, real-work payout, delivery, residents, photography, interiors, rigged characters, save and scene")
    instance.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)