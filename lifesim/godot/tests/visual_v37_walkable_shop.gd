extends SceneTree

# Exact original Godot 4.7.2 main scene, same cameras and fixed parcel.
# Proves V36's full solid collider is removed ONLY in QA V37,
# and a real CharacterBody3D physics test can walk along the original
# street approach and through the open door. This is a proxy, NOT the
# production CityPlayer or a verified commerce/POI interaction.
const CAMERAS: Array = [
    ["street",Vector3(-5.0,5.7,108.5),Vector3(-27.0,4.1,116.0),54.0],
    ["door",Vector3(-15.8,1.85,116.0),Vector3(-23.0,1.65,116.0),64.0]
]
var _captures: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    printerr("V37 WALKABLE SHOP REAL QA FAIL: "+reason)
    quit(1)

func _ray(scene: Node3D, start: Vector3, finish: Vector3) -> Dictionary:
    var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        start,finish,1)
    return scene.get_world_3d().direct_space_state.intersect_ray(q)

func _render(camera: Camera3D, shot: Array, filename: String) -> bool:
    camera.global_position = shot[1] as Vector3
    camera.look_at(shot[2] as Vector3, Vector3.UP)
    camera.fov = float(shot[3])
    for t in range(9):
        await process_frame
    RenderingServer.force_draw(false)
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width()<720 or img.get_height()<400:
        return false
    return img.save_png(
        ProjectSettings.globalize_path("res://tests/"+filename+".png")) == OK

func _try_walk(scene: Node3D) -> Dictionary:
    var body := CharacterBody3D.new()
    body.name="V37QA_Shop_CharacterBodyProxy"
    body.collision_layer=2
    body.collision_mask=1
    var collider:=CollisionShape3D.new()
    var capsule:=CapsuleShape3D.new()
    capsule.radius=.28
    capsule.height=1.65
    collider.shape=capsule
    body.add_child(collider)
    body.position=Vector3(-14.0,1.17,116)
    scene.add_child(body)
    await physics_frame
    var initial: Vector3=body.global_position
    var collisions:int=0
    # Exactly 50 fixed-motion samples toward the interior (9.0m).
    # Collisions are NOT silently ignored. No teleportation across a wall.
    for t in range(50):
        await physics_frame
        var hit: KinematicCollision3D=body.move_and_collide(Vector3(-.18,0,0))
        if hit!=null:
            collisions+=1
            break
    var reached: Vector3=body.global_position
    var report: Dictionary={
        "proxy_type":"CharacterBody3D using real Godot physics",
        "start":[initial.x,initial.y,initial.z],
        "end":[reached.x,reached.y,reached.z],
        "distance_metres":initial.distance_to(reached),
        "collision_events":collisions,
        "steps_requested":50,
        "steps_without_blocking":50 if collisions==0 else 0,
        "production_city_player_input_verified":false
    }
    body.queue_free()
    await process_frame
    return report

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    ProjectSettings.set_setting("application/config/v35_architecture_preview",true)
    ProjectSettings.set_setting("application/config/v33_streetscape_preview",false)
    ProjectSettings.set_setting("application/config/v36_pinned_facade_preview",true)
    var result:Dictionary={
        "version":"V0.37",
        "replaces":"one QA-only 20m x 22m north housing parcel",
        "continuous_street_entry":false,
        "commerce_job_or_purchase_implemented":false,
        "same_camera":true,"screenshots":[],
        "production_city_player_input_verified":false,
        "windows_gpu_verified":false,"chrome_webgl_verified":false,
        "professional_art_approved":false
    }
    for enabled in [false,true]:
        ProjectSettings.set_setting("application/config/v37_walkable_shop_preview",enabled)
        var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
        if packed==null:
            _fail("missing actual main scene");return
        var scene:Node3D=packed.instantiate() as Node3D
        root.add_child(scene)
        await process_frame
        await physics_frame
        var north:PlannedDistrictV32=scene.get_node_or_null(
            "AokawaDistrict/V32NorthWalkableDistrictPreview") as PlannedDistrictV32
        if north==null or int(north.statistics.get("buildings",0))!=11:
            _fail("real connected 11-lot district missing");return
        var lot:Node3D=north.get_node_or_null("PlannedLot_west_homes_a") as Node3D
        if lot==null:
            _fail("original fixed residential parcel missing");return
        var clear_middle:Dictionary=_ray(scene,Vector3(-14,1.55,116),Vector3(-23,1.55,116))
        if not enabled:
            if clear_middle.is_empty():
                _fail("negative control does not detect V36 solid footprint");return
            result["v36_before_door_blocked"]=true
        else:
            if not clear_middle.is_empty():
                _fail("door still physically blocked: "+str(clear_middle.get("collider")));return
            var pilot:WalkableShopV37=lot.get_node_or_null("V37WalkableGroundRetail") as WalkableShopV37
            if pilot==null:
                _fail("V37 actual shop node missing");return
            var stats:Dictionary=pilot.statistics
            if int(north.statistics.get("v37_traversable_shop_pilots",0))!=1:
                _fail("more than one shop or QA flag not engaged");return
            if int(stats.get("verified_glb_instances",0))!=17:
                _fail("V36 source-model reuse count must be 17 upper+side modules");return
            if int(stats.get("missing_source",0))!=0 or int(stats.get("bad_bounds",0))!=0:
                _fail("missing or modified source geometry");return
            if float(stats.get("entrance_clear_width_m",0)) < 2.8:
                _fail("clear physical door aperture is too narrow");return
            # A door should allow entry in its centre and stop sideways
            # attempts into the actual glazed wall. Back wall must also
            # stop a body; it cannot be a fake open-ended empty room.
            if _ray(scene,Vector3(-14,1.55,118.5),Vector3(-23,1.55,118.5)).is_empty():
                _fail("closed storefront side panel has no real collision");return
            if _ray(scene,Vector3(-14,1.55,116),Vector3(-27,1.55,116)).is_empty():
                _fail("rear shop wall has no real collision");return
            # Test THREE grounded public route points at the actual north lot.
            for x in [-15.0,-18.6,-21.0]:
                var ground:Dictionary=_ray(scene,
                    Vector3(x,6,116),Vector3(x,-3,116))
                if ground.is_empty() or absf(float(
                    (ground.get("position",Vector3(0,99,0)) as Vector3).y))>.28:
                    _fail("door to public street route has no grounded walk surface "+str(x));return
            var body_stats:Dictionary=await _try_walk(scene)
            if int(body_stats["collision_events"])!=0 or float(body_stats["distance_metres"]) < 8.85:
                _fail("actual CharacterBody3D proxy cannot walk from public street into shop "+str(body_stats));return
            if float((body_stats["end"] as Array)[0]) > -22.7:
                _fail("character did not pass fully inside building");return
            result["door_clear_path"]=true
            result["side_wall_collision"]=true
            result["back_wall_collision"]=true
            result["public_ground_probes"]=3
            result["character_body_physics"]=body_stats
            result["shop_stats"]=stats
            result["original_planned_lots"]=11
        var hud:CanvasLayer=scene.get_node_or_null("HUD") as CanvasLayer
        if hud!=null:
            hud.visible=false
        var character:Node3D=scene.get_node_or_null("Player") as Node3D
        if character!=null:
            character.visible=false
        var cam:=Camera3D.new()
        cam.current=true
        scene.add_child(cam)
        for shot in CAMERAS:
            var filename:String="v37_"+("after_" if enabled else "before_")+str(shot[0])
            if not await _render(cam,shot,filename):
                _fail("actual Godot screenshot render failed "+filename);return
            result["screenshots"].append(filename+".png")
        if enabled:
            var interior:Array=["inside",Vector3(-23.05,1.73,115.6),
                Vector3(-17.6,1.85,116),70.0]
            if not await _render(cam,interior,"v37_inside_shop"):
                _fail("actual interior image failed");return
            result["screenshots"].append("v37_inside_shop.png")
        scene.queue_free()
        await process_frame
        await physics_frame
    result["ok"]=true
    result["continuous_street_entry"]=true
    var file:FileAccess=FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v37_walkable_shop_metrics.json"),
        FileAccess.WRITE)
    if file==null:
        _fail("metrics could not be stored");return
    file.store_string(JSON.stringify(result,"\t")+"\n")
    file.close()
    print("V37 REAL WALKABLE RETAIL PHYSICS PASS: "+JSON.stringify({
        "actual_source_modules":result["shop_stats"]["verified_glb_instances"],
        "ground_probes":result["public_ground_probes"],
        "walk_metres":result["character_body_physics"]["distance_metres"],
        "rendered_png":result["screenshots"].size()}))
    quit(0)
