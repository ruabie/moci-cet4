extends SceneTree

# Fixed interior camera and a second angle make the aesthetic change auditable.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        printerr("V13 CAPTURE FAIL: scene not found")
        quit(1)
        return
    var scene := packed.instantiate() as Node3D
    root.add_child(scene)
    for i in range(90):
        await process_frame
    var cafe: CuratedInteriorsV13 = scene.get_node_or_null("CafeInterior") as CuratedInteriorsV13
    if cafe == null or cafe.quaternius_assets < 12 or cafe.art_lights < 4:
        printerr("V13 CAPTURE FAIL: furnished cafe not initialized")
        quit(1)
        return
    var camera := Camera3D.new()
    camera.name = "V13ArtDirectionCamera"
    camera.fov = 62.0
    camera.near = .07
    scene.add_child(camera)
    var frames: Array = [
        ["v13_cafe_same_camera", Vector3(0, 2.8, 226.0), Vector3(-1.0, 1.5, 217.5)],
        ["v13_cafe_service", Vector3(3.25, 2.45, 224.8), Vector3(-1.4, 1.35, 219.0)],
        ["v13_cafe_window", Vector3(-2.5, 2.20, 221.3), Vector3(1.6, 1.45, 225.15)]
    ]
    for frame in frames:
        camera.global_position=frame[1]
        camera.look_at(frame[2])
        camera.current=true
        for k in range(24):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width()<800:
            printerr("V13 CAPTURE FAIL: no rendered image")
            quit(1)
            return
        var dest: String = "res://tests/%s.png" % frame[0]
        if img.save_png(dest) != OK:
            printerr("V13 CAPTURE FAIL: failed save "+dest)
            quit(1)
            return
        print("V13 CAPTURE PASS: ",dest)
    scene.queue_free()
    quit(0)