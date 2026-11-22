extends SceneTree

# Real Godot A/B from SAME map, time and camera. All extra props/lighting
# remain behind the joint V32+V33 QA flags. No staged/mock screenshots.
const SHOTS: Array = [
    ["road",Vector3(2.6,6.3,83.0),Vector3(0,2.5,135.0),58.0],
    ["cross",Vector3(16.0,6.2,163.0),Vector3(-24.0,2.0,168.0),61.0],
    ["park",Vector3(-83.0,6.8,222.0),Vector3(-63.0,1.5,244.0),59.0],
    ["facades",Vector3(-6.2,3.4,212.0),Vector3(28.0,3.0,201.0),54.0]
]
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason:String) -> void:
    printerr("V33 REAL CITY ART FAIL: "+reason)
    quit(1)

func _render(cam:Camera3D,where:Vector3,target:Vector3,fov:float,name:String) -> bool:
    cam.fov=fov
    cam.global_position=where
    cam.look_at(target,Vector3.UP)
    for t in range(7):
        await process_frame
    RenderingServer.force_draw(false)
    var img:Image=root.get_viewport().get_texture().get_image()
    if img==null or img.get_width()<720 or img.get_height()<400:
        return false
    return img.save_png(ProjectSettings.globalize_path("res://tests/"+name+".png"))==OK

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    ProjectSettings.set_setting("application/config/v33_streetscape_preview",true)
    var packed:PackedScene=load("res://scenes/main.tscn") as PackedScene
    if packed==null:
        _fail("missing real original LifeSim game scene")
        return
    var scene:Node3D=packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame
    var city:CityBuilder=scene.get_node_or_null("AokawaDistrict") as CityBuilder
    if city==null:
        _fail("missing original CityBuilder")
        return
    var north:PlannedDistrictV32=city.get_node_or_null("V32NorthWalkableDistrictPreview") as PlannedDistrictV32
    var detail:StreetscapeDetailsV33=city.get_node_or_null("V33StreetLevelArtReview") as StreetscapeDetailsV33
    if north==null or detail==null:
        _fail("one or both gated district preview layers missing")
        return
    var metrics:Dictionary=detail.stats
    if int(metrics.get("authored_frontages",0))!=11:
        _fail("not every V32 property got a building-frontage improvement")
        return
    if int(metrics.get("licensed_fixtures",0))<24:
        _fail("real Kenney GLB props missing, no box substitutions allowed")
        return
    if int(metrics.get("authored_detail_meshes",0))<65:
        _fail("no significant exterior storefront/planter/fence details")
        return
    if str(metrics.get("version",""))!="V0.33":
        _fail("incorrect versioned visual layer")
        return
    if int(north.statistics.get("buildings",0))!=11:
        _fail("original V32 construction is not preserved")
        return
    # Main.gd creates this WorldEnvironment dynamically and exposes it as a
    # script member. Dynamic Godot node names are NOT guaranteed "WorldEnvironment".
    var ambient:WorldEnvironment=scene.get("ambient_env") as WorldEnvironment
    if ambient==null or ambient.environment==null:
        _fail("main scene world sky/environment unavailable")
        return
    var env:Environment=ambient.environment
    var sky:ProceduralSkyMaterial=env.sky.sky_material as ProceduralSkyMaterial
    if sky==null:
        _fail("main ProceduralSkyMaterial missing")
        return
    var original:Dictionary={
        "exposure":env.tonemap_exposure,
        "ambient":env.ambient_light_energy,
        "fog":env.fog_density,
        "horizon":sky.sky_horizon_color.to_html(false)
    }
    if absf(float(original["exposure"])-.74)>.001:
        _fail("V33 lowered exposure is not correctly gated")
        return
    var hud:CanvasLayer=scene.get_node_or_null("HUD") as CanvasLayer
    if hud!=null:
        hud.visible=false
    var player:Node3D=scene.get_node_or_null("Player") as Node3D
    if player!=null:
        player.visible=false
    var cam:=Camera3D.new()
    cam.current=true
    scene.add_child(cam)
    var pairs:Array[Dictionary]=[]
    for shot in SHOTS:
        var tag:String=str(shot[0])
        # Original V32 settings and hide extras; no changes to cameras or time.
        detail.visible=false
        env.tonemap_exposure=1.0
        env.ambient_light_energy=.18
        env.fog_density=.00185
        sky.sky_horizon_color=Color("#c3c7c3")
        var before:String="v33_before_"+tag+".png"
        if not await _render(cam,shot[1] as Vector3,shot[2] as Vector3,float(shot[3]),"v33_before_"+tag):
            _fail("could not capture original V32 frame "+tag)
            return
        detail.visible=true
        env.tonemap_exposure=.74
        env.ambient_light_energy=.12
        env.fog_density=.00115
        sky.sky_horizon_color=Color("#9daeb2")
        var after:String="v33_after_"+tag+".png"
        if not await _render(cam,shot[1] as Vector3,shot[2] as Vector3,float(shot[3]),"v33_after_"+tag):
            _fail("could not capture actual improved V33 frame "+tag)
            return
        pairs.append({"camera":tag,"before":before,"after":after,
            "identical_camera_and_world":true,"changed_stage":"only V33 layer plus reviewed environment"})
    # Preserve the real physics-based road checks from the former milestone.
    var streets:Array[Vector2]=[
        Vector2(0,88),Vector2(0,113),Vector2(0,145),
        Vector2(0,165),Vector2(0,222),Vector2(0,268),
        Vector2(-9,119),Vector2(9,119),Vector2(-9,215),Vector2(9,246),
        Vector2(-65,145),Vector2(65,145),Vector2(-65,222),Vector2(65,222)]
    var good:int=0
    for point in streets:
        var query:=PhysicsRayQueryParameters3D.create(
            Vector3(point.x,12,point.y),Vector3(point.x,-3,point.y),1)
        var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
        if hit.is_empty():
            _fail("public road/crossing lost ground collision "+str(point))
            return
        var pos:Vector3=hit["position"]
        if absf(pos.y)>.28:
            _fail("obstructed public road/sidewalk at "+str(point)+" y="+str(pos.y))
            return
        good+=1
    var report:Dictionary={
        "ok":true,"version":"V0.33","base_version":"V0.32",
        "same_camera_qa_pairs":pairs,"render_count":pairs.size()*2,
        "authored_frontages":metrics["authored_frontages"],
        "kenney_cc0_real_mesh_fixtures":metrics["licensed_fixtures"],
        "new_authored_detail_meshes":metrics["authored_detail_meshes"],
        "preserved_existing_lots":north.statistics["buildings"],
        "public_road_collision_checks":good,
        "experimental_qa_exposure":.74,
        "not_proven":["real player navigation through entrances","true building interiors",
            "professional urban art style","Windows RTX3060 FPS","Chrome WebGL published"]
    }
    var f:FileAccess=FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v33_actual_environment_metrics.json"),FileAccess.WRITE)
    if f==null:
        _fail("failed to write objective render and scene metrics")
        return
    f.store_string(JSON.stringify(report,"\t")+"\n")
    f.close()
    print("V33 REAL STREETSCAPE AB RENDER PASS: "+JSON.stringify({
        "pairs":pairs.size(),"real_cc0_fixtures":metrics["licensed_fixtures"],
        "frontages":metrics["authored_frontages"],
        "old_roads_grounded":good
    }))
    quit(0)
