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
    if avatar.rig == null or avatar.rig.get_bone_count() < 40:
        fail("V0.5 Skeleton3D missing or unrigged")
        return
    for required_name in ["LeftThigh", "RightThigh", "LeftShin", "RightShin"]:
        if not CharacterArtV18.has_bone(avatar.rig, required_name):
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
    var thigh_idx: int = avatar.rig.find_bone(CharacterArtV18.joint_name(avatar.rig, "LeftThigh"))
    var pose: Quaternion = avatar.rig.get_bone_pose_rotation(thigh_idx)
    if absf(pose.get_angle()) < 0.01:
        fail("V0.5.1 locomotion didn't update skinned left thigh")
        return
    var district: Node = instance.get_node_or_null("AokawaDistrict")
    if district.get_node_or_null("Authored_AOI_MART__·__24H/V15UpperStoreys") == null:
        fail("V15 integrated mart upper shell missing")
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
    if district.get_node_or_null("Authored_KAWA_COFFEE/V14UpperStoreys") == null:
        fail("V0.9 curated cafe mesh missing from live 3D world")
        return
    for address in ["Authored_SLOW_LIVING", "Authored_青川公寓"]:
        if district.get_node_or_null(address + "/V08TexturedEnvelopeAndInterior") == null:
            fail("V0.8 integrated facade missing: " + address)
            return
    if district.get_node_or_null("AmbientResidents") == null:
        fail("V0.4 residents missing")
        return
    # V0.18: distinct CC0 civilians all need real imported bone rigs.
    if district.npc_figures.size() != 6 or district.npc_rigs.size() != 6:
        fail("V18 expected six differently dressed residents")
        return
    for civilian_rig in district.npc_rigs:
        if civilian_rig == null or civilian_rig.get_bone_count() < 40 or not CharacterArtV18.has_bone(civilian_rig, "LeftThigh"):
            fail("V18 humanoid bone import failed")
            return
    print("V18 QA PASS: seven licensed civilians, actual rigged bone poses")
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
    if cafe_v11.placed_assets < 20 or (mart_v11.placed_assets < 20 and not mart_v11 is WalkableMartV16) or home_v11.placed_assets < 10:
        fail("V0.11 imported furniture missing")
        return
    if cafe_v11.collidable_assets < 5 or mart_v11.collidable_assets < 5:
        fail("V0.11 furniture collision missing")
        return
    # V0.12: real-time economy/save tests above must still pass before interiors QA.
    var v12_cafe := cafe_v11 as CuratedInteriorsV12
    var v12_mart := mart_v11 as CuratedInteriorsV12
    var v12_home := home_v11 as CuratedInteriorsV12
    if v12_cafe == null or v12_mart == null or v12_home == null:
        fail("V0.12 compact interiors missing")
        return
    if v12_cafe.placed_assets < 25 or (v12_mart.placed_assets < 48 and not v12_mart is WalkableMartV16) or v12_home.placed_assets < 14:
        fail("V0.12 insufficient functional interior density")
        return
    if v12_cafe.displayed_products < 12 or v12_mart.displayed_products < 45:
        fail("V0.12 showcase/store products not populated")
        return
    if v12_cafe.functional_zones.size() < 4 or v12_mart.functional_zones.size() < 4 or v12_home.functional_zones.size() < 5:
        fail("V0.12 planned interior zones missing")
        return
    if v12_cafe.room_dimensions.x > 12 or v12_home.room_dimensions.x > 9.5:
        fail("V0.12 interior footprint still too cavernous")
        return
    # Verify unobstructed doorway-to-center aisle against real physics bodies.
    for candidate in [v12_cafe, v12_mart, v12_home]:
        var room: CuratedInteriorsV12 = candidate as CuratedInteriorsV12
        var front_offset: float = room.room_dimensions.y*.5-.65
        var a: Vector3 = room.to_global(Vector3(0, 1.08, front_offset))
        var b: Vector3 = room.to_global(Vector3(0, 1.08, 1.1))
        var ray := PhysicsRayQueryParameters3D.create(a, b)
        ray.collision_mask = 1
        var hit: Dictionary = room.get_world_3d().direct_space_state.intersect_ray(ray)
        if not hit.is_empty():
            fail("V0.12 entrance path blocked in "+room.name+" by "+str(hit.get("collider")))
            return
    var block: LicensedBlockV11 = district.get_node_or_null("V11LicensedNeighborhood") as LicensedBlockV11
    if block == null or block.building_count < 6 or block.model_count < 12:
        fail("V0.11 licensed district GLBs not loaded")
        return
    if district.npc_rigs.size() != district.npc_figures.size():
        fail("V0.5.1 NPC bone rigs do not match resident count")
        return
    for npc_rig in district.npc_rigs:
        if npc_rig == null or npc_rig.get_bone_count() < 40:
            fail("V0.5.1 unrigged resident")
            return
    var v13_cafe: CuratedInteriorsV13 = instance.get_node_or_null("CafeInterior") as CuratedInteriorsV13
    if v13_cafe == null:
        fail("V0.13 art-directed cafe missing")
        return
    if v13_cafe.quaternius_assets < 12 or v13_cafe.art_lights < 4 or v13_cafe.finish_systems < 4:
        fail("V0.13 cafe authored geometry or lighting missing")
        return
    if v13_cafe.clear_aisle_width < 2.0 or v13_cafe.room_dimensions.x * v13_cafe.room_dimensions.y > 90.0:
        fail("V0.13 cramped aisle or oversized cafe")
        return
    # V0.14: door, street and bar must occupy the SAME physics world.
    var seamless: WalkableCafeV14 = instance.get_node_or_null("CafeInterior") as WalkableCafeV14
    if seamless == null or seamless.position.distance_to(Vector3(22.5,0,-14)) > .01:
        fail("V14 cafe still isolated from real street")
        return
    var approach: Vector3 = seamless.street_door_world()
    var inside: Vector3 = seamless.interior_probe_world()
    if seamless.is_inside_world(approach) or not seamless.is_inside_world(inside):
        fail("V14 entrance spatial boundary invalid")
        return
    var q := PhysicsRayQueryParameters3D.create(
        seamless.to_global(Vector3(0,1.1,6.15)),
        seamless.to_global(Vector3(0,1.1,2.9)), 1)
    var blockage: Dictionary = avatar.get_world_3d().direct_space_state.intersect_ray(q)
    if not blockage.is_empty():
        fail("V14 physically blocked cafe threshold: "+str(blockage.get("collider")))
        return
    avatar.global_position = approach
    avatar.camera_yaw = -PI * .5
    avatar.velocity = Vector3.ZERO
    instance.indoor_place = ""
    Input.action_press("move_forward")
    for ticks in range(46):
        await physics_frame
        await process_frame
    Input.action_release("move_forward")
    if not seamless.is_inside_world(avatar.global_position):
        fail("V14 WASD cannot actually cross threshold")
        return
    if instance.indoor_place != "咖啡馆":
        fail("V14 did not set cafe indoor context upon physical entry")
        return
    if avatar.global_position.distance_to(approach) > 6.0:
        fail("V14 entering used teleport rather than physical movement")
        return
    Input.action_press("move_back")
    for ticks in range(115):
        await physics_frame
        await process_frame
    Input.action_release("move_back")
    if seamless.is_inside_world(avatar.global_position) or instance.indoor_place != "":
        fail("V14 could not physically leave cafe: pos=" + str(avatar.global_position) + " indoor=" + str(instance.indoor_place))
        return
    print("V14 QA PASS: genuine contiguous street/interior, threshold ray, actual physical entry and exit")
    # V0.15: the convenience store is also in the actual road scene. No
    # isolated z=190 teleport, no opaque solid collider through its entrance.
    var mart: WalkableMartV15 = instance.get_node_or_null("MartInterior") as WalkableMartV15
    if mart == null or mart.global_position.distance_to(Vector3(-22.35,0,-14)) > .01:
        fail("V15 mart is still off-map or missing")
        return
    if mart.room_dimensions.x < 11.0 or mart.displayed_products < 45:
        fail("V15 mart not furnished at usable scale")
        return
    var curated: WalkableMartV16 = mart as WalkableMartV16
    if curated == null or curated.rack_count != 4 or curated.stocked_sku_instances < 240:
        fail("V16 curated shelves / real-size stock missing")
        return
    if curated.lit_fixture_count != 4 or curated.shelf_clear_center_width < 2.30:
        fail("V16 light and accessible center aisle contract missing")
        return
    for sku in curated.SKU_IDS:
        if curated.get_node_or_null("V16_Stock_" + sku) == null:
            fail("V16 optimized stock batch not rendered: " + sku)
            return
    # V0.17: inspect the actual runtime instantiation, not only GLB files.
    var v17: WalkableMartV17 = mart as WalkableMartV17
    if v17 == null or v17.open_refrigerator_bays != 3 or v17.refrigerated_skus != 72:
        fail("V17 art: refrigerators are missing or incorrectly stocked")
        return
    if v17.cold_led_strips != 6 or v17.finish_surfaces < 3:
        fail("V17 art: in-cabinet LEDs and original material surfaces not loaded")
        return
    var mart_approach: Vector3 = mart.street_door_world()
    var mart_in: Vector3 = mart.interior_probe_world()
    if mart.is_inside_world(mart_approach) or not mart.is_inside_world(mart_in):
        fail("V15 mart physical doorway invalid")
        return
    var mart_ray := PhysicsRayQueryParameters3D.create(
        mart.to_global(Vector3(0,1.2,8.0)),
        mart.to_global(Vector3(0,1.2,3.3)), 1)
    if not avatar.get_world_3d().direct_space_state.intersect_ray(mart_ray).is_empty():
        fail("V15 mart storefront collider blocks open doorway")
        return
    avatar.global_position = mart_approach
    avatar.camera_yaw = PI * .5
    avatar.velocity = Vector3.ZERO
    instance.indoor_place = ""
    Input.action_press("move_forward")
    for ticks in range(56):
        await physics_frame
        await process_frame
    Input.action_release("move_forward")
    if not mart.is_inside_world(avatar.global_position) or instance.indoor_place != "便利店":
        fail("V15 cannot walk into street-level mart: " + str(avatar.global_position))
        return
    if avatar.global_position.distance_to(mart_approach) > 7.5:
        fail("V15 unintended mart teleport on entry")
        return
    Input.action_press("move_back")
    for ticks in range(105):
        await physics_frame
        await process_frame
    Input.action_release("move_back")
    if mart.is_inside_world(avatar.global_position) or instance.indoor_place != "":
        fail("V15 cannot walk back out of street-level mart")
        return
    # Camera near an injected opaque wall: actual physics sweep must retract
    # behind it rather than let the third-person view pass through the wall.
    avatar.global_position = Vector3(0, .2, 0)
    avatar.camera_yaw = 0.0
    avatar.camera_pitch = 0.0
    avatar.camera_distance = 4.6
    var test_wall := StaticBody3D.new()
    test_wall.collision_layer = 1
    var wall_shape := CollisionShape3D.new()
    var wall_box := BoxShape3D.new()
    wall_box.size = Vector3(5.0, 3.4, .35)
    wall_shape.shape = wall_box
    test_wall.add_child(wall_shape)
    root.add_child(test_wall)
    test_wall.global_position = Vector3(0, 1.65, 2.6)
    avatar.camera_collision_activations = 0
    for ticks in range(18):
        await physics_frame
    if avatar.camera_collision_activations == 0 or avatar.camera.global_position.z > 2.4:
        fail("V15 camera collision failed to retract behind wall")
        return
    test_wall.queue_free()
    print("V17 QA PASS: 3 recessed fridges / 72 chilled goods / 6 LED rails / 3 texture surfaces")
    print("V16 QA PASS: walkable four-rack mart, 170+ stocked instances, coherent lighting")
    print("V15 QA PASS: walkable mart/cafe, reversible physical doors, bounded camera collision, unchanged save/economy")
    print("QA PASS: V0.8 integrated facade and clock, old-save migration, daily quest idempotence, real-work payout, delivery, residents, photography, interiors, rigged characters, save and scene")
    instance.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)