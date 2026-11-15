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
    var player: CityPlayer = instance.get_node_or_null("Player") as CityPlayer
    var before: Vector3 = player.global_position
    Input.action_press("move_forward")
    for step in range(18):
        await process_frame
    Input.action_release("move_forward")
    await RenderingServer.frame_post_draw
    if player.global_position.distance_to(before) < 0.08:
        printerr("CAPTURE FAIL: no movement during visual capture")
        quit(1)
        return
    var walking_image: Image = root.get_texture().get_image()
    if walking_image.save_png("res://tests/visual_walk_evidence.png") != OK:
        printerr("CAPTURE FAIL: cannot save walking evidence")
        quit(1)
        return
    # V0.7 independent architectural inspection camera. The existing player
    # camera only shows half a facade, hiding broken joints and door apertures.
    var facade_cam := Camera3D.new()
    facade_cam.name = "V07FacadeInspectionCamera"
    facade_cam.fov = 61.0
    instance.add_child(facade_cam)
    facade_cam.global_position = Vector3(-4.5, 5.25, -24.0)
    facade_cam.look_at(Vector3(-17.2, 3.1, -14.0), Vector3.UP)
    facade_cam.current = true
    for frame in range(18):
        await process_frame
    await RenderingServer.frame_post_draw
    var facade_image: Image = root.get_texture().get_image()
    if facade_image == null or facade_image.is_empty():
        printerr("CAPTURE FAIL: V0.7 facade inspection blank")
        quit(1)
        return
    if facade_image.save_png("res://tests/v07_facade_inspection.png") != OK:
        printerr("CAPTURE FAIL: V0.7 facade inspection not saved")
        quit(1)
        return
    print("CAPTURE PASS: %dx%d PNG + walk + facade inspection" % [image.get_width(), image.get_height()])
    instance.queue_free()
    quit(0)