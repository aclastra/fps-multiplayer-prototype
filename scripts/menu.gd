extends CanvasLayer
## Minimal host/join menu, built in code to keep the scene file tiny.

var _status_label: Label

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "FPS MULTIPLAYER PROTOTYPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var name_line := LineEdit.new()
	name_line.placeholder_text = "Your name"
	name_line.text = "Player"
	vbox.add_child(name_line)

	var team_option := OptionButton.new()
	team_option.add_item("Team: Steel Blue", 0)
	team_option.add_item("Team: Rust Red", 1)
	vbox.add_child(team_option)

	var ip_line := LineEdit.new()
	ip_line.placeholder_text = "Server IP"
	ip_line.text = "127.0.0.1"
	vbox.add_child(ip_line)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var host_btn := Button.new()
	host_btn.text = "Host"
	buttons.add_child(host_btn)
	var join_btn := Button.new()
	join_btn.text = "Join"
	buttons.add_child(join_btn)

	_status_label = Label.new()
	_status_label.text = "Host a game, or join one on this machine / LAN."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	var help := Label.new()
	help.text = "WASD move  |  Mouse aim  |  LMB fire  |  Shift sprint\nSpace jump  |  R reload  |  Esc release mouse (click to recapture)"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	vbox.add_child(help)

	# Look up the manager when a button is actually pressed: child _ready()
	# callbacks run before the parent's, so the group may not exist yet here.
	host_btn.pressed.connect(func() -> void:
		var game := get_tree().get_first_node_in_group("game_manager")
		if game == null:
			return
		game.call("set_local_name", name_line.text)
		game.call("set_local_team", team_option.selected)
		game.call("host")
	)
	join_btn.pressed.connect(func() -> void:
		var game := get_tree().get_first_node_in_group("game_manager")
		if game == null:
			return
		game.call("set_local_name", name_line.text)
		game.call("set_local_team", team_option.selected)
		game.call("join", ip_line.text)
	)

func set_status(text: String) -> void:
	_status_label.text = text
