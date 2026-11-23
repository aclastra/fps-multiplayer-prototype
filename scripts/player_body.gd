extends Node3D
class_name PlayerBody
## Visual-only soldier: realistic CC0 rigged model from Grab3D.
##
## The model ships only walk/run clips. We derive extra clips from the walk
## animation at runtime (idle, fire, reload, hit, death) by freezing its keys
## and layering a few bone rotations. That keeps every bone anchored to a real
## pose, so AnimationPlayer can crossfade smoothly between all states.

const BODY_SCENE := preload("res://assets/models/realistic/soldier.glb")
const JUMP_SOURCE := preload("res://assets/models/animations/jump_source.glb")
const TEAM_TINTS := [Color(0.72, 0.86, 1.0), Color(1.0, 0.76, 0.68)]
const BODY_Y_OFFSET := -0.9

## Quaternius (DEF-*) bone names mapped to the soldier's Mixamo-style names.
const JUMP_BONE_MAP := {
	"DEF-hips": "Hips",
	"DEF-spine.001": "Spine",
	"DEF-spine.002": "Spine01",
	"DEF-spine.003": "Spine02",
	"DEF-neck": "neck",
	"DEF-head": "Head",
	"DEF-shoulder.L": "LeftShoulder",
	"DEF-upper_arm.L": "LeftArm",
	"DEF-forearm.L": "LeftForeArm",
	"DEF-hand.L": "LeftHand",
	"DEF-shoulder.R": "RightShoulder",
	"DEF-upper_arm.R": "RightArm",
	"DEF-forearm.R": "RightForeArm",
	"DEF-hand.R": "RightHand",
	"DEF-thigh.L": "LeftUpLeg",
	"DEF-shin.L": "LeftLeg",
	"DEF-foot.L": "LeftFoot",
	"DEF-toe.L": "LeftToeBase",
	"DEF-thigh.R": "RightUpLeg",
	"DEF-shin.R": "RightLeg",
	"DEF-foot.R": "RightFoot",
	"DEF-toe.R": "RightToeBase",
}

static var _jump_cache: Dictionary = {}

var _model: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _library: AnimationLibrary
var _weapon_attach: BoneAttachment3D
var _armband_material: StandardMaterial3D

var _playing := ""
var _locomotion := "idle"
var _effect := ""
var _effect_time := 0.0
var _was_grounded := true
var _grounded := true
var _jump_phase := 0
var _target_speed_scale := 1.0
var _dead := false
var _team := 0

func _ready() -> void:
	_model = BODY_SCENE.instantiate()
	_model.name = "RealisticSoldier"
	_model.position.y = BODY_Y_OFFSET
	add_child(_model)

	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _anim == null:
		push_error("PlayerBody: soldier GLB missing Skeleton3D or AnimationPlayer")
		return

	_library = _anim.get_animation_library(&"")
	if _library == null:
		push_error("PlayerBody: no default animation library")
		return

	_attach_weapon_anchor()
	_add_team_accents()
	# The imported clips don't loop by default, so a 1-second walk/run would
	# play once and then freeze while the player keeps moving.
	for clip_name in ["walk", "run"]:
		var clip := _library.get_animation(clip_name)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR
	_build_extra_clips()
	_tint_materials()
	set_team(0)
	_play("idle", 0.0)

func _process(delta: float) -> void:
	# Ease the playback rate so speed changes don't pop.
	_anim.speed_scale = lerpf(
		_anim.speed_scale,
		_target_speed_scale,
		1.0 - exp(-8.0 * delta)
	)

	# Safety net: if a clip ever reaches its end, restart the current state.
	if _effect.is_empty() and not _dead and not _anim.is_playing():
		_anim.play(_locomotion, 0.15)

	if _effect_time <= 0.0:
		return
	_effect_time -= delta
	if _effect_time > 0.0:
		return

	var finished := _effect
	_effect = ""
	if finished == "jump_start" and not _grounded:
		_jump_phase = 2
		_target_speed_scale = 1.0
		_play("jump_loop", 0.1)
	elif finished == "jump_land":
		_jump_phase = 0
		_play(_locomotion, 0.2)
	elif not _dead:
		_play(_locomotion, 0.3)

# --- Model setup -----------------------------------------------------------

func _attach_weapon_anchor() -> void:
	if _skeleton.find_bone("RightHand") < 0:
		return
	_weapon_attach = BoneAttachment3D.new()
	_weapon_attach.bone_name = "RightHand"
	_weapon_attach.name = "WeaponAttach"
	_skeleton.add_child(_weapon_attach)

func _add_team_accents() -> void:
	if _skeleton.find_bone("LeftArm") < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "LeftArm"
	attach.name = "TeamAccentAttach"
	_skeleton.add_child(attach)

	var band := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.11, 0.12)
	band.mesh = box
	_armband_material = StandardMaterial3D.new()
	_armband_material.albedo_color = TEAM_TINTS[_team]
	_armband_material.emission_enabled = true
	_armband_material.emission = TEAM_TINTS[_team] * 0.4
	band.material_override = _armband_material
	band.position = Vector3(0, 0.02, 0)
	attach.add_child(band)

func set_weapon(scene: PackedScene) -> void:
	if _weapon_attach == null:
		return
	for child in _weapon_attach.get_children():
		child.queue_free()
	if scene == null:
		return
	var weapon := scene.instantiate() as Node3D
	if weapon == null:
		return
	# The CC0 models point their muzzle along +Z; rotate to the soldier's -Z.
	weapon.transform = Transform3D(Basis().rotated(Vector3.UP, PI), Vector3(0, -0.02, 0))
	weapon.scale = Vector3.ONE * 0.9
	weapon.name = "HeldWeapon"
	_weapon_attach.add_child(weapon)

func _tint_materials() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mesh := mi.mesh.duplicate(true) as Mesh
		mi.mesh = mesh
		for i in range(mesh.get_surface_count()):
			var source := mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = TEAM_TINTS[clampi(_team, 0, TEAM_TINTS.size() - 1)]
				mesh.surface_set_material(i, copy)

func set_team(team: int) -> void:
	_team = clampi(team, 0, TEAM_TINTS.size() - 1)
	_tint_materials()
	if _armband_material != null:
		_armband_material.albedo_color = TEAM_TINTS[_team]
		_armband_material.emission = TEAM_TINTS[_team] * 0.4

# --- Derived animation clips ----------------------------------------------

func _build_extra_clips() -> void:
	# Each derived clip keeps frame 0 of every walk track, then overrides a few
	# bones. This guarantees a complete pose for clean crossfades.
	_make_pose_clip("idle", 2.0, true)
	_build_jump_clips()
	_make_pose_clip("fire", 0.28, false)
	_make_pose_clip("reload", 1.0, false)
	_make_pose_clip("hit", 0.35, false)
	_make_pose_clip("death", 0.6, false)

	var idle := _library.get_animation(&"idle")
	_add_rotation(idle, "Spine", [[0.0, Vector3.RIGHT, 0.0], [1.0, Vector3.RIGHT, 0.025], [2.0, Vector3.RIGHT, 0.0]])

	var fire := _library.get_animation(&"fire")
	_add_rotation(fire, "RightArm", [[0.0, Vector3.RIGHT, 0.0], [0.08, Vector3.RIGHT, -1.05], [0.18, Vector3.RIGHT, -0.95], [0.28, Vector3.RIGHT, 0.0]])
	_add_rotation(fire, "RightForeArm", [[0.0, Vector3.RIGHT, 0.0], [0.08, Vector3.RIGHT, -0.35], [0.28, Vector3.RIGHT, 0.0]])

	var reload := _library.get_animation(&"reload")
	_add_rotation(reload, "RightArm", [[0.0, Vector3.RIGHT, 0.0], [0.25, Vector3.RIGHT, -0.6], [0.7, Vector3.RIGHT, -0.75], [1.0, Vector3.RIGHT, 0.0]])
	_add_rotation(reload, "RightForeArm", [[0.0, Vector3.RIGHT, 0.0], [0.25, Vector3.RIGHT, -0.7], [0.7, Vector3.RIGHT, -0.5], [1.0, Vector3.RIGHT, 0.0]])

	var hit := _library.get_animation(&"hit")
	_add_rotation(hit, "Spine", [[0.0, Vector3.RIGHT, 0.0], [0.1, Vector3.RIGHT, 0.18], [0.35, Vector3.RIGHT, 0.0]])

	var death := _library.get_animation(&"death")
	_add_rotation(death, "Hips", [[0.0, Vector3.RIGHT, 0.0], [0.25, Vector3.RIGHT, -0.8], [0.6, Vector3.RIGHT, -1.45]])
	_add_rotation(death, "Spine", [[0.0, Vector3.RIGHT, 0.0], [0.35, Vector3.RIGHT, -0.25], [0.6, Vector3.RIGHT, -0.35]])

## Real CC0 jump clips from Quaternius's Universal Animation Library.
## Rotation keys are retargeted from the DEF-* rig onto the soldier's bones;
## position tracks are ignored because the character controller owns height.
func _build_jump_clips() -> void:
	if _jump_cache.is_empty():
		_load_jump_cache()
	# The source clips are much longer than our ~0.5 s physics jump. Compress
	# the WHOLE curve into a short window instead of truncating the first few
	# frames (which looked like a broken half-pose).
	var durations := {"jump_start": 0.22, "jump_loop": 0.45, "jump_land": 0.38}
	for name in ["jump_start", "jump_loop", "jump_land"]:
		var data: Dictionary = _jump_cache.get(name, {})
		if data.is_empty():
			continue
		var source_length := maxf(0.01, float(data.get("length", 1.0)))
		var duration := float(durations[name])
		var time_scale := duration / source_length
		var clip := Animation.new()
		clip.length = duration
		clip.loop_mode = Animation.LOOP_LINEAR if name == "jump_loop" else Animation.LOOP_NONE
		for track_data in data.get("tracks", []):
			var idx := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(idx, NodePath("Armature/Skeleton3D:" + String(track_data["bone"])))
			for key in track_data["keys"]:
				clip.track_insert_key(idx, float(key[0]) * time_scale, key[1])
		if _library.has_animation(name):
			_library.remove_animation(name)
		_library.add_animation(name, clip)

func _load_jump_cache() -> void:
	var packed := JUMP_SOURCE as PackedScene
	if packed == null:
		return
	var source := packed.instantiate()
	var source_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_skeleton == null or source_player == null:
		return
	var pairs := [
		["Jump_Start", "jump_start"],
		["Jump", "jump_loop"],
		["Jump_Land", "jump_land"],
	]
	for pair in pairs:
		var anim := source_player.get_animation(pair[0])
		if anim == null:
			continue
		var data := {"length": anim.length, "tracks": []}
		for i in range(anim.get_track_count()):
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var source_bone := anim.track_get_path(i).get_concatenated_subnames()
			var target_bone := String(JUMP_BONE_MAP.get(source_bone, ""))
			if target_bone.is_empty():
				continue
			var si := source_skeleton.find_bone(source_bone)
			var ti := _skeleton.find_bone(target_bone)
			if si < 0 or ti < 0:
				continue
			# Imported GLB tracks store ABSOLUTE local joint rotations, not
			# deltas. Convert to a delta from the source rest, then apply that
			# delta to the target bone's rest rotation.
			var rest_source := source_skeleton.get_bone_rest(si).basis.get_rotation_quaternion()
			var rest_target := _skeleton.get_bone_rest(ti).basis.get_rotation_quaternion()
			var keys: Array = []
			for k in range(anim.track_get_key_count(i)):
				var q: Quaternion = anim.track_get_key_value(i, k)
				var delta := rest_source.inverse() * q
				var mapped := rest_target * delta
				keys.append([anim.track_get_key_time(i, k), mapped])
			data["tracks"].append({"bone": target_bone, "keys": keys})
		_jump_cache[pair[1]] = data
	source.free()

func _make_pose_clip(name: String, duration: float, loop: bool) -> void:
	var source := _library.get_animation(&"walk")
	if source == null:
		return
	var clip := source.duplicate(true) as Animation
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for i in range(clip.get_track_count()):
		var count := clip.track_get_key_count(i)
		if count <= 1:
			continue
		var first: Variant = clip.track_get_key_value(i, 0)
		for k in range(count - 1, 0, -1):
			clip.track_remove_key(i, k)
		clip.track_set_key_value(i, 0, first)
	if _library.has_animation(name):
		_library.remove_animation(name)
	_library.add_animation(name, clip)

func _add_rotation(clip: Animation, bone: String, keys: Array) -> void:
	for i in range(clip.get_track_count()):
		var path := clip.track_get_path(i)
		if clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		if path.get_concatenated_subnames() != bone:
			continue
		var base: Quaternion = clip.track_get_key_value(i, 0)
		for key in keys:
			var offset := Quaternion(key[1], float(key[2]))
			clip.track_insert_key(i, float(key[0]), base * offset)
		return

# --- State machine ---------------------------------------------------------

func set_state(speed: float, grounded: bool, sprinting: bool, reloading: bool, dead: bool) -> void:
	if dead:
		death()
		return
	if _dead:
		respawn()

	# Three-phase jump: take-off -> in-air loop -> landing.
	if not grounded and _was_grounded and _jump_phase == 0:
		_jump_phase = 1
		_start_effect("jump_start", 0.22)
		_target_speed_scale = 1.0
	if grounded and _jump_phase == 2:
		_jump_phase = 0
		_start_effect("jump_land", 0.38)
	elif grounded and _jump_phase == 1:
		_jump_phase = 0
		_effect = ""
	_was_grounded = grounded
	_grounded = grounded

	if reloading and _effect != "reload" and _jump_phase == 0:
		_start_effect("reload", 1.0)
	if not _effect.is_empty():
		return
	if _jump_phase == 2 and not grounded:
		return

	if not grounded:
		_set_locomotion("walk", clampf(speed / 4.0, 0.9, 1.5))
	elif sprinting or speed > 3.5:
		_set_locomotion("run", clampf(speed / 6.0, 0.85, 1.25))
	elif speed > 0.35:
		_set_locomotion("walk", clampf(speed / 3.0, 0.65, 1.25))
	else:
		_set_locomotion("idle", 1.0)

func fire() -> void:
	if _dead:
		return
	_start_effect("fire", 0.28)

func hit() -> void:
	if _dead:
		return
	_start_effect("hit", 0.35)

func death() -> void:
	if _dead:
		return
	_dead = true
	_effect = "death"
	_effect_time = 0.0
	_play("death", 0.25)

func respawn() -> void:
	_dead = false
	_effect = ""
	_effect_time = 0.0
	_was_grounded = true
	_grounded = true
	_jump_phase = 0
	_play("idle", 0.3)

func _start_effect(name: String, duration: float) -> void:
	if _dead:
		return
	_effect = name
	_effect_time = duration
	_play(name, 0.12)

func _set_locomotion(clip: String, speed_scale: float) -> void:
	_locomotion = clip
	_target_speed_scale = speed_scale
	_play(clip, 0.3)

func _play(clip: String, blend: float) -> void:
	if _anim == null or _playing == clip or not _library.has_animation(clip):
		return
	_playing = clip
	_anim.play(clip, blend)
