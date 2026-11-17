extends SceneTree

# Three-way, same-camera, actual Godot 4.7 visual evidence.
# (1) native UAL Mannequin + original clip, (2) matching 65-bone CC0 base
# + full-body rotations and animated pelvis translation, (3) legacy 49-bone
# civilian + prior V0.22 rotation-only retarget. No production player changes.
const PHASES: Array[float]=[0.19,0.59]
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("V26 VISUAL COMPARE FAIL: "+message)
    quit(1)

func _ankle_y(rig: Skeleton3D) -> float:
    var low:float=INF
    for name in ["foot_l","foot_r","Foot.L","Foot.R"]:
        var idx:int=rig.find_bone(name)
        if idx>=0:
            low=minf(low,(rig.global_transform*rig.get_bone_global_pose(idx).origin).y)
    return low

func _align_once(character: Node3D, rig: Skeleton3D) -> bool:
    var y:float=_ankle_y(rig)
    if not is_finite(y):
        return false
    # Scene-wide camera/scale fixed after foot-ground pre-alignment. This is
    # not per-frame compensation and cannot fake planted feet.
    character.position.y+=0.07-y
    return true

func _capture(name: String) -> bool:
    # Three offscreen imported models with no main scene can fail to emit a
    # frame_post_draw signal in the isolated Godot CI test. Force the actual
    # rendering server to draw the current pose, never fake or reuse images.
    await process_frame
    RenderingServer.force_draw(false)
    var im:Image=root.get_viewport().get_texture().get_image()
    if im==null or im.get_width()<720 or im.get_height()<400:
        return false
    return im.save_png(ProjectSettings.globalize_path(
        "res://tests/v26_"+name+".png"))==OK

func _run() -> void:
    var ual_scene:PackedScene=load("res://art/animations/v21/ual1_inplace.glb") as PackedScene
    var base_scene:PackedScene=load("res://art/characters/v26/base_character_compatible.glb") as PackedScene
    var old_scene:PackedScene=load("res://art/characters/v18/player_casual.glb") as PackedScene
    if ual_scene==null or base_scene==null or old_scene==null:
        _fail("exact pinned GLB scene import missing")
        return
    var world:=Node3D.new()
    root.add_child(world)
    var source:Node3D=ual_scene.instantiate() as Node3D
    var base:Node3D=base_scene.instantiate() as Node3D
    var old:Node3D=old_scene.instantiate() as Node3D
    if source==null or base==null or old==null:
        _fail("invalid imported CC0 root node type")
        return
    source.name="V26OriginalUALMannequin"
    base.name="V26CompatibleBase65"
    old.name="V26LegacyCivilian49"
    world.add_child(source)
    world.add_child(base)
    world.add_child(old)
    source.position.x=-2.3
    base.position.x=0.0
    old.position.x=2.3
    source.rotation.y=PI
    base.rotation.y=PI
    old.rotation.y=PI
    var camera:=Camera3D.new()
    world.add_child(camera)
    camera.current=true
    camera.fov=51.0
    var light:=DirectionalLight3D.new()
    light.light_energy=2.2
    light.rotation_degrees=Vector3(-53,28,-9)
    world.add_child(light)
    var room:=MeshInstance3D.new()
    room.name="V26NeutralReferenceFloor"
    var plane:=PlaneMesh.new()
    plane.size=Vector2(10,6)
    room.mesh=plane
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color(0.42,0.44,0.46)
    mat.roughness=0.94
    room.material_override=mat
    room.position.y=-0.045
    world.add_child(room)
    var ambient:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color(0.14,0.17,0.2)
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color(0.68,0.71,0.76)
    env.ambient_light_energy=1.0
    ambient.environment=env
    world.add_child(ambient)
    await process_frame
    var src_rig:Skeleton3D=AnimationRetargetV22._find_skeleton(source)
    var base_rig:Skeleton3D=AnimationRetargetV22._find_skeleton(base)
    var old_rig:Skeleton3D=AnimationRetargetV22._find_skeleton(old)
    var src_player:AnimationPlayer=AnimationRetargetV22._find_animation_player(source)
    if src_rig==null or base_rig==null or old_rig==null or src_player==null:
        _fail("actual CC0 model rigs or animation player missing")
        return
    if src_rig.get_bone_count()<60 or base_rig.get_bone_count()<60 or old_rig.get_bone_count()<40:
        _fail("unexpected imported bone count")
        return
    for row in [[source,src_rig],[base,base_rig],[old,old_rig]]:
        if not _align_once(row[0] as Node3D,row[1] as Skeleton3D):
            _fail("cannot set static ground reference")
            return
    var compatible:Dictionary=CompatibleAnimV26.install(source,base)
    var legacy:Dictionary=AnimationRetargetV22.install(source,old_rig,old)
    if not bool(compatible.get("ok",false)):
        _fail("native-compatible 65-bone clip import failed: "+JSON.stringify(compatible))
        return
    if not bool(legacy.get("ok",false)):
        _fail("previous V0.22 retarget unexpectedly failed: "+JSON.stringify(legacy))
        return
    var compat_player:AnimationPlayer=compatible["player"] as AnimationPlayer
    var legacy_player:AnimationPlayer=legacy["player"] as AnimationPlayer
    var frames:Array[String]=[]
    var observations:Dictionary={}
    for motion in ["idle","walk","jog"]:
        var legacy_motion:String="run" if motion=="jog" else motion
        var source_name:String=str(compatible["clips"][motion])
        var src_clip:Animation=src_player.get_animation(source_name)
        var mapped_clip:Animation=compat_player.get_animation("v26/"+motion)
        var old_clip:Animation=legacy_player.get_animation("v22/"+legacy_motion)
        if src_clip==null or mapped_clip==null or old_clip==null:
            _fail("one of three real clip variants is absent for "+motion)
            return
        # Godot conditional array literals may be untyped at runtime. Explicit
        # typed assignment preserves Array[float] for both cases.
        var phases:Array[float]=[0.18]
        if motion!="idle":
            phases=PHASES
        var series:Array[Dictionary]=[]
        for t in range(phases.size()):
            var fraction:float=phases[t]
            src_player.play(source_name)
            src_player.seek(minf(src_clip.length*fraction,src_clip.length-.01),true)
            src_player.stop(true)
            compat_player.play("v26/"+motion)
            compat_player.seek(minf(mapped_clip.length*fraction,mapped_clip.length-.01),true)
            compat_player.stop(true)
            legacy_player.play("v22/"+legacy_motion)
            legacy_player.seek(minf(old_clip.length*fraction,old_clip.length-.01),true)
            legacy_player.stop(true)
            await process_frame
            var sample:Dictionary={
                "phase":fraction,
                "native_source_left_ankle_world_y":snappedf(_ankle_y(src_rig),.003),
                "compatible_left_ankle_world_y":snappedf(_ankle_y(base_rig),.003),
                "legacy_left_ankle_world_y":snappedf(_ankle_y(old_rig),.003),
                "frames":{}
            }
            for row in [
                ["native",source],
                ["compatible",base],
                ["legacy",old]
            ]:
                var role:String=str(row[0])
                var actor:Node3D=row[1] as Node3D
                # Strict one-avatar-at-a-time photography: avoid letting the
                # two other real character models contaminate each screenshot.
                source.hide()
                base.hide()
                old.hide()
                actor.show()
                camera.global_position=actor.global_position+Vector3(1.24,1.64,-3.0)
                camera.look_at(actor.global_position+Vector3.UP*1.04)
                await process_frame
                var filename:String="%s_%s_%02d" % [motion,role,t]
                if not await _capture(filename):
                    _fail("failed actual Godot OpenGL3 camera capture "+filename)
                    return
                sample["frames"][role]="v26_"+filename+".png"
                frames.append("v26_"+filename+".png")
            # Reenable all actors for the next phase; only the single-subject
            # photo is isolated, animation source and gameplay remain intact.
            source.show()
            base.show()
            old.show()
            series.append(sample)
        observations[motion]=series
    var report:Dictionary={
        "ok":true,"project":"LifeSim Godot 4.7.2 source-vs-compatible-vs-legacy full-body art trial",
        "source_skin_joint_count":src_rig.get_bone_count(),
        "compatible_skin_joint_count":base_rig.get_bone_count(),
        "legacy_skin_joint_count":old_rig.get_bone_count(),
        "compatible_audit":compatible,
        "legacy_shared_bones":legacy["shared_bones"],
        "total_raw_godot_frames":frames.size(),
        "single_actor_visible_per_capture":true,
        "source_clip_phases":observations,
        "frames":frames,
        "evidence_scope":"Actual rendered imported CC0 source Mannequin, 65-bone compatible BaseCharacter, and 49-bone legacy civilian. Fixed local camera per actor.",
        "limits":["No input-driven live walk / sprint or transitions",
                  "Original base character is a rig trial, NOT an approved civilian art style",
                  "Shoe toe mesh/ground contact unmeasured",
                  "No Windows RTX3060 or Chrome/WebGL browser evidence"]
    }
    # Avoid serializing the player Object held in CompatibleAnimV26's dict.
    report["compatible_audit"]={
        "shared_bones":compatible["shared_bones"],
        "matching_parent_bones":compatible["parent_matches"],
        "track_counts":compatible["track_counts"],
        "source_clips":compatible["clips"]
    }
    var file:FileAccess=FileAccess.open(
        ProjectSettings.globalize_path("res://tests/v26_visual_metrics.json"),
        FileAccess.WRITE)
    if file==null:
        _fail("cannot save real art comparison metrics")
        return
    file.store_string(JSON.stringify(report,"\t")+"\n")
    file.close()
    print("V26 THREE RIG RENDER PASS: "+JSON.stringify({
        "native_bones":src_rig.get_bone_count(),
        "compatible_bones":base_rig.get_bone_count(),
        "legacy_bones":old_rig.get_bone_count(),
        "raw_godot_screenshots":frames.size(),
        "compatible_tracks":compatible["track_counts"],
        "source_clips":compatible["clips"]
    }))
    quit(0)
