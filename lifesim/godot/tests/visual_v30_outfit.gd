extends SceneTree

# Real CC0 65-bone modular clothing test, independently animated with the same
# verified UAL1 original source time. NOT installed in production CityPlayer.
const SOURCE:String="res://art/animations/v21/ual1_inplace.glb"
const BASE:String="res://art/characters/v26/base_character_compatible.glb"
const CLOTHING:Array[String]=[
    "res://art/characters/v30/Male_Peasant_Body.gltf",
    "res://art/characters/v30/Male_Peasant_Legs.gltf",
    "res://art/characters/v30/Male_Peasant_Feet.gltf"
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message:String) -> void:
    printerr("V30 SKINNED OUTFIT FAIL: "+message)
    quit(1)

func _capture(name:String) -> bool:
    await process_frame
    RenderingServer.force_draw(false)
    var picture:Image=root.get_viewport().get_texture().get_image()
    if picture==null or picture.get_width()<720:
        return false
    return picture.save_png(ProjectSettings.globalize_path(
        "res://tests/v30_"+name+".png"))==OK

func _run() -> void:
    var source_p:PackedScene=load(SOURCE) as PackedScene
    var base_p:PackedScene=load(BASE) as PackedScene
    if source_p==null or base_p==null:
        _fail("missing pinned UAL source or 65-bone base")
        return
    var world:=Node3D.new()
    root.add_child(world)
    var origin:Node3D=source_p.instantiate() as Node3D
    var base:Node3D=base_p.instantiate() as Node3D
    if origin==null or base==null:
        _fail("invalid original/base scene")
        return
    origin.name="SourceUALForMotion"
    origin.hide()
    world.add_child(origin)
    base.name="CC0CompatibleBase"
    world.add_child(base)
    var models:Array[Node3D]=[]
    for p in CLOTHING:
        var scene:PackedScene=load(p) as PackedScene
        if scene==null:
            _fail("missing pinned CC0 clothing glTF: "+p)
            return
        var part:Node3D=scene.instantiate() as Node3D
        if part==null:
            _fail("invalid imported skinned outfit: "+p)
            return
        part.name="Garment_"+str(models.size())
        world.add_child(part)
        models.append(part)
    var light:=DirectionalLight3D.new()
    light.light_energy=2.1
    light.rotation_degrees=Vector3(-54,22,-8)
    world.add_child(light)
    var e:=Environment.new()
    e.background_mode=Environment.BG_COLOR
    e.background_color=Color(0.14,0.16,0.19)
    e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color=Color(0.72,0.74,0.78)
    e.ambient_light_energy=1.0
    var environment:=WorldEnvironment.new()
    environment.environment=e
    world.add_child(environment)
    var floor:=MeshInstance3D.new()
    var mesh:=PlaneMesh.new()
    mesh.size=Vector2(7,7)
    floor.mesh=mesh
    floor.position.y=-.03
    world.add_child(floor)
    var cam:=Camera3D.new()
    cam.fov=52
    cam.current=true
    world.add_child(cam)
    cam.global_position=Vector3(1.15,1.65,-3.05)
    cam.look_at(Vector3(0,1.06,0))
    await process_frame

    var base_rig:Skeleton3D=AnimationRetargetV22._find_skeleton(base)
    if base_rig==null or base_rig.get_bone_count()!=65:
        _fail("base mesh no longer 65-bone compatible")
        return
    var drivers:Array[AnimationPlayer]=[]
    var all_models:Array[Node3D]=[base]
    all_models.append_array(models)
    var compatibility:Array[Dictionary]=[]
    for model in all_models:
        var rig:Skeleton3D=AnimationRetargetV22._find_skeleton(model)
        if rig==null or rig.get_bone_count()!=65:
            _fail(model.name+" does not import as 65-bone skinned human")
            return
        var result:Dictionary=CompatibleAnimV26.install(origin,model)
        if not bool(result.get("ok",false)):
            _fail(model.name+" did not retain full-body UAL: "+JSON.stringify(result))
            return
        drivers.append(result["player"] as AnimationPlayer)
        compatibility.append({
            "part":model.name,
            "shared":result["shared_bones"],
            "matching_parent":result["parent_matches"],
            "clip_tracks":result["track_counts"]
        })
    var pairs:Array[Dictionary]=[]
    for motion in ["idle","walk","jog"]:
        var phases:Array[float]=[0.18]
        if motion!="idle":
            phases=[0.19,0.59]
        for i in range(phases.size()):
            var fraction:float=phases[i]
            for driver in drivers:
                var key:String="v26/"+motion
                var clip:Animation=driver.get_animation(key)
                if clip==null:
                    _fail("actual imported animation missing "+key)
                    return
                driver.play(key)
                driver.seek(minf(clip.length*fraction,clip.length-.01),true)
                driver.stop(true)
            for p in models:
                p.hide()
            var bare:String=motion+"_%02d_base" % i
            if not await _capture(bare):
                _fail("failed real Godot baseline "+bare)
                return
            for p in models:
                p.show()
            var dressed:String=motion+"_%02d_outfit" % i
            if not await _capture(dressed):
                _fail("failed real Godot skinned clothing "+dressed)
                return
            pairs.append({
                "motion":motion,"fraction":fraction,
                "base_png":"v30_"+bare+".png",
                "clothing_png":"v30_"+dressed+".png",
                "same_pose_camera_and_animation":true
            })
    var report:Dictionary={
        "ok":true,"pairs":pairs,
        "source":"Actual Quaternius CC0 peasant shirt/pants/shoes on 65 bone compatible base",
        "actual_screenshot_count":pairs.size()*2,
        "imported_skinned_model_count":models.size(),
        "skeleton_validation":compatibility,
        "not_proven":["proper civilian apparel","garment penetration","cloth deformation quality",
                     "skinned shoe sole ground contact","actual input-driven locomotion",
                     "Windows GPU / Chrome browser performance"]
    }
    var f:FileAccess=FileAccess.open(ProjectSettings.globalize_path(
        "res://tests/v30_outfit_render.json"),FileAccess.WRITE)
    if f==null:
        _fail("failed to save evidence")
        return
    f.store_string(JSON.stringify(report,"\t")+"\n")
    f.close()
    print("V30 SKINNED OUTFIT RENDER PASS: "+JSON.stringify({
        "pairs":pairs.size(),"renders":pairs.size()*2,
        "skinned_parts":models.size(),"part_joint_count":65
    }))
    quit(0)
