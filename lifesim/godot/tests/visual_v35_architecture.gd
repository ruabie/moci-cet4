extends SceneTree

# V0.35: run the ORIGINAL game scene twice with identical framing,
# once with only V32+V33, then with a two-building V35 architecture
# replacement. This is an art REVIEW gate, never production approval.
const SHOTS: Array = [
    ["residence", Vector3(-4.8, 7.2, 107.0), Vector3(-28.0, 8.1, 116.0), 56.0],
    ["library", Vector3(0.0, 6.7, 194.0), Vector3(28.0, 7.2, 201.0), 57.0]
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    printerr("V35 ARCHITECTURE QA FAIL: " + reason)
    quit(1)

func _capture(cam: Camera3D, shot: Array, name: String) -> bool:
    cam.global_position = shot[1] as Vector3
    cam.look_at(shot[2] as Vector3, Vector3.UP)
    cam.fov = float(shot[3])
    for i in range(8):
        await process_frame
    RenderingServer.force_draw(false)
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width() < 720 or img.get_height() < 400:
        return false
    return img.save_png(ProjectSettings.globalize_path("res://tests/" + name + ".png")) == OK

func _run() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    ProjectSettings.set_setting("application/config/v32_spatial_preview", true)
    ProjectSettings.set_setting("application/config/v33_streetscape_preview", true)
    var comparisons: Array[Dictionary] = []
    var results: Dictionary = {}
    for enabled in [false, true]:
        ProjectSettings.set_setting("application/config/v35_architecture_preview", enabled)
        var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
        if packed == null:
            _fail("missing original main scene")
            return
        var scene: Node3D = packed.instantiate() as Node3D
        root.add_child(scene)
        await process_frame
        await physics_frame
        var district: PlannedDistrictV32 = scene.get_node_or_null(
            "AokawaDistrict/V32NorthWalkableDistrictPreview") as PlannedDistrictV32
        if district == null or int(district.statistics.get("buildings",0)) != 11:
            _fail("existing connected district / eleven original parcels missing")
            return
        var shots_stats: Dictionary = {}
        if enabled:
            if int(district.statistics.get("v35_architecture_pilots", 0)) != 2:
                _fail("two designated pilot parcels not actually replaced")
                return
            for lot in ["west_homes_a", "east_library"]:
                var node: ArchitecturalSliceV35 = district.get_node_or_null(
                    "PlannedLot_" + lot + "/V35Architecture_" + lot) as ArchitecturalSliceV35
                if node == null or node.statistics.get("exterior_only") != true:
                    _fail("one V35 authored architectural lot or exterior-only marker missing")
                    return
                if int(node.statistics.get("mesh_count",0)) < 48:
                    _fail("architectural profile too sparse to replace plain monolith " + lot)
                    return
                shots_stats[lot] = node.statistics
            if str(shots_stats["west_homes_a"]["profile"]) == str(shots_stats["east_library"]["profile"]):
                _fail("different land uses generated the same architecture profile")
                return
            # Real physics ray probes on the two public door-access paths.
            for point in [Vector2(-15.0,116.0),Vector2(14.0,201.0)]:
                var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
                    Vector3(point.x,12,point.y), Vector3(point.x,-3,point.y),1)
                var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
                if hit.is_empty() or absf(float((hit.get("position",Vector3(0,100,0)) as Vector3).y)) > .28:
                    _fail("existing exterior door access blocked " + str(point))
                    return
            results["architecture_profiles"] = shots_stats
            results["door_path_collision_ray_checks"] = 2
        var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
        if hud != null: hud.visible = false
        var avatar: Node3D = scene.get_node_or_null("Player") as Node3D
        if avatar != null: avatar.visible = false
        var cam := Camera3D.new()
        cam.current = true
        scene.add_child(cam)
        for shot in SHOTS:
            var tag: String = str(shot[0])
            var name: String = "v35_" + ("after_" if enabled else "before_") + tag
            if not await _capture(cam,shot,name):
                _fail("authentic Godot screenshot failed: " + name)
                return
            comparisons.append({"lot":tag,"phase":"V35" if enabled else "V33",
                "png":name+".png","identical_camera":true})
        scene.queue_free()
        await process_frame
        await physics_frame
    results["version"] = "V0.35"
    results["ok"] = true
    results["real_render_count"] = comparisons.size()
    results["screenshots"] = comparisons
    results["production_city_changed"] = false
    results["not_proven"] = ["art-director approval","enterable interiors",
        "continuous walking","Chrome WebGL","Windows hardware FPS"]
    var f: FileAccess = FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v35_architecture_metrics.json"),FileAccess.WRITE)
    if f == null:
        _fail("failed to archive per-profile objective metrics")
        return
    f.store_string(JSON.stringify(results,"\t")+"\n")
    f.close()
    print("V35 REAL ARCHITECTURE RENDER PASS: " + JSON.stringify({
        "pairs":2,"different_profiles":2,"public_access_ray_checks":2}))
    quit(0)
