extends RefCounted
class_name Weapons

const PATHS := [
	"res://resources/weapons/rifle.tres",
	"res://resources/weapons/smg.tres",
	"res://resources/weapons/shotgun.tres",
]

static var _cache: Array[WeaponData] = []

static func all() -> Array[WeaponData]:
	if _cache.is_empty():
		for path in PATHS:
			var data := load(path) as WeaponData
			if data != null:
				_cache.append(data)
	return _cache
