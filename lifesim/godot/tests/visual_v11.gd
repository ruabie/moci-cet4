extends SceneTree
# Viewport evidence: indoor rooms plus licensed outdoor block. Not merely a GLB file check.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        printerr("V11 CAPTURE FAIL: scene missing")
        quit(1)
        return
    var stage: Node3D = scene.instantiate() as Node3D
    root.add_child(stage)
    for i in range(60):
        await process_frame
    var cafe: CuratedInteriorsV11 = stage.get_node_or_null("CafeInterior") as CuratedInteriorsV11
    var mart: CuratedInteriorsV11 = stage.get_node_or_null("MartInterior") as CuratedInteriorsV11
    var home: CuratedInteriorsV11 = stage.get_node_or_null("ApartmentInterior") as CuratedInteriorsV11
    if cafe == null or mart == null or home == null:
        printerr("V11 CAPTURE FAIL: one or more furnished spaces missing")
        quit(1)
        return
    var camera := Camera3D.new()
    camera.name = "V11VisualEvidence"
    camera.fov = 69
    stage.add_child(camera)
    var scenes: Array = [
        ["v11_cafe", cafe.to_global(Vector3(0.0,2.45,3.65)), cafe.to_global(Vector3(-1.8,1.50,-3.85))],
        ["v11_mart", mart.to_global(Vector3(0.0, 2.45, 4.5)), mart.to_global(Vector3(1.2, 1.50, -3.75))],
        ["v11_home", Vector3(0.15, 2.45, 153.65), Vector3(-2.0, 1.35, 146.25)],
        ["v11_licensed_block", Vector3(-2.4, 3.4, -48.0), Vector3(-25, 5.0, -66)]
    ]
    for view in scenes:
        camera.global_position = view[1]
        camera.look_at(view[2])
        camera.current = true
        for n in range(30):
            await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty() or frame.get_width() < 800:
            printerr("V11 CAPTURE FAIL: viewport image missing")
            quit(1)
            return
        var name: String = "res://tests/%s.png" % str(view[0])
        if frame.save_png(name) != OK:
            printerr("V11 CAPTURE FAIL: unable to write PNG: " + name)
            quit(1)
            return
        print("V11 CAPTURE PASS: ", name)
    stage.queue_free()
    quit(0)
