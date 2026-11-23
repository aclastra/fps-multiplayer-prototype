extends CanvasLayer
## Health / ammo readout, crosshair, kill feed, score and scoreboard.

var _hp: Label
var _ammo: Label
var _grenades: Label
var _status: Label
var _feed: VBoxContainer
var _banner: Label
var _center_msg: Label
var _scoreboard: PanelContainer
var _scoreboard_list: VBoxContainer
var _hitmarker: Label
var _announcement: Label
var _announcement_time := 0.0
var _floaters: Array = []
var _damage_arrows: Array = []
var _hitmarker_time := 0.0

func _ready() -> void:
	add_to_group("hud")

	var stats := PanelContainer.new()
	stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stats.offset_left = 14
	stats.offset_top = 14
	stats.offset_right = 214
	stats.offset_bottom = 110
	add_child(stats)

	var stats_box := VBoxContainer.new()
	stats.add_child(stats_box)
	_hp = _make_label("HP  100", 20)
	_ammo = _make_label("RIFLE  30 / 30", 18)
	_grenades = _make_label("GRENADES  2", 15)
	_status = _make_label("", 13)
	stats_box.add_child(_hp)
	stats_box.add_child(_ammo)
	stats_box.add_child(_grenades)
	stats_box.add_child(_status)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.position = Vector2(-10, -18)
	add_child(crosshair)

	_hitmarker = _make_label("×", 26)
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	_hitmarker.offset_left = -12
	_hitmarker.offset_top = -24
	_hitmarker.visible = false
	add_child(_hitmarker)

	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -320
	_feed.offset_top = 14
	_feed.offset_right = -14
	add_child(_feed)

	_announcement = _make_label("", 20)
	_announcement.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_announcement.offset_left = -300
	_announcement.offset_right = 300
	_announcement.offset_top = 50
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.visible = false
	add_child(_announcement)

	_banner = _make_label("BLUE 0  -  0 RED", 18)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -200
	_banner.offset_right = 200
	_banner.offset_top = 12
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)

	_center_msg = _make_label("", 42)
	_center_msg.set_anchors_preset(Control.PRESET_CENTER)
	_center_msg.offset_left = -300
	_center_msg.offset_right = 300
	_center_msg.offset_top = -70
	_center_msg.offset_bottom = 10
	_center_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_center_msg)

	_scoreboard = PanelContainer.new()
	_scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	_scoreboard.offset_left = -280
	_scoreboard.offset_right = 280
	_scoreboard.offset_top = -210
	_scoreboard.offset_bottom = 210
	_scoreboard.visible = false
	add_child(_scoreboard)
	_scoreboard_list = VBoxContainer.new()
	_scoreboard.add_child(_scoreboard_list)

	var hint := Label.new()
	hint.text = "WASD move · Shift sprint · Ctrl crouch/slide · Space jump · LMB fire · R reload · 1/2/3 weapons · G grenade · Tab scoreboard · Esc mouse"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 14
	hint.offset_bottom = -12
	hint.add_theme_font_size_override("font_size", 13)
	add_child(hint)

func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func update_match(state: int, scores: Dictionary, time_left: float, countdown: float, winner: int) -> void:
	var blue := int(scores.get(0, 0))
	var red := int(scores.get(1, 0))
	var seconds := maxi(0, ceili(time_left))
	_banner.text = "BLUE %d  -  %d RED     %02d:%02d" % [blue, red, seconds / 60, seconds % 60]

	match state:
		0: # LOBBY
			_center_msg.text = "Waiting for players..."
		1: # COUNTDOWN
			_center_msg.text = "GET READY  %d" % maxi(1, ceili(countdown))
		2: # PLAYING
			_center_msg.text = ""
		3: # MATCH_END
			var team_name := "DRAW" if winner < 0 else ("BLUE" if winner == 0 else "RED")
			_center_msg.text = "%s TEAM WINS" % team_name

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		_scoreboard.visible = event.pressed

func _process(delta: float) -> void:
	_animate_feedback(delta)
	if _scoreboard.visible:
		_refresh_scoreboard()
	if multiplayer.multiplayer_peer == null:
		return
	var me := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p == null or p.peer_id != me:
			continue
		_hp.text = "HP  %d" % p.health
		var weapon := p.current_weapon()
		if weapon != null:
			_ammo.text = "%s  %d / %d" % [weapon.display_name.to_upper(), p.ammo, weapon.magazine]
		_grenades.text = "GRENADES  %d   [G]" % p.grenades
		_status.text = "DEAD — respawning..." if p.dead else ""
		return

func show_announcement(text: String) -> void:
	_announcement.text = text
	_announcement.visible = true
	_announcement_time = 2.5

func add_hitmarker(damage: int, headshot: bool = false) -> void:
	_hitmarker.visible = true
	_hitmarker.modulate = Color(1, 0.85, 0.6) if headshot else Color(1, 1, 1)
	_hitmarker_time = 0.12
	var center := get_viewport().get_visible_rect().size * 0.5
	var label := _make_label(str(damage), 20)
	label.position = center + Vector2(randf_range(-45, 45), randf_range(-45, 10))
	add_child(label)
	_floaters.append({"label": label, "time": 0.8})

func show_damage_direction(angle: float) -> void:
	var arrow := _make_label("◄", 26)
	var center := get_viewport().get_visible_rect().size * 0.5
	arrow.position = center + Vector2(cos(angle), sin(angle)) * 170.0 - Vector2(10, 16)
	arrow.rotation = angle + PI
	add_child(arrow)
	_damage_arrows.append({"label": arrow, "time": 1.0})

func _animate_feedback(delta: float) -> void:
	if _announcement_time > 0.0:
		_announcement_time -= delta
		if _announcement_time <= 0.0:
			_announcement.visible = false
	if _hitmarker_time > 0.0:
		_hitmarker_time -= delta
		if _hitmarker_time <= 0.0:
			_hitmarker.visible = false

	for entry in _floaters.duplicate():
		entry["time"] -= delta
		var label: Label = entry["label"]
		label.position.y -= 45.0 * delta
		label.modulate.a = clampf(float(entry["time"]) / 0.8, 0.0, 1.0)
		if entry["time"] <= 0.0:
			label.queue_free()
			_floaters.erase(entry)

	for entry in _damage_arrows.duplicate():
		entry["time"] -= delta
		var arrow: Label = entry["label"]
		arrow.modulate.a = clampf(float(entry["time"]), 0.0, 1.0)
		if entry["time"] <= 0.0:
			arrow.queue_free()
			_damage_arrows.erase(entry)

func _refresh_scoreboard() -> void:
	for child in _scoreboard_list.get_children():
		child.queue_free()
	var title := _make_label("TEAM  NAME                K   D", 16)
	_scoreboard_list.add_child(title)
	var players: Array = []
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as Player
		if p != null:
			players.append(p)
	players.sort_custom(func(a: Player, b: Player) -> bool: return a.kills > b.kills)
	for p in players:
		var team_name := "BLUE" if p.team == 0 else "RED"
		_scoreboard_list.add_child(_make_label(
			"%-5s %-18s %2d  %2d" % [team_name, p.display_name.substr(0, 16), p.kills, p.deaths], 15
		))

func add_kill(killer: String, victim: String) -> void:
	var line := _make_label("%s  >  %s" % [killer, victim], 15)
	_feed.add_child(line)
	_feed.move_child(line, 0)
	while _feed.get_child_count() > 6:
		_feed.get_child(_feed.get_child_count() - 1).queue_free()
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(line):
		line.queue_free()
