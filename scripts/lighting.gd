extends Node3D
## Arena lighting and atmosphere. Kept in code so it is easy to tune.
## Lights have shadows disabled to stay cheap on integrated graphics.

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)

	var ambient := Environment.new()
	ambient.background_mode = Environment.BG_COLOR
	ambient.background_color = Color(0.05, 0.07, 0.10)
	ambient.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.ambient_light_color = Color(0.45, 0.55, 0.75)
	ambient.ambient_light_energy = 0.8
	ambient.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambient.fog_enabled = true
	ambient.fog_light_color = Color(0.07, 0.09, 0.13)
	ambient.fog_density = 0.012

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = ambient
	add_child(world)

	for position in [Vector3(-8, 4, -6), Vector3(8, 4, 6), Vector3(0, 4, 10)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.65, 0.78, 1.0)
		lamp.light_energy = 2.0
		lamp.omni_range = 14.0
		lamp.shadow_enabled = false
		lamp.position = position
		add_child(lamp)
