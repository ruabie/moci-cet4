extends SceneTree
# Genuine Godot OpenGL render. Inspection cameras are only part of the QA script.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        printerr("V08 CAPTURE FAIL: missing main scene")
        quit(1)
        return
    var game: Node3D = scene.instantiate() as Node3D
    root.add_child(game)
    for i in range(24):
        await process_frame
    var cam := Camera3D.new()
    cam.fov = 61.0
    game.add_child(cam)
    var views := [
        ["cafe", Vector3(5.6,5.9,-1.7),Vector3(18.0,3.25,-14.0)],
        ["mart", Vector3(-5.3,5.8,-1.5),Vector3(-17.5,2.9,-14.0)]
    ]
    for view in views:
        cam.global_position = view[1]
        cam.look_at(view[2], Vector3.UP)
        cam.current = true
        for i in range(20):
            await process_frame
        await RenderingServer.frame_post_draw
        var im: Image = root.get_texture().get_image()
        if im == null or im.is_empty() or im.get_width() < 800:
            printerr("V08 CAPTURE FAIL: empty viewport")
            quit(1)
            return
        var dest := "res://tests/v08_hero_%s.png" % str(view[0])
        if im.save_png(dest) != OK:
            printerr("V08 CAPTURE FAIL: cannot save PNG")
            quit(1)
            return
        print("V08 CAPTURE PASS: ", dest)
    game.queue_free()
    quit(0)
