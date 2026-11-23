extends Node
## Tiny procedural sound player. All clips are locally generated WAVs (CC0).

const CLIPS := {
	"fire": "res://assets/audio/fire.wav",
	"reload": "res://assets/audio/reload.wav",
	"hit": "res://assets/audio/hit.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"death": "res://assets/audio/death.wav",
	"pickup": "res://assets/audio/pickup.wav",
}

var _streams := {}

func _ready() -> void:
	for name in CLIPS:
		var stream := load(CLIPS[name]) as AudioStream
		if stream != null:
			_streams[name] = stream

func play(name: String, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
