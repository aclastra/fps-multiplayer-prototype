extends Node3D
class_name WeaponView
## First-person weapon model with subtle sway, bob and ADS blending.

const ADS_OFFSET := Vector3(0.0, -0.17, -0.36)

var _weapon: Node3D
var _data: WeaponData
var _base_basis := Basis.IDENTITY
var _bob_time := 0.0
var _sway := Vector2.ZERO
var _speed := 0.0
var _ads := false
var _ads_t := 0.0

func set_weapon(data: WeaponData) -> void:
	for child in get_children():
		child.queue_free()
	_weapon = null
	_data = data
	if data == null or data.scene == null:
		return

	var weapon := data.scene.instantiate() as Node3D
	if weapon == null:
		return
	_base_basis = Basis().rotated(Vector3.RIGHT, data.view_rotation.x)
	_base_basis = _base_basis.rotated(Vector3.UP, data.view_rotation.y)
	_base_basis = _base_basis.rotated(Vector3.FORWARD, data.view_rotation.z)
	_base_basis = _base_basis.scaled(Vector3.ONE * data.view_scale)
	weapon.transform = Transform3D(_base_basis, data.view_offset)
	weapon.name = "ViewWeapon"
	add_child(weapon)
	_weapon = weapon

func set_motion(speed: float, delta: float) -> void:
	_speed = speed
	_bob_time += delta * (3.0 + clampf(speed, 0.0, 12.0) * 0.25)

func add_sway(relative: Vector2) -> void:
	_sway += Vector2(-relative.x, -relative.y) * 0.0006
	_sway = _sway.limit_length(0.035)

func set_ads(value: bool) -> void:
	_ads = value

func _process(delta: float) -> void:
	if _weapon == null or _data == null:
		return
	_ads_t = lerpf(_ads_t, 1.0 if _ads else 0.0, 1.0 - exp(-12.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	var bob := clampf(_speed / 6.0, 0.0, 1.0) * 0.008
	var offset := _data.view_offset.lerp(ADS_OFFSET, _ads_t)
	offset += Vector3(sin(_bob_time) * bob + _sway.x, cos(_bob_time * 2.0) * bob * 0.6 + _sway.y, 0.0)
	_weapon.transform = Transform3D(_base_basis, offset)
