extends SceneTree

# V0.32 REAL GODOT spatial pilot: present CityBuilder + QA-only northern
# extension. Quantify actual 3D collisions and save viewport images. Not an
# acceptance of crowd/traffic, new public building interiors, or GPU FPS.
const VIEWS: Array = [
    ["v32_north_aerial",Vector3(72,93,294),Vector3(0,3,179),58.0],
    ["v32_road_continuity",Vector3(2.6,6.3,83),Vector3(0,2.5,135),58.0],
    ["v32_community_cross",Vector3(16,6.2,163),Vector3(-24,2.0,168),61.0],
    ["v32_park_walkway",Vector3(-83,6.8,222),Vector3(-63,1.5,244),59.0],
    ["v32_bus_stop",Vector3(-20,4.3,126),Vector3(-13.5,1.55,135),57.0]
]

func _initialize() -> void:
    call_deferred("_execute")

func _fail(message:String) -> void:
    printerr("V32 CITY SPATIAL FAIL: "+message)
    quit(1)

func _sample_ground(scene:Node3D,x:float,z:float) -> Dictionary:
    var start:=Vector3(x,12.0,z)
    var end:=Vector3(x,-3.0,z)
    var query:=PhysicsRayQueryParameters3D.create(start,end,1)
    query.collide_with_areas=false
    var result:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return {"hit":false,"x":x,"z":z}
    var at:Vector3=result["position"]
    var obj:CollisionObject3D=result["collider"] as CollisionObject3D
    return {"hit":true,"x":x,"z":z,"height":snappedf(at.y,.004),
            "collider":str(obj.name) if obj!=null else "unknown"}

func _save(name:String,cam:Camera3D,origin:Vector3,target:Vector3,fov:float) -> bool:
    cam.fov=fov
    cam.global_position=origin
    cam.look_at(target,Vector3.UP)
    for i in range(8):
        await process_frame
    RenderingServer.force_draw(false)
    var picture:Image=root.get_viewport().get_texture().get_image()
    if picture==null or picture.get_width()<720 or picture.get_height()<400:
        return false
    return picture.save_png(ProjectSettings.globalize_path("res://tests/"+name+".png"))==OK

func _execute() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    var world_res:PackedScene=load("res://scenes/main.tscn") as PackedScene
    if world_res==null:
        _fail("production LifeSim scene missing")
        return
    var stage:Node3D=world_res.instantiate() as Node3D
    root.add_child(stage)
    await process_frame
    await physics_frame
    var city:CityBuilder=stage.get_node_or_null("AokawaDistrict") as CityBuilder
    if city==null:
        _fail("real city builder missing")
        return
    var north:PlannedDistrictV32=city.get_node_or_null(
        "V32NorthWalkableDistrictPreview") as PlannedDistrictV32
    if north==null:
        _fail("QA preview not inserted into actual city")
        return
    var old:Node3D=city.get_node_or_null("V10DistantUrbanBackdrop") as Node3D
    if old==null or old.visible:
        _fail("ghost skyline intersects the newly walkable northern ground")
        return
    var stats:Dictionary=north.statistics
    if str(stats.get("v32_version",""))!="V0.32" or int(stats.get("buildings",0))!=11:
        _fail("authored district lots missing: "+JSON.stringify(stats))
        return
    if int(stats.get("doors_with_paths",0))!=11 or int(stats.get("parks",0))!=1:
        _fail("door access or public park missing")
        return
    if int(stats.get("visible_facade_windows",0))<350:
        _fail("too few four-sided facade/window bays for the enlarged district")
        return
    if int(stats.get("original_glb_foliage_instances",0))<14:
        _fail("missing original branched glTF landscape assets; primitive trees are not acceptable")
        return
    if float(stats.get("ground_m2",0))<33000:
        _fail("new physical walkable land is not really larger")
        return
    var required:Array[String]=[
        "V32WestSideBusShelter","V32PublicBikeDock",
        "V32CommunityGreenAndPublicPath"]
    for n in required:
        if north.get_node_or_null(n)==null:
            _fail("missing intended public facility "+n)
            return
    var checks:Array[Vector2]=[
        Vector2(0,88),Vector2(0,93),Vector2(0,113),
        Vector2(0,145),Vector2(0,165),Vector2(0,195),
        Vector2(0,222),Vector2(0,254),Vector2(0,268),
        Vector2(-9,119),Vector2(9,119),Vector2(-9,215),Vector2(9,246),
        Vector2(-65,145),Vector2(65,145),
        Vector2(-65,222),Vector2(65,222),Vector2(-65,245),
        Vector2(-82,145),Vector2(82,222)]
    var hits:Array[Dictionary]=[]
    for point in checks:
        var result:Dictionary=_sample_ground(stage,point.x,point.y)
        if not bool(result.get("hit",false)):
            _fail("physical walkable collision missing at "+str(point))
            return
        if absf(float(result.get("height",-999)))>.28:
            _fail("proposed public road/footpath obstructed or raised: "+JSON.stringify(result))
            return
        hits.append(result)
    var player:Node3D=stage.get_node_or_null("Player") as Node3D
    if player!=null:
        player.visible=false
    var hud:CanvasLayer=stage.get_node_or_null("HUD") as CanvasLayer
    if hud!=null:
        hud.visible=false
    var cam:=Camera3D.new()
    stage.add_child(cam)
    cam.current=true
    var captures:Array[String]=[]
    for view in VIEWS:
        var filename:String=str(view[0])
        if not await _save(filename,cam,view[1] as Vector3,
                view[2] as Vector3,float(view[3])):
            _fail("unable to capture real district Godot image "+filename)
            return
        captures.append(filename+".png")
    var metrics:Dictionary={
        "ok":true,"version":"V0.32","scene":"actual LifeSim main.tscn QA setting only",
        "new_ground_m2":stats["ground_m2"],
        "original_ground_m2":32400.0,
        "total_ground_m2_before_subtracting_seam":32400.0+float(stats["ground_m2"]),
        "buildings":stats["buildings"],
        "door_access_routes":stats["doors_with_paths"],
        "public_park_count":stats["parks"],
        "facade_window_bays":stats["visible_facade_windows"],
        "actual_glb_foliage_instances":stats["original_glb_foliage_instances"],
        "geometry_parts":stats["geometry_pieces"],
        "ghost_backdrop_visible":old.visible,
        "public_ground_rays":hits,
        "actual_godot_screenshots":captures,
        "limits":["QA-only preview flag; no production change",
            "New facades exterior-only and not interactive yet",
            "No actual player-driven continuous traversal or navigation mesh",
            "Footwear, art, Chrome WebGL and RTX3060 performance not approved"]
    }
    var output:FileAccess=FileAccess.open(ProjectSettings.globalize_path(
        "res://tests/v32_actual_city_metrics.json"),FileAccess.WRITE)
    if output==null:
        _fail("cannot save objective Godot QA metrics")
        return
    output.store_string(JSON.stringify(metrics,"\t")+"\n")
    output.close()
    print("V32 REAL EXPANDED CITY SPATIAL PASS: "+JSON.stringify({
        "building_count":stats["buildings"],
        "new_ground_m2":stats["ground_m2"],
        "road_and_sidewalk_physics_samples":hits.size(),
        "windows":stats["visible_facade_windows"],
        "real_modelled_tree_count":stats["original_glb_foliage_instances"],
        "screenshot_count":captures.size(),
        "ghost_backdrop_hidden":true
    }))
    quit(0)
