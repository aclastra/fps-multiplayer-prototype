extends Node3D
class_name Pickup
## Server-authoritative health / ammo pickup with timed respawn.

enum Type { HEALTH, AMMO }

@export var type: Type = Type.HEALTH
@export var respawn_time := 15.0
@export var pickup_radius := 1.6

var available := true
var _respawn_timer := 0.0
var _visual: Node3D

func _ready() -> void:
	_build_visual()
	_apply()

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not available:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			set_available(true)
		return
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Player
		if player == null or player.dead:
			continue
		if player.global_position.distance_to(global_position) <= pickup_radius:
			_collect(player)
			break

func _collect(player: Player) -> void:
	if type == Type.HEALTH:
		player.health = mini(player.max_health, player.health + 30)
	else:
		player.call("refill_ammo")
	set_available(false)
	_respawn_timer = respawn_time

func set_available(value: bool) -> void:
	if not multiplayer.is_server():
		return
	available = value
	_apply()
	_send_available.rpc(value)

func sync_to(peer_id: int) -> void:
	if multiplayer.is_server():
		_send_available.rpc_id(peer_id, available)

@rpc("authority", "reliable")
func _send_available(value: bool) -> void:
	if multiplayer.is_server():
		return
	available = value
	_apply()

func _apply() -> void:
	if is_instance_valid(_visual):
		_visual.visible = available

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.35, 0.5)
	base.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.45, 0.25) if type == Type.HEALTH else Color(0.45, 0.34, 0.16)
	mat.metallic = 0.4
	mat.roughness = 0.5
	base.material_override = mat
	base.position.y = 0.2
	_visual.add_child(base)

	var marker := MeshInstance3D.new()
	var marker_box := BoxMesh.new()
	marker_box.size = Vector3(0.32, 0.06, 0.34) if type == Type.HEALTH else Vector3(0.34, 0.08, 0.34)
	marker.mesh = marker_box
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.9, 0.25, 0.25) if type == Type.HEALTH else Color(0.85, 0.7, 0.3)
	marker_mat.emission_enabled = true
	marker_mat.emission = marker_mat.albedo_color
	marker.material_override = marker_mat
	marker.position.y = 0.4
	_visual.add_child(marker)
