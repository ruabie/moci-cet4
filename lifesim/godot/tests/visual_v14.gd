extends SceneTree
# Capture a real continuous street, physical doorway and window view.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        printerr("V14 CAPTURE FAIL: cannot load scene")
        quit(1)
        return
    var stage: Node3D = packed.instantiate() as Node3D
    root.add_child(stage)
    for i in range(75):
        await process_frame
    var cafe: WalkableCafeV14 = stage.get_node_or_null("CafeInterior") as WalkableCafeV14
    if cafe == null or cafe.quaternius_assets < 12:
        printerr("V14 CAPTURE FAIL: no furnished walkable cafe")
        quit(1)
        return
    var hud: CanvasLayer = stage.get_node_or_null("HUD") as CanvasLayer
    if hud != null: hud.visible = false
    var cam := Camera3D.new()
    cam.fov = 63.0
    cam.near = .08
    stage.add_child(cam)
    var views: Array = [
        ["v14_from_sidewalk", cafe.to_global(Vector3(0,2.05,10.25)), cafe.to_global(Vector3(-.2,1.35,1.5))],
        ["v14_at_threshold", cafe.to_global(Vector3(0,1.90,4.45)), cafe.to_global(Vector3(-1.15,1.45,-3.5))],
        ["v14_inside_counter", cafe.to_global(Vector3(1.85,1.78,1.25)), cafe.to_global(Vector3(-1.75,1.45,-3.8))],
        ["v14_look_out_to_real_street", cafe.to_global(Vector3(-2,1.90,-.60)), cafe.to_global(Vector3(0,1.45,12))]
    ]
    for view in views:
        cam.global_position = view[1]
        cam.look_at(view[2])
        cam.current = true
        for n in range(35): await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty() or frame.get_width() < 800:
            printerr("V14 CAPTURE FAIL: empty viewport")
            quit(1)
            return
        var file: String = "res://tests/%s.png" % view[0]
        if frame.save_png(file) != OK:
            printerr("V14 CAPTURE FAIL: cannot save " + file)
            quit(1)
            return
        print("V14 CAPTURE PASS: ", file)
    stage.queue_free()
    quit(0)
