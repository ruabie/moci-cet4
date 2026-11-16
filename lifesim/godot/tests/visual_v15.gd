extends SceneTree
# Evidence from the actual physical environment, not synthetic screenshots.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var p: PackedScene = load("res://scenes/main.tscn")
    if p == null:
        printerr("V15 CAPTURE FAIL: scene missing")
        quit(1)
        return
    var stage: Node3D = p.instantiate()
    root.add_child(stage)
    for n in range(65):
        await process_frame
    var mart: WalkableMartV15 = stage.get_node_or_null("MartInterior") as WalkableMartV15
    if mart == null or mart.displayed_products < 45:
        printerr("V15 CAPTURE FAIL: missing furnished street mart")
        quit(1)
        return
    var hud: CanvasLayer = stage.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var cam := Camera3D.new()
    cam.fov = 65.0
    cam.near = .08
    stage.add_child(cam)
    var views: Array = [
        ["v15_mart_from_sidewalk", mart.to_global(Vector3(0, 2.2, 11.5)), mart.to_global(Vector3(0, 1.5, 1.8))],
        ["v15_mart_threshold", mart.to_global(Vector3(0, 1.95, 6.25)), mart.to_global(Vector3(-2.4, 1.5, -2.6))],
        ["v15_mart_checkout", mart.to_global(Vector3(1.4, 1.74, 2.0)), mart.to_global(Vector3(-3.5, 1.3, 3.6))],
        ["v15_mart_aisles", mart.to_global(Vector3(0.0, 1.88, 1.0)), mart.to_global(Vector3(2.8, 1.4, -4.4))],
        ["v15_mart_to_street", mart.to_global(Vector3(-2.4, 1.85, -.9)), mart.to_global(Vector3(0, 1.5, 11.0))]
    ]
    for view in views:
        cam.global_position = view[1]
        cam.look_at(view[2])
        cam.current = true
        for i in range(30):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width() < 800:
            printerr("V15 CAPTURE FAIL: blank renderer")
            quit(1)
            return
        var output: String = "res://tests/%s.png" % view[0]
        if img.save_png(output) != OK:
            printerr("V15 CAPTURE FAIL: cannot save " + output)
            quit(1)
            return
        print("V15 CAPTURE PASS: ", output)
    stage.queue_free()
    quit(0)
