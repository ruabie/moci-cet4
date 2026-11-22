extends SceneTree

# V0.38 QA: original production CityPlayer with actual action-map KEY W/A/D/S
# keyboard dispatch. No proxy CharacterBody, no teleport after initial QA spawn,
# no calls to move_and_collide() / move_and_slide() from this test.
# Five authentic frames captured FROM THE ORIGINAL PLAYER CAMERA, not a free camera.
const QA_START_X: float = -13.75
const QA_DOOR_X: float = -18.0
const QA_INSIDE_X: float = -22.70
const MAX_STEPS: int = 175

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    for code in [KEY_W,KEY_A,KEY_D,KEY_S]:
        _key(code,false)
    printerr("V38 REAL CITYPLAYER INPUT FAIL: " + message)
    quit(1)

func _key(key: Key, down: bool) -> void:
    var evt := InputEventKey.new()
    evt.physical_keycode = key
    evt.pressed = down
    evt.echo = false
    Input.parse_input_event(evt)

func _xyz(point: Vector3) -> Array:
    return [snappedf(point.x,0.0001),snappedf(point.y,0.0001),
        snappedf(point.z,0.0001)]

func _capture(player: CityPlayer, suffix: String) -> bool:
    if player.camera == null or not player.camera.current:
        return false
    for i in range(7):
        await process_frame
    RenderingServer.force_draw(false)
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width()<720 or img.get_height()<400:
        return false
    return img.save_png(ProjectSettings.globalize_path(
        "res://tests/v38_"+suffix+".png"))==OK

func _trace(player: CityPlayer, stage: String, samples: Array) -> void:
    var v: Vector3=player.global_position
    var cam: Vector3=player.camera.global_position
    var rad: float=(cam-v-Vector3.UP*1.56).length()
    samples.append({
        "stage":stage,"tick":player.physics_tick_counter,
        "position":_xyz(v),"velocity":_xyz(player.velocity),
        "grounded":player.is_on_floor(),
        "animation_weight":snappedf(player.anim_weight,0.0001),
        "stride_phase":snappedf(player.gait_stride_phase,0.0001),
        "ankle_reference_vs_idle_m":snappedf(player.foot_clearance_vs_idle(),0.0001),
        "camera_position":_xyz(cam),
        "camera_pivot_radius_m":snappedf(rad,0.0001),
        "camera_collision_activations":player.camera_collision_activations,
        "facing_y_rad":snappedf(player.character_visual.rotation.y,0.0001)
    })

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    ProjectSettings.set_setting("application/config/v33_streetscape_preview",false)
    ProjectSettings.set_setting("application/config/v35_architecture_preview",true)
    ProjectSettings.set_setting("application/config/v36_pinned_facade_preview",true)
    ProjectSettings.set_setting("application/config/v37_walkable_shop_preview",true)
    ProjectSettings.set_setting("application/config/v38_real_player_route_qa",true)
    var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("real original game scene missing");return
    var scene:Node3D=packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame
    var north:PlannedDistrictV32=scene.get_node_or_null(
        "AokawaDistrict/V32NorthWalkableDistrictPreview") as PlannedDistrictV32
    if north == null or int(north.statistics.get("v37_traversable_shop_pilots",0))!=1:
        _fail("prior verified accessible original shop absent");return
    if int(north.statistics.get("buildings",0))!=11:
        _fail("the original 11 map lots must be kept");return
    var player:CityPlayer=scene.get_node_or_null("Player") as CityPlayer
    if player == null or player.camera == null or not player.animation_verified:
        _fail("original actual skinned CityPlayer unavailable");return
    if player.camera_sweep_query == null or player.camera_collision_shape == null:
        _fail("actual camera obstacle sweep mechanism not initialized");return
    if absf(player.global_position.x-QA_START_X)>.01 or absf(
            player.global_position.z-116.0)>.01:
        _fail("player wasn't spawned at the route start by QA gate");return
    if not InputMap.has_action("move_forward") or not InputMap.has_action("move_back"):
        _fail("original WASD InputMap not configured");return
    var base_tick:int=player.physics_tick_counter
    var evidence:Dictionary={
        "version":"V0.38",
        "real_original_production_cityplayer":true,
        "character_class":"CityPlayer/CharacterBody3D",
        "input_path":"Input.parse_input_event physical KEY_W/A/D/S -> InputMap -> CityPlayer._physics_process -> move_and_slide",
        "qa_only_initial_spawn":_xyz(player.global_position),
        "test_moves_avatar_node_directly_after_initial_spawn":false,
        "qa_world_flag_only":true,
        "screenshot_camera":"real CityPlayer.ThirdPersonCamera",
        "original_north_lots":11,
        "storefront_qa_interiors":1,
        "frames":[],
        "trace":[],
        "real_user_hardware_input_tested":false,
        "full_mesh_sole_ik_proven":false,
        "retail_economy_connected":false,
        "web_export_or_windows_fps_verified":false,
        "holistic_art_approved":false
    }
    var trace:Array=evidence["trace"]
    # Let actual original player capsule settle on public pavement before keypress.
    for t in range(18):
        await physics_frame
    if not player.is_on_floor():
        _fail("actual CityPlayer does not stand on north pavement");return
    _trace(player,"street_idle",trace)
    if not await _capture(player,"street_idle"):
        _fail("actual player-camera street PNG missing");return
    evidence["frames"].append("v38_street_idle.png")
    var start:Vector3=player.global_position
    _key(KEY_W,true)
    await physics_frame
    if not Input.is_action_pressed("move_forward"):
        _fail("actual physical W did not activate original InputMap");return
    var reached_inside:bool=false
    var crossed_door:bool=false
    var ground_ticks:int=0
    var dynamic_pose_ticks:int=0
    var peak_ankle:float=0.0
    var forward_steps:int=0
    for i in range(MAX_STEPS):
        await physics_frame
        forward_steps+=1
        if player.is_on_floor():
            ground_ticks+=1
        if player.anim_weight>.25:
            dynamic_pose_ticks+=1
        peak_ankle=maxf(peak_ankle,absf(player.foot_clearance_vs_idle()))
        if i%15==0:
            _trace(player,"W_forward",trace)
        if not crossed_door and player.global_position.x < QA_DOOR_X-.5:
            crossed_door=true
            _trace(player,"door_crossing",trace)
        if player.global_position.x <= QA_INSIDE_X:
            reached_inside=true
            break
    _key(KEY_W,false)
    await physics_frame
    if not reached_inside:
        _fail("real W held for %d ticks but actual player could not enter; x=%.3f, start=%.3f" %
            [forward_steps,player.global_position.x,start.x]);return
    if not crossed_door or ground_ticks < 55 or dynamic_pose_ticks < 55:
        _fail("forward input did not demonstrate supported on-floor walking+gait");return
    var inside:Vector3=player.global_position
    if not await _capture(player,"shop_enter"):
        _fail("original player-camera inside PNG missing");return
    evidence["frames"].append("v38_shop_enter.png")
    # Natural neutral input coast: no injected position updates.
    for i in range(23):
        await physics_frame
    _trace(player,"stopped_inside",trace)
    if player.global_position.distance_to(inside)>.9 or player.anim_weight>.42:
        _fail("real player failed to stop smoothly inside shop");return
    if not await _capture(player,"stopped_inside"):
        _fail("stationary inside player-camera PNG missing");return
    evidence["frames"].append("v38_stopped_inside.png")
    # Real A then D key dispatch to rotate the avatar facing and restore aisle.
    var old_facing:float=player.character_visual.rotation.y
    _key(KEY_A,true)
    await physics_frame
    if not Input.is_action_pressed("move_left"):
        _fail("A key did not reach original action input");return
    for i in range(8):
        await physics_frame
    _key(KEY_A,false)
    # The physical-key event queue needs a clean release frame between
    # opposing horizontal inputs in the software-rendered Xvfb harness.
    # Require evidence for D rather than substituting Input.action_press().
    for clean_release in range(3):
        await physics_frame
    var turn_change:float=absf(wrapf(
        player.character_visual.rotation.y-old_facing,-PI,PI))
    if turn_change<.18:
        _fail("original avatar not responding to A strafe/turn input");return
    _trace(player,"turned_left",trace)
    var mapped_d:bool=false
    for event in InputMap.action_get_events("move_right"):
        if event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_D:
            mapped_d=true
    if not mapped_d:
        _fail("D key was not present in actual game's move_right InputMap");return
    var z_before_d:float=player.global_position.z
    _key(KEY_D,true)
    var d_observed:bool=false
    for d_tick in range(14):
        await physics_frame
        d_observed=d_observed or Input.is_action_pressed("move_right")
    _key(KEY_D,false)
    if not d_observed:
        _fail("D physical key not registered across 14 ticks; InputMap mapped="+str(mapped_d)+
            ", z_delta="+str(player.global_position.z-z_before_d)+
            ", pressed="+str(Input.is_action_pressed("move_right")));return
    evidence["D_key_input_observed"]=d_observed
    evidence["D_strafe_displacement_m"]=player.global_position.z-z_before_d
    for i in range(12):
        await physics_frame
    _trace(player,"turn_recovered",trace)
    if absf(player.global_position.z-116.0)>1.45:
        _fail("A/D turn walked out of doorway corridor");return
    if not await _capture(player,"turn_inside"):
        _fail("original player-camera turning PNG missing");return
    evidence["frames"].append("v38_turn_inside.png")
    _key(KEY_S,true)
    await physics_frame
    if not Input.is_action_pressed("move_back"):
        _fail("original S key not mapped");return
    var exited:bool=false
    var reverse_steps:int=0
    for i in range(MAX_STEPS):
        await physics_frame
        reverse_steps+=1
        if i%15==0:
            _trace(player,"S_reverse",trace)
        if player.global_position.x >= QA_START_X+.15:
            exited=true
            break
    _key(KEY_S,false)
    if not exited:
        _fail("the real CityPlayer could enter but failed to WALK out; x="+str(player.global_position.x));return
    for i in range(20):
        await physics_frame
    _trace(player,"street_return_idle",trace)
    if not player.is_on_floor():
        _fail("returned player isn't on real public pavement");return
    if not await _capture(player,"street_return"):
        _fail("actual returning player-camera PNG missing");return
    evidence["frames"].append("v38_street_return.png")
    if player.physics_tick_counter-base_tick < forward_steps + reverse_steps + 65:
        _fail("actual player physics process did not drive route");return
    if peak_ankle > .65:
        _fail("ankle reference deviated unreasonably; not sole-level IK proof");return
    evidence["forward_W_physics_ticks"]=forward_steps
    evidence["backward_S_physics_ticks"]=reverse_steps
    evidence["grounded_ticks_while_W"]=ground_ticks
    evidence["animated_gait_ticks_while_W"]=dynamic_pose_ticks
    evidence["initial_street"]= _xyz(start)
    evidence["first_inside"]= _xyz(inside)
    evidence["returned_street"]= _xyz(player.global_position)
    evidence["total_forward_distance_m"]=start.distance_to(inside)
    evidence["max_ankle_reference_deviation_m"]=peak_ankle
    evidence["original_player_physics_ticks"]=player.physics_tick_counter-base_tick
    evidence["original_player_camera_collision_activations"]=player.camera_collision_activations
    evidence["original_camera_sweep_initialized"]=true
    evidence["turn_delta_radians"]=turn_change
    evidence["w_s_pressed_using_real_key_events"]=true
    evidence["qa_result"]=true
    var file:FileAccess=FileAccess.open(ProjectSettings.globalize_path(
        "res://tests/v38_real_player_walk_metrics.json"), FileAccess.WRITE)
    if file == null:
        _fail("Godot could not save route telemetry");return
    file.store_string(JSON.stringify(evidence,"  ")+"\n")
    file.close()
    print("V38 REAL CITYPLAYER WASD ROUNDTRIP PASS: "+JSON.stringify({
        "W_ticks":forward_steps,"S_ticks":reverse_steps,
        "grounded_ticks":ground_ticks,"gait_ticks":dynamic_pose_ticks,
        "screenshots":evidence["frames"].size(),"camera_collision_activations":
            evidence["original_player_camera_collision_activations"]}))
    quit(0)
