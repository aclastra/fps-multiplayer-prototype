extends Node3D
class_name Grenade
## Server-side grenade simulation. Clients get positions through main.gd RPCs.

const RADIUS := 5.0
const MAX_DAMAGE := 90
const FUSE := 2.0
const GRAVITY := 20.0

var grenade_id := 0
var owner_id := 0
var velocity := Vector3.ZERO
var fuse := FUSE
var _sync_accum := 0.0

func setup(id: int, owner: int, pos: Vector3, vel: Vector3) -> void:
	grenade_id = id
	owner_id = owner
	global_position = pos
	velocity = vel

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return

	fuse -= delta
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta

	if global_position.y < 0.16:
		global_position.y = 0.16
		velocity.y = absf(velocity.y) * 0.35
		velocity.x *= 0.7
		velocity.z *= 0.7

	_sync_accum += delta
	if _sync_accum >= 0.05:
		_sync_accum = 0.0
		var game := get_tree().get_first_node_in_group("game_manager")
		if game != null and game.has_method("sync_grenade"):
			game.call("sync_grenade", grenade_id, global_position)

	if fuse <= 0.0:
		_explode()

func _explode() -> void:
	var game := get_tree().get_first_node_in_group("game_manager")
	if game != null and game.has_method("remove_grenade"):
		game.call("remove_grenade", grenade_id, global_position)

	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Player
		if player == null or player.dead:
			continue
		var distance := player.global_position.distance_to(global_position)
		if distance > RADIUS:
			continue
		var damage := int(MAX_DAMAGE * (1.0 - distance / RADIUS))
		if damage > 0:
			player.take_damage(damage, owner_id)
	queue_free()
