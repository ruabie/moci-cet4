extends SceneTree

# V0.40: real production CityPlayer and original north shop, original camera.
# W and S use physical keyboard event dispatch. Only CAMERA_YAW is put
# into two explicit diagnostic orientations to stress a known real wall.
# The test never teleports the player after the one opt-in initial QA spawn.
const START_X: float = -13.75
const WALL_YAW: float = -PI * .5
const OPEN_YAW: float = PI * .5

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason:String)->void:
    _key(KEY_W,false)
    _key(KEY_S,false)
    printerr("V40 REAL PLAYER CAMERA OCCLUSION FAIL: "+reason)
    quit(1)

func _key(key:Key,pressed:bool)->void:
    var event:=InputEventKey.new()
    event.physical_keycode=key
    event.pressed=pressed
    Input.parse_input_event(event)

func _arr(v:Vector3)->Array:
    return [snappedf(v.x,.0001),snappedf(v.y,.0001),snappedf(v.z,.0001)]

func _camera_frame(player:CityPlayer, label:String)->bool:
    if player.camera==null or not player.camera.current:
        return false
    for i in range(5):
        await process_frame
    RenderingServer.force_draw(false)
    var image:Image=root.get_viewport().get_texture().get_image()
    return image != null and image.get_width() >= 720 \
        and image.get_height()>=400 \
        and image.save_png(ProjectSettings.globalize_path(
            "res://tests/v40_"+label+".png"))==OK

func _wanted(player:CityPlayer)->Vector3:
    var pivot:Vector3=player.global_position+Vector3.UP*1.56
    return pivot+Vector3(
        sin(player.camera_yaw)*player.camera_distance*cos(player.camera_pitch),
        player.camera_distance*(0.12-sin(player.camera_pitch)),
        cos(player.camera_yaw)*player.camera_distance*cos(player.camera_pitch))

func _wall_query(player:CityPlayer)->Dictionary:
    var pivot:Vector3=player.global_position+Vector3.UP*1.56
    var query:=PhysicsRayQueryParameters3D.create(
        pivot,_wanted(player),1,[player.get_rid()])
    return player.get_world_3d().direct_space_state.intersect_ray(query)

func _camera_overlap(player:CityPlayer)->int:
    var sphere:=SphereShape3D.new()
    sphere.radius=player.camera_occlusion_radius*.90
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=sphere
    query.transform=Transform3D(Basis(),player.camera.global_position)
    query.collision_mask=1
    query.exclude=[player.get_rid()]
    return player.get_world_3d().direct_space_state.intersect_shape(query,8).size()

func _count_hidden_local_avatar_meshes(player:CityPlayer)->int:
    var hidden:int=0
    for mesh_instance in player.avatar_render_meshes:
        if not is_instance_valid(mesh_instance):
            return -1
        if not mesh_instance.visible:
            hidden+=1
    return hidden


func _snapshot(player:CityPlayer,section:String)->Dictionary:
    var pivot:Vector3=player.global_position+Vector3.UP*1.56
    var desired:Vector3=_wanted(player)
    return {
        "stage":section,"player":_arr(player.global_position),
        "actual_camera":_arr(player.camera.global_position),
        "pivot":_arr(pivot),"unobstructed_wanted":_arr(desired),
        "camera_distance_actual_m":pivot.distance_to(player.camera.global_position),
        "camera_distance_requested_m":pivot.distance_to(desired),
        "camera_collision_activations":player.camera_collision_activations,
        "camera_overlap_objects":_camera_overlap(player),
        "yaw":player.camera_yaw,
        "avatar_on_real_ground":player.is_on_floor(),
        "avatar_camera_fade":player.avatar_camera_fade,
        "avatar_mesh_hidden_count":_count_hidden_local_avatar_meshes(player),
        "avatar_render_mesh_count":player.avatar_render_meshes.size()
    }

func _run()->void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    ProjectSettings.set_setting("application/config/v33_streetscape_preview",false)
    ProjectSettings.set_setting("application/config/v35_architecture_preview",true)
    ProjectSettings.set_setting("application/config/v36_pinned_facade_preview",true)
    ProjectSettings.set_setting("application/config/v37_walkable_shop_preview",true)
    ProjectSettings.set_setting("application/config/v38_real_player_route_qa",true)
    var packed:PackedScene=load("res://scenes/main.tscn") as PackedScene
    if packed==null:
        _fail("original real Godot main scene not available");return
    var scene:Node3D=packed.instantiate() as Node3D
    root.add_child(scene)
    for t in range(20):
        await physics_frame
    var player:CityPlayer=scene.get_node_or_null("Player") as CityPlayer
    var district:PlannedDistrictV32=scene.get_node_or_null(
        "AokawaDistrict/V32NorthWalkableDistrictPreview") as PlannedDistrictV32
    if player==null or district==null or player.camera==null:
        _fail("original CityPlayer+original camera+real north district required");return
    if player.avatar_render_meshes.is_empty():
        _fail("no original imported avatar meshes available for short-camera fade");return
    if not player.animation_verified or player.camera_sweep_query==null:
        _fail("original skinned avatar and real sphere-sweep camera required");return
    if int(district.statistics.get("buildings",0))!=11:
        _fail("original 11 lots missing");return
    if int(district.statistics.get("v37_traversable_shop_pilots",0))!=1:
        _fail("real V37 collision-aware shop unavailable");return
    if absf(player.global_position.x-START_X)>.05:
        _fail("original QA starting point wrong");return
    var result:Dictionary={
        "version":"V0.40","actual_game_scene":true,
        "real_original_cityplayer":true,
        "camera_type":"CityPlayer.ThirdPersonCamera",
        "camera_collision_type":"3D sphere swept on collision_mask 1",
        "shop_collision_unmodified":true,
        "camera_orientations_test_setup_only":true,
        "player_teleport_after_qa_spawn":false,
        "font_or_art_gate_approved":false,
        "real_human_mouse_verified":false,
        "windows_or_browser_performance_verified":false,
        "screenshots":[],"stages":[]
    }
    if not player.is_on_floor():
        _fail("actual player not grounded outside shop");return
    player.camera_yaw=OPEN_YAW
    player.camera_distance=4.6
    for i in range(35):
        await physics_frame
    result["stages"].append(_snapshot(player,"public_street_unobstructed"))
    if not await _camera_frame(player,"street"):
        _fail("original street third-person camera frame missing");return
    result["screenshots"].append("v40_street.png")

    # Move original skinned CityPlayer by physical W input to real interior.
    _key(KEY_W,true)
    var arrived:bool=false
    var ticks:int=0
    for i in range(180):
        await physics_frame
        ticks+=1
        if player.global_position.x < -22.7:
            arrived=true
            break
    _key(KEY_W,false)
    if not arrived:
        _fail("real W key cannot bring original player inside original shop");return
    for i in range(28):
        await physics_frame
    if not player.is_on_floor():
        _fail("real player is not grounded in interior");return
    result["real_W_forward_ticks"]=ticks
    result["stages"].append(_snapshot(player,"inside_open_entrance_behind_camera"))
    if not await _camera_frame(player,"inside_open"):
        _fail("real inside baseline third-person camera PNG missing");return
    result["screenshots"].append("v40_inside_open.png")

    # Stress deliberate real *rear shop wall* obstruction. Original
    # unmodified CityPlayer.camera_yaw is a camera control field; here it
    # is oriented by the QA harness, not claimed as real mouse input.
    player.camera_yaw=WALL_YAW
    player.camera_distance=4.6
    await physics_frame
    var wall_hit:Dictionary=_wall_query(player)
    if wall_hit.is_empty():
        _fail("negative control: no real collidable wall across camera aim");return
    var wall_body:CollisionObject3D=wall_hit["collider"] as CollisionObject3D
    if wall_body==null:
        _fail("wall result wasn't an actual collision object");return
    var body_name:String=str(wall_body.name)
    if body_name!="Solid_rear_retail_wall" and body_name!="Solid_west_ground_solid":
        _fail("expected original solid shop rear wall but hit "+body_name);return
    var pivot:Vector3=player.global_position+Vector3.UP*1.56
    var distance_to_wall:float=pivot.distance_to(wall_hit["position"] as Vector3)
    var requested:float=pivot.distance_to(_wanted(player))
    if requested < distance_to_wall+1.5:
        _fail("camera requested position did not reach behind a physical wall");return
    var activated_before:int=player.camera_collision_activations
    var peak_overlap:int=0
    for t in range(28):
        await physics_frame
        peak_overlap=maxi(peak_overlap,_camera_overlap(player))
    var now:Dictionary=_snapshot(player,"inside_camera_behind_rear_wall")
    result["stages"].append(now)
    result["rear_obstacle_name"]=body_name
    result["rear_wall_ray_hit"]=_arr(wall_hit["position"] as Vector3)
    result["wall_distance_m"]=distance_to_wall
    result["open_camera_requested_radius_m"]=requested
    result["forced_occlusion_count"]=player.camera_collision_activations-activated_before
    result["peak_camera_shape_overlaps"]=peak_overlap
    if result["forced_occlusion_count"]<4:
        _fail("actual original camera sphere sweep never retracted despite solid wall");return
    if float(now["camera_distance_actual_m"])>distance_to_wall-.04:
        _fail("actual third person camera remained across collidable shop wall");return
    if int(now["camera_overlap_objects"])!=0 or peak_overlap>0:
        _fail("camera near plane sphere crossed a solid wall during occlusion");return
    if float(now["avatar_camera_fade"])<.97 or int(now["avatar_mesh_hidden_count"])!=player.avatar_render_meshes.size():
        _fail("original avatar hair/face is still rendered opaque close behind real wall");return
    if not await _camera_frame(player,"inside_occluded"):
        _fail("actual occluded original third person camera image missing");return
    result["screenshots"].append("v40_inside_occluded.png")

    # Real camera angle reopens onto street. Camera must recover behind
    # player after the obstruction clears, not stick to the wall.
    player.camera_yaw=OPEN_YAW
    for t in range(85):
        await physics_frame
    var recovered:Dictionary=_snapshot(player,"inside_camera_recovered")
    result["stages"].append(recovered)
    if float(recovered["camera_distance_actual_m"]) < distance_to_wall+1.20:
        _fail("occlusion-cleared camera stuck against a wall");return
    if int(recovered["camera_overlap_objects"])>0:
        _fail("camera penetrates solid building after obstruction cleared");return
    if float(recovered["avatar_camera_fade"])>.02 or int(recovered["avatar_mesh_hidden_count"])!=0:
        _fail("original third-person avatar remains faded after exiting tight wall camera");return
    if not await _camera_frame(player,"inside_recovered"):
        _fail("original recovered third-person camera image missing");return
    result["screenshots"].append("v40_inside_recovered.png")

    # Physical S exit, same as V38. Not teleported from room to street.
    _key(KEY_S,true)
    var exited:bool=false
    for t in range(180):
        await physics_frame
        if player.global_position.x>START_X+.15:
            exited=true
            break
    _key(KEY_S,false)
    if not exited:
        _fail("actual CityPlayer failed to physically walk out of shop");return
    for i in range(24):
        await physics_frame
    if not player.is_on_floor():
        _fail("real CityPlayer not grounded on exit");return
    result["stages"].append(_snapshot(player,"street_after_physical_S_exit"))
    if not await _camera_frame(player,"street_exit"):
        _fail("actual return street third person camera image missing");return
    result["screenshots"].append("v40_street_exit.png")
    result["avatar_render_mesh_count"]=player.avatar_render_meshes.size()
    result["compatibility_material_alpha_slot_count"]=player.avatar_fade_materials.size()
    result["camera_near_avatar_fade_proof"]=true
    result["real_solid_collision_preserved"]=true
    result["ok"]=true
    var f:FileAccess=FileAccess.open(ProjectSettings.globalize_path(
        "res://tests/v40_real_camera_occlusion_metrics.json"),FileAccess.WRITE)
    if f==null:
        _fail("Godot couldn't save real camera metrics");return
    f.store_string(JSON.stringify(result,"  ")+"\n")
    f.close()
    print("V40 REAL CITYPLAYER CAMERA REAR-WALL OCCLUSION PASS: "+JSON.stringify({
        "real_wall":body_name,"actual_occlusion_activations":result["forced_occlusion_count"],
        "ray_hit_m":distance_to_wall,
        "retracted_camera_m":now["camera_distance_actual_m"],
        "open_camera_m":recovered["camera_distance_actual_m"],
        "max_overlaps":peak_overlap,"original_player_cam_frames":result["screenshots"].size()}))
    quit(0)
