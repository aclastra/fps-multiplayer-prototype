extends Node
class_name MatchManager
## Server-authoritative match flow: lobby -> countdown -> playing -> match end.
## Clients only receive state snapshots and display them.

enum State { LOBBY, COUNTDOWN, PLAYING, MATCH_END }

const SCORE_LIMIT := 20
const TIME_LIMIT := 300.0
const COUNTDOWN_TIME := 3.0
const END_DELAY := 5.0
const BROADCAST_INTERVAL := 0.2

var state := State.LOBBY
var scores := {0: 0, 1: 0}
var time_left := TIME_LIMIT
var countdown := COUNTDOWN_TIME
var winner := -1

var _end_timer := 0.0
var _broadcast_accum := 0.0
var _game: Node

func _ready() -> void:
	add_to_group("match_manager")
	call_deferred("_bind_game")

func _bind_game() -> void:
	_game = get_tree().get_first_node_in_group("game_manager")

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return

	match state:
		State.COUNTDOWN:
			countdown -= delta
			if countdown <= 0.0:
				countdown = 0.0
				state = State.PLAYING
				_broadcast()
		State.PLAYING:
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				_end_match(-1)
		State.MATCH_END:
			_end_timer -= delta
			if _end_timer <= 0.0:
				start_match()

	_broadcast_accum += delta
	if _broadcast_accum >= BROADCAST_INTERVAL:
		_broadcast_accum = 0.0
		_broadcast()

func start_match() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	scores[0] = 0
	scores[1] = 0
	time_left = TIME_LIMIT
	countdown = COUNTDOWN_TIME
	winner = -1
	state = State.COUNTDOWN
	if _game != null and _game.has_method("reset_players"):
		_game.call("reset_players")
	_broadcast()

func register_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server() or state != State.PLAYING:
		return
	var team := _team_of(killer_id)
	if team < 0:
		return
	scores[team] = int(scores.get(team, 0)) + 1
	if scores[team] >= SCORE_LIMIT:
		_end_match(team)
	_broadcast()

func is_playing() -> bool:
	return state == State.PLAYING

func _end_match(winning_team: int) -> void:
	state = State.MATCH_END
	winner = winning_team
	_end_timer = END_DELAY
	_broadcast()

func _team_of(peer_id: int) -> int:
	if _game == null:
		return -1
	var p: Player = _game.call("get_player", peer_id) as Player
	return p.team if p != null else -1

func _broadcast() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_send_state.rpc(state, scores, time_left, countdown, winner)

@rpc("authority", "reliable", "call_local")
func _send_state(new_state: int, new_scores: Dictionary, new_time: float, new_countdown: float, new_winner: int) -> void:
	state = new_state
	scores = new_scores
	time_left = new_time
	countdown = new_countdown
	winner = new_winner
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("update_match"):
		hud.call("update_match", state, scores, time_left, countdown, winner)
