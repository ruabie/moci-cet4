extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        printerr("V16 CAPTURE FAIL: scene missing")
        quit(1)
        return
    var stage: Node3D = scene.instantiate() as Node3D
    root.add_child(stage)
    await process_frame
    var mart: WalkableMartV16 = stage.get_node_or_null("MartInterior") as WalkableMartV16
    if mart == null or mart.stocked_sku_instances < 170 or mart.rack_count != 4:
        printerr("V16 CAPTURE FAIL: custom mart not created")
        quit(1)
        return
    var avatar: Node3D = stage.get_node_or_null("Player") as Node3D
    if avatar != null:
        avatar.visible = false
    var cam: Camera3D = Camera3D.new()
    cam.fov = 69
    stage.add_child(cam)
    cam.current = true
    var views: Array = [
        ["v16_shop_aisles",mart.to_global(Vector3(0,1.76,3.96)),mart.to_global(Vector3(0,1.42,-2.7))],
        ["v16_stock_closeup",mart.to_global(Vector3(1.12,1.58,1.80)),mart.to_global(Vector3(3.02,1.10,-.20))],
        ["v16_refrigeration",mart.to_global(Vector3(0,1.8,.1)),mart.to_global(Vector3(0,1.22,-5.55))]
    ]
    for item in views:
        cam.global_position = item[1]
        cam.look_at(item[2],Vector3.UP)
        for i in range(10):
            await process_frame
        var tex: Texture2D = root.get_viewport().get_texture()
        var picture: Image = tex.get_image()
        if picture == null or picture.get_width() < 720:
            printerr("V16 CAPTURE FAIL: viewport empty")
            quit(1)
            return
        var filename: String = "res://tests/" + item[0] + ".png"
        var error: int = picture.save_png(ProjectSettings.globalize_path(filename))
        if error != OK:
            printerr("V16 CAPTURE FAIL: image save " + filename)
            quit(1)
            return
        print("V16 CAPTURE PASS: " + filename)
    stage.queue_free()
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)
