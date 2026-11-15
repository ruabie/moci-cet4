extends SceneTree
# Three real Godot captures, including a repeatable V09 comparison viewpoint.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        printerr("V10 CAPTURE FAIL: scene unavailable")
        quit(1)
        return
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    for i in range(50):
        await process_frame
    var district: Node = world.get_node_or_null("AokawaDistrict")
    if district == null or district.get_node_or_null("V10DistantUrbanBackdrop") == null:
        printerr("V10 CAPTURE FAIL: skyline missing")
        quit(1)
        return
    var camera := Camera3D.new()
    camera.name = "V10VisualAcceptanceCamera"
    camera.fov = 61.0
    world.add_child(camera)
    var views: Array = [
        ["v10_cafe_same_camera", Vector3(6.0,3.2,-9.0), Vector3(18.0,3.1,-14.0)],
        ["v10_street_landscape", Vector3(-4.7,3.0,14.0), Vector3(3.0,2.5,-28.0)],
        ["v10_park_trees", Vector3(-8.8,3.9,50.0), Vector3(-24.0,3.5,51.0)]
    ]
    for view in views:
        camera.global_position = view[1]
        camera.look_at(view[2], Vector3.UP)
        camera.current = true
        for i in range(36):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width() < 800:
            printerr("V10 CAPTURE FAIL: viewport empty")
            quit(1)
            return
        var output: String = "res://tests/%s.png" % str(view[0])
        if img.save_png(output) != OK:
            printerr("V10 CAPTURE FAIL: PNG not written")
            quit(1)
            return
        print("V10 CAPTURE PASS: ", output)
    world.queue_free()
    quit(0)