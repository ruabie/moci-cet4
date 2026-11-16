extends SceneTree

# Identical aisle lens and coordinates to V0.16 for real before/after review.
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode",true)
    var resource: PackedScene = load("res://scenes/main.tscn")
    if resource == null:
        printerr("V17 CAPTURE FAIL: scene missing")
        quit(1)
        return
    var stage: Node3D = resource.instantiate() as Node3D
    root.add_child(stage)
    await process_frame
    var mart: WalkableMartV17 = stage.get_node_or_null("MartInterior") as WalkableMartV17
    if mart == null or mart.open_refrigerator_bays != 3:
        printerr("V17 CAPTURE FAIL: refrigerated cabinets absent")
        quit(1)
        return
    var avatar: Node3D = stage.get_node_or_null("Player") as Node3D
    if avatar != null:
        avatar.visible = false
    var hud: CanvasLayer = stage.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var cam: Camera3D = Camera3D.new()
    cam.fov = 69
    stage.add_child(cam)
    cam.current = true
    var views: Array = [
        ["v17_shop_aisles",mart.to_global(Vector3(0,1.76,3.96)),mart.to_global(Vector3(0,1.42,-2.7))],
        ["v17_refrigerator_cavity",mart.to_global(Vector3(0.4,1.7,-2.60)),mart.to_global(Vector3(0,1.30,-5.50))],
        ["v17_cold_stock_detail",mart.to_global(Vector3(-1.30,1.47,-3.70)),mart.to_global(Vector3(-3.85,1.26,-5.37))],
        ["v17_storefront",mart.to_global(Vector3(0,2.0,10.3)),mart.to_global(Vector3(0,1.6,0))]
    ]
    for view in views:
        cam.global_position = view[1]
        cam.look_at(view[2],Vector3.UP)
        for n in range(12):
            await process_frame
        var pic: Image = root.get_viewport().get_texture().get_image()
        if pic == null or pic.get_width() < 720:
            printerr("V17 CAPTURE FAIL: blank viewport")
            quit(1)
            return
        var path: String = "res://tests/" + view[0] + ".png"
        if pic.save_png(ProjectSettings.globalize_path(path)) != OK:
            printerr("V17 CAPTURE FAIL: cannot save " + path)
            quit(1)
            return
        print("V17 CAPTURE PASS: " + path)
    stage.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode",false)
    quit(0)
