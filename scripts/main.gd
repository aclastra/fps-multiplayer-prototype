extends Node3D
## Bootstrap + authoritative session manager.
##
## Run modes:
##   godot --path .                      -> host/join menu
##   godot --path . -- --server          -> dedicated headless-friendly server
##   godot --path . -- --join 127.0.0.1  -> join directly

const PORT := 7777
const MAX_PLAYERS := 8
const STATE_HZ := 30.0

const _player_scene := preload("res://scenes/player.tscn")
const _pickup_script := preload("res://scripts/pickup.gd")
const _grenade_script := preload("res://scripts/grenade.gd")

@onready var _arena: Node3D = $Arena
@onready var _players_root: Node3D = $Players
@onready var _pickups_root: Node3D = $Pickups
@onready var _grenades_root: Node3D = $Grenades
@onready var _hud: CanvasLayer = $HUD
@onready var _menu: CanvasLayer = $Menu
@onready var _match: Node = $Match

var _players := {}          # peer id -> Player
var _spawn_index := {}      # peer id -> spawn point index
var _spawn_points: Array[Vector3] = []
var _next_spawn := 0
var _next_grenade_id := 1
var _grenades: Dictionary = {}
var _grenade_visuals: Dictionary = {}
var _state_accum := 0.0
var _dedicated := false
var my_name := "Player"
var my_team := 0
var my_weapon := 0
var my_perk := 0

func _ready() -> void:
	add_to_group("game_manager")
	_spawn_points = (_arena as Node).call("spawn_points")
	_spawn_pickups()
	_setup_network_signals()

	var args := OS.get_cmdline_user_args()
	if args.has("--server"):
		_dedicated = true
		host()
	elif args.has("--host"):
		host()
	elif args.has("--join"):
		var i := args.find("--join")
		var ip := "127.0.0.1"
		if i + 1 < args.size():
			ip = args[i + 1]
		join(ip)
	else:
		_show_menu()

func _setup_network_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _spawn_pickups() -> void:
	var placements := [
		[0, Vector3(0, 0, 0)],
		[1, Vector3(8, 0, -2)],
		[0, Vector3(-8, 0, 2)],
		[1, Vector3(-2, 0, 10)],
	]
	for entry in placements:
		var pickup := Node3D.new()
		pickup.set_script(_pickup_script)
		pickup.set("type", entry[0])
		pickup.name = "Pickup%d" % _pickups_root.get_child_count()
		_pickups_root.add_child(pickup)
		pickup.global_position = entry[1]

# --- Grenades --------------------------------------------------------------

func throw_grenade(owner_id: int, pos: Vector3, vel: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var id := _next_grenade_id
	_next_grenade_id += 1
	var grenade := Node3D.new()
	grenade.set_script(_grenade_script)
	grenade.name = "Grenade%d" % id
	_grenades_root.add_child(grenade)
	grenade.call("setup", id, owner_id, pos, vel)
	_grenades[id] = grenade
	_spawn_grenade.rpc(id, pos, vel)

func sync_grenade(id: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_sync_grenade.rpc(id, pos)

func remove_grenade(id: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_grenades.erase(id)
		_remove_grenade.rpc(id, pos)

@rpc("authority", "reliable")
func _spawn_grenade(id: int, pos: Vector3, vel: Vector3) -> void:
	if multiplayer.is_server():
		return
	var visual := _make_grenade_visual()
	visual.name = "GrenadeVisual%d" % id
	_grenades_root.add_child(visual)
	visual.global_position = pos
	_grenade_visuals[id] = visual

@rpc("authority", "unreliable")
func _sync_grenade(id: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		return
	var visual: Node3D = _grenade_visuals.get(id)
	if is_instance_valid(visual):
		visual.global_position = pos

@rpc("authority", "reliable", "call_local")
func _remove_grenade(id: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		return
	var visual: Node3D = _grenade_visuals.get(id)
	if is_instance_valid(visual):
		visual.queue_free()
	_grenade_visuals.erase(id)
	_flash_at(pos)

func _make_grenade_visual() -> Node3D:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.2, 0.13)
	mat.metallic = 0.5
	mesh.material_override = mat
	node.add_child(mesh)
	return node

func _flash_at(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	flash.material_override = mat
	_grenades_root.add_child(flash)
	flash.global_position = pos
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)

# --- Public API used by the menu -------------------------------------------

func set_local_name(value: String) -> void:
	var cleaned := value.strip_edges().substr(0, 16)
	if not cleaned.is_empty():
		my_name = cleaned

func set_local_team(value: int) -> void:
	my_team = clampi(value, 0, 1)

func set_local_loadout(weapon: int, perk: int) -> void:
	my_weapon = clampi(weapon, 0, 2)
	my_perk = clampi(perk, 0, 3)

func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		_menu.call("set_status", "Could not host: error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	if not _dedicated:
		_enter_game()
		_spawn_player(1)
	_match.call("start_match")

func join(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		_menu.call("set_status", "Could not join: error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	_menu.call("set_status", "Connecting to %s:%d..." % [ip, PORT])

func spawn_position_for(peer_id: int) -> Vector3:
	var i := int(_spawn_index.get(peer_id, 0))
	if _spawn_points.is_empty():
		return Vector3(0, 1, 0)
	return _spawn_points[i % _spawn_points.size()]

func player_display_name(peer_id: int) -> String:
	var p := _players.get(peer_id) as Player
	return p.display_name if p != null else "Player %d" % peer_id

func get_player(peer_id: int) -> Player:
	return _players.get(peer_id) as Player

func report_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server():
		return
	var killer := get_player(killer_id)
	var victim := get_player(victim_id)
	if killer != null:
		killer.kills += 1
		killer.call("check_killstreak")
	if victim != null:
		victim.deaths += 1
	_receive_kill.rpc(player_display_name(killer_id), player_display_name(victim_id))
	_match.call("register_kill", killer_id, victim_id)

func reset_players() -> void:
	if not multiplayer.is_server():
		return
	for id in _players:
		var p := _players[id] as Player
		if p == null:
			continue
		p.kills = 0
		p.deaths = 0
		p.call("reset_for_match")

# --- Callbacks -------------------------------------------------------------

func _on_connected_to_server() -> void:
	_enter_game()

func _on_connection_failed() -> void:
	_show_menu()
	_menu.call("set_status", "Connection failed.")

func _on_server_disconnected() -> void:
	_clear_players()
	for id in _grenade_visuals:
		var visual: Node3D = _grenade_visuals[id]
		if is_instance_valid(visual):
			visual.queue_free()
	_grenade_visuals.clear()
	_show_menu()
	_menu.call("set_status", "Disconnected from server.")
	# Deactivate the peer so per-frame code no longer queries an inactive API.
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server() or id == 1:
		return
	_spawn_player(id)
	# Broadcast to EVERYONE: the joiner needs players who connected earlier,
	# and existing clients need the player who just joined. State RPCs for the
	# new player start arriving immediately, so its node must exist everywhere.
	_receive_snapshot.rpc(_build_snapshot())
	for pickup in _pickups_root.get_children():
		if pickup.has_method("sync_to"):
			pickup.call("sync_to", id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_player(id)
	_receive_remove_player.rpc(id)

# --- Spawning / snapshots --------------------------------------------------

func _spawn_player(id: int) -> void:
	var p := _player_scene.instantiate() as Player
	p.peer_id = id
	p.name = "Player%d" % id
	_players_root.add_child(p)
	_players[id] = p
	_spawn_index[id] = _next_spawn
	_next_spawn = (_next_spawn + 1) % maxi(1, _spawn_points.size())
	p.global_position = spawn_position_for(id)

func _build_snapshot() -> Array:
	var snapshot: Array = []
	for id in _players:
		var p := _players[id] as Player
		if p == null:
			continue
		snapshot.append({
			"id": id,
			"pos": p.global_position,
			"yaw": p.yaw,
			"pitch": p.pitch,
			"hp": p.health,
			"ammo": p.ammo,
			"dead": p.dead,
			"name": p.display_name,
			"team": p.team,
			"kills": p.kills,
			"deaths": p.deaths,
			"weapon": p.weapon_index,
			"grenades": p.grenades,
			"perk": p.perk_id,
		})
	return snapshot

@rpc("authority", "reliable")
func _receive_snapshot(snapshot: Array) -> void:
	if multiplayer.is_server():
		return
	var me := multiplayer.get_unique_id()
	for entry in snapshot:
		var id := int(entry.get("id", 0))
		var p := _players.get(id) as Player
		if p == null:
			p = _player_scene.instantiate() as Player
			p.peer_id = id
			p.name = "Player%d" % id
			_players_root.add_child(p)
			_players[id] = p
			_spawn_index[id] = _players.size() - 1
		p.apply_snapshot(entry)
		if id == me:
			p.set_display_name.rpc_id(1, my_name)
			p.set_team.rpc_id(1, my_team)
			p.set_loadout.rpc_id(1, my_weapon, my_perk)
	_enter_game()

@rpc("authority", "reliable")
func _receive_remove_player(id: int) -> void:
	if multiplayer.is_server():
		return
	_remove_player(id)

func _remove_player(id: int) -> void:
	var p := _players.get(id) as Player
	if p != null:
		_players.erase(id)
		_spawn_index.erase(id)
		p.queue_free()

func _clear_players() -> void:
	for id in _players:
		var p := _players[id] as Player
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_spawn_index.clear()

@rpc("authority", "reliable", "call_local")
func _receive_kill(killer: String, victim: String) -> void:
	if _hud.has_method("add_kill"):
		_hud.call("add_kill", killer, victim)

# --- Per-frame state broadcast (server only) -------------------------------

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_state_accum += delta
	var period := 1.0 / STATE_HZ
	while _state_accum >= period:
		_state_accum -= period
		for id in _players:
			var p := _players[id] as Player
			if is_instance_valid(p):
				p.broadcast_state()

# --- UI state --------------------------------------------------------------

func _enter_game() -> void:
	_menu.visible = false
	_hud.visible = true

func _show_menu() -> void:
	_menu.visible = true
	_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
