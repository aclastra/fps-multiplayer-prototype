extends CharacterBody3D
class_name Player
## One player, present on the server and on every client.
##
## Authority rule used throughout this prototype:
##   * The SERVER is the authority of every Player node (the Godot default).
##   * Clients SEND input with @rpc("any_peer", ...) to peer 1.
##   * The server SENDS state with @rpc("authority", ...) to all clients.
##
## The local client predicts its own movement so controls feel responsive;
## remote players are interpolated toward the latest server snapshot.

# --- Tunables -------------------------------------------------------------
@export var move_speed := 6.0
@export var sprint_speed := 10.0
@export var jump_velocity := 5.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.0025
@export var max_health := 100

var weapons: Array[WeaponData] = []
var weapon_index := 0
var ammo_by_weapon: Array[int] = []

# --- Replicated state -----------------------------------------------------
var peer_id := 1
var display_name := "Player"
var yaw := 0.0
var pitch := 0.0
var health := 100
var ammo := 30
var dead := false
var team := 0
var kills := 0
var deaths := 0
var grenades := 2

# --- Local / server-only state --------------------------------------------
var _is_local := false
var _show_own_body := false
var _grab_attempts := 0
var _move := Vector2.ZERO
var _sprint := false
var _fire := false
var _jump_held := false
var _prev_jump := false
var _reload_requested := false
var _fire_cooldown := 0.0
var _reload_timer := 0.0

var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_speed := 0.0
var _net_grounded := true
var _net_sprinting := false
var _net_reloading := false

@onready var _collision: CollisionShape3D = $Collision
@onready var _body_visual: PlayerBody = $BodyVisual
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _weapon_view: WeaponView = $CameraRig/Camera3D/WeaponView
@onready var _flash: MeshInstance3D = $CameraRig/Camera3D/MuzzleFlash
@onready var _label: Label3D = $NameLabel

func _ready() -> void:
	add_to_group("players")
	_show_own_body = OS.get_cmdline_user_args().has("--show-body")
	_is_local = peer_id == multiplayer.get_unique_id()
	_net_pos = global_position
	_net_yaw = yaw
	_net_pitch = pitch
	weapons = Weapons.all()
	for weapon in weapons:
		ammo_by_weapon.append(weapon.magazine)
	ammo = current_weapon().magazine
	health = max_health
	display_name = "Player %d" % peer_id
	_label.text = display_name
	_body_visual.set_team(team)
	_update_weapon_visual()

	if _is_local:
		_camera.current = true
		if _show_own_body:
			# Pull the camera back so you can inspect your own armored soldier.
			_camera_rig.position = Vector3(0, 1.15, 2.8)
			pitch = -0.15
			_camera_rig.rotation.x = pitch
		# Pointer capture happens on the first click: an automatic grab at
		# startup fails on some X11 window managers ("NO GRAB").
	else:
		_camera.current = false
	_apply_visuals()

# --- Weapons ---------------------------------------------------------------

func current_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[clampi(weapon_index, 0, weapons.size() - 1)]

func _update_weapon_visual() -> void:
	var weapon := current_weapon()
	if is_instance_valid(_weapon_view):
		_weapon_view.set_weapon(weapon)
	if is_instance_valid(_body_visual) and weapon != null:
		_body_visual.set_weapon(weapon.scene)

func _request_grenade() -> void:
	if dead or grenades <= 0:
		return
	if multiplayer.is_server():
		_throw_grenade()
	else:
		request_grenade.rpc_id(1)

@rpc("any_peer", "reliable")
func request_grenade() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_throw_grenade()

func _throw_grenade() -> void:
	if dead or grenades <= 0:
		return
	grenades -= 1
	var dir := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
	var pos := global_position + Vector3.UP * 1.5 + dir * 0.6
	var vel := dir * 13.0 + Vector3.UP * 4.0
	var game := get_tree().get_first_node_in_group("game_manager")
	if game != null and game.has_method("throw_grenade"):
		game.call("throw_grenade", peer_id, pos, vel)

func _request_weapon(index: int) -> void:
	if dead or index < 0 or index >= weapons.size() or index == weapon_index:
		return
	if multiplayer.is_server():
		_equip_weapon(index)
	else:
		request_weapon.rpc_id(1, index)

@rpc("any_peer", "reliable")
func request_weapon(index: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_equip_weapon(index)

func _equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == weapon_index:
		return
	weapon_index = index
	ammo = ammo_by_weapon[index]
	_fire_cooldown = 0.25
	_reload_timer = 0.0
	_update_weapon_visual()

# --- Input ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		_camera_rig.rotation.x = pitch
		rotation.y = yaw
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_grab_attempts = 0
			_capture_mouse()

func _capture_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if _grab_attempts >= 20:
		return
	_grab_attempts += 1
	# Grabbing the pointer fails if the window isn't focused yet (common when
	# two clients launch together). Retry briefly; a click also retries.
	if DisplayServer.window_is_focused():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		get_tree().create_timer(0.25).timeout.connect(_capture_mouse)

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if _is_local:
		_move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		_sprint = Input.is_action_pressed("sprint")
		_jump_held = Input.is_action_pressed("jump")
		_fire = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if Input.is_action_just_pressed("reload"):
			_reload_requested = true
		if Input.is_action_just_pressed("weapon_1"):
			_request_weapon(0)
		elif Input.is_action_just_pressed("weapon_2"):
			_request_weapon(1)
		elif Input.is_action_just_pressed("weapon_3"):
			_request_weapon(2)
		if Input.is_action_just_pressed("grenade"):
			_request_grenade()
		if not multiplayer.is_server():
			# The host already has these values locally; RPCs to yourself are
			# rejected by "any_peer" mode.
			receive_input.rpc_id(1, _move, yaw, pitch, _sprint, _fire, _jump_held, _reload_requested)
		_apply_movement(_move, _sprint, _jump_held, delta)
		# The server owns ammo/reload; clear the one-shot request once sent.
		_reload_requested = false
	elif multiplayer.is_server():
		# Remote players on the server move using the last input they sent.
		_apply_movement(_move, _sprint, _jump_held, delta)
	else:
		# A remote player on a client: smooth toward the server's state.
		_interpolate(delta)

	if multiplayer.is_server():
		_server_tick(delta)

	if is_instance_valid(_body_visual):
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		var grounded := is_on_floor()
		var sprinting := _sprint
		var reloading := _reload_timer > 0.0
		if not _is_local and not multiplayer.is_server():
			# Remote clients don't simulate this body, so use the server's state.
			planar_speed = _net_speed
			grounded = _net_grounded
			sprinting = _net_sprinting
			reloading = _net_reloading
		_body_visual.set_state(planar_speed, grounded, sprinting, reloading, dead)

func _apply_movement(move: Vector2, sprint: bool, jump_held: bool, delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return

	rotation.y = yaw

	# Basis vectors already include yaw; +Z is "back", so move.y maps to +Z.
	var direction := transform.basis.x * move.x + transform.basis.z * move.y
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	var speed := sprint_speed if sprint else move_speed

	var jump_edge := jump_held and not _prev_jump
	_prev_jump = jump_held

	if is_on_floor():
		velocity.x = horizontal.x * speed
		velocity.z = horizontal.z * speed
		if jump_edge:
			velocity.y = jump_velocity
	else:
		velocity.x = lerpf(velocity.x, horizontal.x * speed, 0.08)
		velocity.z = lerpf(velocity.z, horizontal.z * speed, 0.08)

	velocity.y -= gravity * delta
	move_and_slide()

func _interpolate(delta: float) -> void:
	var t := 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(_net_pos, t)
	yaw = lerp_angle(yaw, _net_yaw, t)
	pitch = lerpf(pitch, _net_pitch, t)
	rotation.y = yaw
	_camera_rig.rotation.x = pitch

# --- Server-authoritative combat ------------------------------------------

func _server_tick(delta: float) -> void:
	var weapon := current_weapon()
	if weapon == null:
		return
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			ammo = weapon.magazine
			ammo_by_weapon[weapon_index] = ammo
			_reload_timer = 0.0
	elif _reload_requested and ammo < weapon.magazine and not dead:
		_reload_timer = weapon.reload_time
		show_reload.rpc()
	_reload_requested = false

	if _fire and not dead and ammo > 0 and _fire_cooldown <= 0.0 and _reload_timer <= 0.0:
		_server_shoot()

func _server_shoot() -> void:
	var weapon := current_weapon()
	if weapon == null:
		return
	_fire_cooldown = weapon.fire_interval
	ammo -= 1
	ammo_by_weapon[weapon_index] = ammo
	show_shot.rpc() # Everyone sees the muzzle flash, including the shooter.

	# The body origin is the capsule centre; the camera sits 0.6 above it.
	var origin := global_position + Vector3.UP * 0.6
	var base_dir := Vector3(
		-sin(yaw) * cos(pitch),
		sin(pitch),
		-cos(yaw) * cos(pitch)
	).normalized()
	var space := get_world_3d().direct_space_state

	var right := base_dir.cross(Vector3.UP).normalized()
	var up := right.cross(base_dir).normalized()
	for pellet in range(maxi(1, weapon.pellets)):
		var spread := deg_to_rad(weapon.spread_deg)
		var dir := (base_dir + right * randf_range(-spread, spread) + up * randf_range(-spread, spread)).normalized()
		var end := origin + dir * weapon.range
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			end = hit.get("position", end)
		show_tracer.rpc(origin, end)
		if hit.is_empty():
			continue
		var target: Object = hit.get("collider")
		if target is Player and target != self:
			(target as Player).take_damage(weapon.damage, peer_id)
			if peer_id == multiplayer.get_unique_id():
				show_hit(weapon.damage, (target as Player).global_position)
			else:
				show_hit.rpc_id(peer_id, weapon.damage, (target as Player).global_position)

func take_damage(amount: int, attacker_id: int) -> void:
	if not multiplayer.is_server() or dead:
		return
	health = maxi(0, health - amount)
	if is_instance_valid(_body_visual):
		_body_visual.hit()
	var game := get_tree().get_first_node_in_group("game_manager")
	var attacker_pos := global_position
	if game != null and game.has_method("get_player"):
		var attacker: Player = game.call("get_player", attacker_id) as Player
		if attacker != null:
			attacker_pos = attacker.global_position
	if peer_id == multiplayer.get_unique_id():
		show_damage(attacker_pos)
	else:
		show_damage.rpc_id(peer_id, attacker_pos)
	if health == 0:
		if peer_id == multiplayer.get_unique_id():
			Sound.play("death", -2.0)
			_camera_rig.rotation.z = -0.45
		dead = true
		_collision.set_deferred("disabled", true)
		if game != null and game.has_method("report_kill"):
			game.call("report_kill", attacker_id, peer_id)
		get_tree().create_timer(3.0).timeout.connect(_respawn)

func _respawn() -> void:
	if not multiplayer.is_server() or not is_inside_tree():
		return
	var game := get_tree().get_first_node_in_group("game_manager")
	if game != null and game.has_method("spawn_position_for"):
		global_position = game.spawn_position_for(peer_id)
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	health = max_health
	grenades = 2
	_refill_ammo()
	dead = false
	_collision.set_deferred("disabled", false)
	if is_instance_valid(_body_visual):
		_body_visual.respawn()

func refill_ammo() -> void:
	if multiplayer.is_server():
		_refill_ammo()

func _refill_ammo() -> void:
	ammo_by_weapon.clear()
	for weapon in weapons:
		ammo_by_weapon.append(weapon.magazine)
	var weapon := current_weapon()
	ammo = weapon.magazine if weapon != null else 0

func reset_for_match() -> void:
	if not multiplayer.is_server():
		return
	kills = 0
	deaths = 0
	var game := get_tree().get_first_node_in_group("game_manager")
	if game != null and game.has_method("spawn_position_for"):
		global_position = game.spawn_position_for(peer_id)
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	health = max_health
	grenades = 2
	_refill_ammo()
	dead = false
	_collision.set_deferred("disabled", false)
	if is_instance_valid(_body_visual):
		_body_visual.respawn()

# --- Networking -----------------------------------------------------------

## Client -> server input. Sent every physics tick, unreliable on purpose:
## a late input is useless, the next one arrives 16 ms later.
@rpc("any_peer", "unreliable")
func receive_input(
	move: Vector2,
	new_yaw: float,
	new_pitch: float,
	sprint: bool,
	fire: bool,
	jump: bool,
	reload: bool
) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_move = move
	yaw = new_yaw
	pitch = clampf(new_pitch, -1.45, 1.45)
	_sprint = sprint
	_fire = fire
	_jump_held = jump
	if reload:
		_reload_requested = true

@rpc("any_peer", "reliable")
func set_display_name(value: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	display_name = value.strip_edges().substr(0, 16)
	if display_name.is_empty():
		display_name = "Player %d" % peer_id
	_label.text = display_name

@rpc("any_peer", "reliable")
func set_team(value: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	team = clampi(value, 0, 1)
	if is_instance_valid(_body_visual):
		_body_visual.set_team(team)

## Server -> clients state, broadcast at a fixed rate by main.gd.
@rpc("authority", "unreliable")
func _send_state(
	pos: Vector3,
	new_yaw: float,
	new_pitch: float,
	new_health: int,
	new_ammo: int,
	new_dead: bool,
	new_speed: float,
	new_grounded: bool,
	new_sprinting: bool,
	new_reloading: bool,
	new_kills: int,
	new_deaths: int,
	new_weapon_index: int,
	new_grenades: int
) -> void:
	if multiplayer.is_server():
		return
	_net_pos = pos
	_net_yaw = new_yaw
	_net_pitch = new_pitch
	health = new_health
	ammo = new_ammo
	dead = new_dead
	_net_speed = new_speed
	_net_grounded = new_grounded
	_net_sprinting = new_sprinting
	_net_reloading = new_reloading
	kills = new_kills
	deaths = new_deaths
	grenades = new_grenades
	if new_weapon_index != weapon_index:
		weapon_index = new_weapon_index
		ammo = ammo_by_weapon[clampi(weapon_index, 0, ammo_by_weapon.size() - 1)] if not ammo_by_weapon.is_empty() else ammo
		_update_weapon_visual()
	_apply_visuals()

@rpc("authority", "unreliable")
func show_shot() -> void:
	if dead:
		return
	if is_instance_valid(_body_visual):
		_body_visual.fire()
	_flash.visible = true
	Sound.play("fire", -4.0)
	get_tree().create_timer(0.06).timeout.connect(_hide_flash)

@rpc("authority", "reliable")
func show_hit(damage: int, victim_pos: Vector3) -> void:
	if not _is_local:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("add_hitmarker"):
		hud.call("add_hitmarker", damage)
	Sound.play("hit", -3.0)

@rpc("authority", "unreliable")
func show_damage(attacker_pos: Vector3) -> void:
	if not _is_local:
		return
	var local_dir := global_transform.basis.inverse() * (attacker_pos - global_position)
	var angle := atan2(local_dir.x, -local_dir.z)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_damage_direction"):
		hud.call("show_damage_direction", angle)
	Sound.play("hurt", -2.0)

@rpc("authority", "unreliable")
func show_tracer(origin: Vector3, end: Vector3) -> void:
	var length := origin.distance_to(end)
	if length < 0.01:
		return
	var tracer := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.006
	cylinder.bottom_radius = 0.006
	cylinder.height = length
	tracer.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.4)
	material.emission_enabled = true
	material.emission = material.albedo_color
	tracer.material_override = material
	add_child(tracer)
	tracer.global_position = (origin + end) * 0.5
	tracer.look_at(end, Vector3.UP)
	tracer.rotate_x(PI * 0.5)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free()
	)

@rpc("authority", "reliable")
func show_reload() -> void:
	Sound.play("reload", -5.0)

@rpc("authority", "reliable")
func show_pickup() -> void:
	if _is_local:
		Sound.play("pickup", -4.0)

func _hide_flash() -> void:
	if is_inside_tree():
		_flash.visible = false

func broadcast_state() -> void:
	if not multiplayer.is_server():
		return
	_send_state.rpc(
		global_position, yaw, pitch, health, ammo, dead,
		Vector2(velocity.x, velocity.z).length(), is_on_floor(), _sprint, _reload_timer > 0.0,
		kills, deaths, weapon_index, grenades
	)

func apply_snapshot(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	yaw = float(data.get("yaw", yaw))
	pitch = float(data.get("pitch", pitch))
	health = int(data.get("hp", health))
	ammo = int(data.get("ammo", ammo))
	dead = bool(data.get("dead", dead))
	team = int(data.get("team", team))
	kills = int(data.get("kills", kills))
	deaths = int(data.get("deaths", deaths))
	weapon_index = int(data.get("weapon", weapon_index))
	grenades = int(data.get("grenades", grenades))
	display_name = String(data.get("name", display_name))
	if is_instance_valid(_body_visual):
		_body_visual.set_team(team)
	_update_weapon_visual()
	_net_pos = global_position
	_net_yaw = yaw
	_net_pitch = pitch
	_label.text = display_name
	_apply_visuals()

func _apply_visuals() -> void:
	# Normally local players see only the viewmodel; --show-body allows inspection.
	_body_visual.visible = not dead and (_show_own_body or not _is_local)
	_label.visible = not _is_local and not dead
	rotation.y = yaw
	_camera_rig.rotation.x = pitch
	if not dead:
		_camera_rig.rotation.z = 0.0
