extends Resource
class_name WeaponData
## Server-owned stats plus client-side viewmodel placement for one weapon.

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene

@export var damage := 25
@export var fire_interval := 0.15
@export var magazine := 30
@export var reload_time := 1.2
@export var range := 120.0
@export var pellets := 1
@export var spread_deg := 0.0
@export var bloom_per_shot := 0.4
@export var bloom_max := 3.0
@export var recoil_deg := 1.2
@export var falloff_start := 40.0
@export var min_damage_scale := 0.5

# First-person placement. The CC0 models have their muzzle pointing +Z and
# sit with their footprint at y=0, so rotate 180deg to aim down -Z.
@export var view_offset := Vector3(0.22, -0.24, -0.42)
@export var view_rotation := Vector3(0.0, 3.14159, 0.0)
@export var view_scale := 1.0

@export var fire_sound: String = "fire"
@export var reload_sound: String = "reload"
