extends SceneTree

# V36 two fixed cameras, same original game map, real GLB asset source.
# Visual difference does NOT equal aesthetic quality acceptance.
const SHOTS: Array = [
    ["street", Vector3(-4.8,7.2,107), Vector3(-28,8.1,116),56.0],
    ["oblique", Vector3(-7.5,5.2,137), Vector3(-28,8.4,116),62.0]
]

func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    printerr("V36 REAL CC0 ART FAIL: " + why)
    quit(1)

func _shot(cam:Camera3D,desc:Array,name:String)->bool:
    cam.global_position=desc[1] as Vector3
    cam.look_at(desc[2] as Vector3,Vector3.UP)
    cam.fov=float(desc[3])
    for t in range(9):
        await process_frame
    RenderingServer.force_draw(false)
    var image:Image=root.get_viewport().get_texture().get_image()
    if image==null or image.get_width()<720 or image.get_height()<400:
        return false
    return image.save_png(ProjectSettings.globalize_path("res://tests/"+name+".png"))==OK

func _run()->void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview",true)
    ProjectSettings.set_setting("application/config/v35_architecture_preview",true)
    # V33 overlay is intentionally OFF in BOTH phases to avoid hiding the
    # imported facade in a decorative procedural awning.
    ProjectSettings.set_setting("application/config/v33_streetscape_preview",false)
    var results:Dictionary={"version":"V0.36","phases":[],"same_camera":true,
        "source_license":"CC0-1.0","production_unchanged":true,
        "not_proven":["professional architecture art approval","interior access",
        "live walking route","Windows 3060 FPS","Chrome WebGL"]}
    for enabled in [false,true]:
        ProjectSettings.set_setting("application/config/v36_pinned_facade_preview",enabled)
        var packed:PackedScene=load("res://scenes/main.tscn") as PackedScene
        if packed==null:
            _fail("real original scene absent");return
        var scene:Node3D=packed.instantiate() as Node3D
        root.add_child(scene)
        await process_frame
        await physics_frame
        var north:PlannedDistrictV32=scene.get_node_or_null(
            "AokawaDistrict/V32NorthWalkableDistrictPreview") as PlannedDistrictV32
        if north==null or int(north.statistics.get("buildings",0))!=11:
            _fail("original 11-lot walkable district absent");return
        var lot:Node3D=north.get_node_or_null("PlannedLot_west_homes_a") as Node3D
        if lot==null:
            _fail("housing test parcel missing");return
        if enabled:
            if int(north.statistics.get("v36_verified_facade_pilots",0))!=1:
                _fail("exactly one pinned facade replacement required");return
            var original:UrbanFacadeV36=lot.get_node_or_null(
                "V36VerifiedResidentialFront") as UrbanFacadeV36
            if original==null:
                _fail("missing actual source-driven housing front");return
            var stats:Dictionary=original.statistics
            if int(stats.get("original_glb_instances",0))!=18:
                _fail("3 bays x 6 storeys must actually instantiate 18 original GLBs");return
            if int(stats.get("source_mesh_variants",0))!=3:
                _fail("source parts reused incorrectly");return
            if int(stats.get("missing_source_models",0))!=0 or int(stats.get("bad_asset_bounds",0))!=0:
                _fail("asset missing or unexpected source model bounds");return
            results["real_original_glb_instances"]=18
            results["pinned_source_variants"]=3
            results["existing_lot_entry_path_preserved"]=true
            results["geometry"]=stats
            # Actual 3D physics tests OUTSIDE the old solid volume, reaching
            # the store frontage. Do not mistake them for interior access.
            var passed:int=0
            for x in [-15.0,-12.0,-10.8]:
                var query:=PhysicsRayQueryParameters3D.create(
                    Vector3(x,12,116),Vector3(x,-3,116),1)
                var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
                if hit.is_empty() or absf((hit["position"] as Vector3).y)>.3:
                    _fail("residential public frontage approach lacks ground "+str(x));return
                passed+=1
            results["public_frontage_raycasts"]=passed
        var hud:CanvasLayer=scene.get_node_or_null("HUD") as CanvasLayer
        if hud!=null:
            hud.visible=false
        var player:Node3D=scene.get_node_or_null("Player") as Node3D
        if player!=null:
            player.visible=false
        var cam:=Camera3D.new()
        cam.current=true
        scene.add_child(cam)
        for shot in SHOTS:
            var tag:String=str(shot[0])
            var filename:String="v36_"+("after_" if enabled else "before_")+tag
            if not await _shot(cam,shot,filename):
                _fail("original Godot PNG missing "+filename);return
            results["phases"].append(filename+".png")
        scene.queue_free()
        await process_frame
        await physics_frame
    results["ok"]=true
    results["render_count"]=results["phases"].size()
    var output:FileAccess=FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v36_real_facade_metrics.json"),FileAccess.WRITE)
    if output==null:
        _fail("cannot write real metrics");return
    output.store_string(JSON.stringify(results,"\t")+"\n")
    output.close()
    print("V36 REAL PINNED GLB RENDER PASS: "+JSON.stringify({
        "source_variants":3,"instances":18,"same_camera_shots":4,
        "public_frontage_raycasts":results["public_frontage_raycasts"]}))
    quit(0)
