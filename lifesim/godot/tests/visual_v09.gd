extends SceneTree
# 1:1 reproducible architectural inspection camera; no mocked imagery.
func _initialize() -> void:
    call_deferred("capture")
func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        printerr("V09 CAPTURE FAIL: missing main scene")
        quit(1)
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    for i in range(32): await process_frame
    if game.get_node_or_null("AokawaDistrict/Authored_KAWA_COFFEE/V09CuratedCafeAndInterior") == null:
        printerr("V09 CAPTURE FAIL: imported hero missing")
        quit(1)
        return
    var camera := Camera3D.new()
    camera.name = "V09ArchitecturalReview"
    camera.fov = 61.0
    game.add_child(camera)
    var views := [
        ["v09_cafe_compare", Vector3(5.6,5.9,-1.7), Vector3(18.0,3.25,-14.0)],
        ["v09_cafe_street", Vector3(6.0,3.2,-9.0), Vector3(18.0,3.1,-14.0)]
    ]
    for v in views:
        camera.global_position=v[1]
        camera.look_at(v[2], Vector3.UP)
        camera.current=true
        for i in range(25): await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width()<800:
            printerr("V09 CAPTURE FAIL: empty viewport")
            quit(1)
            return
        var path: String = "res://tests/%s.png" % str(v[0])
        if img.save_png(path)!=OK:
            printerr("V09 CAPTURE FAIL: png")
            quit(1)
            return
        print("V09 CAPTURE PASS:",path)
    game.queue_free()
    quit(0)
