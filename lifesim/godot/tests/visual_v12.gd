extends SceneTree
# Actual renderer evidence: compare with V11 at similar positions and report
# compact interior silhouettes rather than claiming functional QA proves beauty.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        printerr("V12 CAPTURE FAIL: main scene missing")
        quit(1)
        return
    var stage: Node3D = scene.instantiate() as Node3D
    root.add_child(stage)
    for i in range(70):
        await process_frame
    for room_name in ["CafeInterior","MartInterior","ApartmentInterior"]:
        var room := stage.get_node_or_null(room_name) as CuratedInteriorsV12
        if room == null or room.functional_zones.size() < 4:
            printerr("V12 CAPTURE FAIL: missing room zones " + room_name)
            quit(1)
            return
    var cafe: Node3D = stage.get_node("CafeInterior") as Node3D
    var camera := Camera3D.new()
    camera.name = "V12EvidenceCamera"
    camera.fov = 66
    camera.near = .08
    stage.add_child(camera)
    var views: Array = [
        ["v12_cafe_front", cafe.to_global(Vector3(0,2.8,4.0)), cafe.to_global(Vector3(-1.0,1.5,-4.5))],
        ["v12_cafe_service", cafe.to_global(Vector3(3.95,2.55,2.1)), cafe.to_global(Vector3(-2.0,1.5,-3.45))],
        ["v12_mart_front", Vector3(0.2,2.8,194.2), Vector3(0,1.5,186.0)],
        ["v12_mart_aisles", Vector3(1.8,2.4,192.8), Vector3(-1.8,1.55,188.5)],
        ["v12_home_front", Vector3(.35,2.45,152.3), Vector3(-1.8,1.55,147.2)],
        ["v12_home_corner", Vector3(3.15,2.4,151.5), Vector3(-3.1,1.35,147.2)]
    ]
    for v in views:
        camera.global_position=v[1]
        camera.look_at(v[2])
        camera.current = true
        for k in range(24):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width() < 800:
            printerr("V12 CAPTURE FAIL: empty viewport")
            quit(1)
            return
        var dest: String = "res://tests/%s.png" % str(v[0])
        if img.save_png(dest) != OK:
            printerr("V12 CAPTURE FAIL: cannot save " + dest)
            quit(1)
            return
        print("V12 CAPTURE PASS: ",dest)
    stage.queue_free()
    quit(0)