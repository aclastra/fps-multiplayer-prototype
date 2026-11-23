extends Node3D
class_name WeaponView
## First-person weapon model, swapped when the player changes weapons.

var _weapon: Node3D

func set_weapon(data: WeaponData) -> void:
	for child in get_children():
		child.queue_free()
	_weapon = null
	if data == null or data.scene == null:
		return

	var weapon := data.scene.instantiate() as Node3D
	if weapon == null:
		return
	var basis := Basis().rotated(Vector3.RIGHT, data.view_rotation.x)
	basis = basis.rotated(Vector3.UP, data.view_rotation.y)
	basis = basis.rotated(Vector3.FORWARD, data.view_rotation.z)
	basis = basis.scaled(Vector3.ONE * data.view_scale)
	weapon.transform = Transform3D(basis, data.view_offset)
	weapon.name = "ViewWeapon"
	add_child(weapon)
	_weapon = weapon
