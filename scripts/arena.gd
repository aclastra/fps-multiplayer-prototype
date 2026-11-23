extends Node3D
## Builds a simple box arena at runtime. Everything here is static geometry:
## it exists identically on the server and on every client.

const FLOOR_SIZE := 42.0
const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 1.0

func _ready() -> void:
	var floor_color := Color(0.17, 0.19, 0.22)
	var wall_color := Color(0.32, 0.35, 0.40)
	var crate_color := Color(0.55, 0.36, 0.20)

	_add_box(Vector3(0, -0.5, 0), Vector3(FLOOR_SIZE, 1, FLOOR_SIZE), floor_color)

	var half := FLOOR_SIZE * 0.5
	var wall_len := FLOOR_SIZE + WALL_THICKNESS
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, -half), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, half), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	_add_box(Vector3(-half, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), wall_color)
	_add_box(Vector3(half, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), wall_color)

	# A few crates for cover and line-of-sight testing.
	for p in [Vector3(-8, 1, -6), Vector3(8, 1, 6), Vector3(-6, 1, 9), Vector3(7, 1, -9)]:
		_add_box(p, Vector3(2, 2, 2), crate_color)

func spawn_points() -> Array[Vector3]:
	return [
		Vector3(-12, 1.0, -12),
		Vector3(12, 1.0, 12),
		Vector3(12, 1.0, -12),
		Vector3(-12, 1.0, 12),
		Vector3(0, 1.0, -15),
		Vector3(0, 1.0, 15),
		Vector3(-15, 1.0, 0),
		Vector3(15, 1.0, 0),
	]

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_inst.material_override = material
	body.add_child(mesh_inst)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
