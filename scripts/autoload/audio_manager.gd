extends Node
## Synthesised audio playback. Streams come from AssetFactory.sfx().

var _pool: Array = []
var _next := 0
var _ambient: AudioStreamPlayer
var _context: Node2D


func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -16.0
	add_child(_ambient)


func set_context(node: Node2D) -> void:
	_context = node


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = AssetFactory.sfx(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(name: String, pos: Vector2, volume_db: float = 0.0) -> void:
	if _context == null:
		play(name, volume_db)
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = AssetFactory.sfx(name)
	p.volume_db = volume_db
	p.max_distance = 1400.0
	p.position = pos
	_context.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func start_ambient() -> void:
	_ambient.stream = AssetFactory.sfx("wind")
	if not _ambient.playing:
		_ambient.play()


func set_weather_mix(weather: String) -> void:
	match weather:
		"blizzard":
			_ambient.stream = AssetFactory.sfx("blizzard")
			_ambient.volume_db = -8.0
		"spore_fog":
			_ambient.stream = AssetFactory.sfx("wind")
			_ambient.volume_db = -14.0
		_:
			_ambient.stream = AssetFactory.sfx("wind")
			_ambient.volume_db = -18.0
	if not _ambient.playing:
		_ambient.play()
