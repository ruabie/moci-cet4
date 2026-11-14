extends SceneTree

# Optional CI visual smoke test under Xvfb + software OpenGL.
# This cannot substitute for an actual user's GPU performance benchmark.
func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        printerr("CAPTURE FAIL: main scene does not load")
        quit(1)
        return
    var instance: Node = scene.instantiate()
    root.add_child(instance)
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        printerr("CAPTURE FAIL: viewport image empty")
        quit(1)
        return
    var path := "res://tests/visual_evidence.png"
    var err: Error = image.save_png(path)
    if err != OK:
        printerr("CAPTURE FAIL: cannot write PNG, error ", err)
        quit(1)
        return
    print("CAPTURE PASS: %dx%d PNG" % [image.get_width(), image.get_height()])
    instance.queue_free()
    quit(0)