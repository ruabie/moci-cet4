extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _save_view(label: String, camera: Camera3D, origin: Vector3, target: Vector3) -> bool:
    camera.global_position = origin
    camera.look_at(target, Vector3.UP)
    for i in range(14):
        await process_frame
    var img: Image = root.get_viewport().get_texture().get_image()
    if img == null or img.get_width() < 720:
        printerr("V18 CAPTURE FAIL: viewport missing: " + label)
        return false
    var path: String = ProjectSettings.globalize_path("res://tests/" + label + ".png")
    if img.save_png(path) != OK:
        printerr("V18 CAPTURE FAIL: image missing: " + label)
        return false
    print("V18 CAPTURE PASS: " + label)
    return true

func _capture() -> void:
    ProjectSettings.set_setting("application/config/qa_mode", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    var scene: Node3D = packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    await physics_frame
    var player: CityPlayer = scene.get_node_or_null("Player") as CityPlayer
    var city: CityBuilder = scene.get_node_or_null("AokawaDistrict") as CityBuilder
    if player == null or city == null or not player.animation_verified or city.npc_rigs.size() != 6:
        printerr("V18 CAPTURE FAIL: rigged art missing")
        quit(1)
        return
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if hud != null:
        hud.visible = false
    var camera := Camera3D.new()
    camera.fov = 54.0
    scene.add_child(camera)
    camera.current = true
    player.global_position = Vector3(0, 0.2, -10)
    player.character_visual.rotation.y = 0.0
    if not await _save_view("v18_player_in_city",camera,Vector3(2.75,2.35,-14),Vector3(0,1.12,-10)):
        quit(1)
        return
    if not await _save_view("v18_player_closeup",camera,Vector3(1.05,1.78,-12.65),Vector3(0,1.24,-10)):
        quit(1)
        return
    var preview_root := Node3D.new()
    preview_root.name = "V18ArtLineupQAOnly"
    preview_root.position = Vector3(250,0,0)
    scene.add_child(preview_root)
    var floor := MeshInstance3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(15,.12,7)
    floor.mesh = floor_mesh
    floor.position = Vector3(0,-.08,0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#65717a")
    mat.roughness = .92
    floor.material_override = mat
    preview_root.add_child(floor)
    for i in range(CharacterArtV18.RESIDENT_FILES.size()):
        var res: PackedScene = load(CharacterArtV18.RESIDENT_FILES[i]) as PackedScene
        var figure: Node3D = res.instantiate() as Node3D
        preview_root.add_child(figure)
        figure.rotation.y = PI
        figure.position.x = -5.2 + float(i)*2.0
        if CharacterArtV18.fit_to_height(figure,1.72) < 1.7:
            printerr("V18 CAPTURE FAIL: resident dimensions " + str(i))
            quit(1)
            return
        var preview_rig: Skeleton3D = CharacterArtV18.find_rig(figure)
        if preview_rig != null:
            CharacterArtV18.pose(preview_rig, "LeftUpperArm", -1.13)
            CharacterArtV18.pose(preview_rig, "RightUpperArm", -1.13)
    var preview_light := DirectionalLight3D.new()
    preview_light.rotation_degrees = Vector3(-50,-20,-10)
    preview_light.light_energy = .50
    preview_root.add_child(preview_light)
    if not await _save_view("v18_six_residents",camera,Vector3(250,2.35,-12),Vector3(250,1.05,0)):
        quit(1)
        return
    ProjectSettings.set_setting("application/config/qa_mode", false)
    quit(0)
