extends Node
## 効果音を鳴らす。音の中身は今のスキンが用意する（テイストと一緒に音も変わる）。

const VOICES := 12

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _banks := {}                # スキン名 → {音の名前: AudioStreamWAV}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	prepare()


## 今のスキンの音を先に作っておく（最初に鳴らしたときのカクつき防止）
func prepare() -> void:
	_bank()


## pitch: 再生速度（1.0 で元の高さ）。volume: 0〜1
func play(sound: String, pitch := 1.0, volume := 1.0) -> void:
	var master: float = App.settings.se_volume / 10.0
	if master <= 0.0:
		return
	var bank := _bank()
	if not bank.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = bank[sound]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(master * volume)
	p.play()


func _bank() -> Dictionary:
	var key: String = App.settings.skin
	if not _banks.has(key):
		var bank := {}
		var sounds: Dictionary = App.skin.build_sounds()
		for sound in sounds:
			bank[sound] = Synth.to_stream(sounds[sound])
		_banks[key] = bank
	return _banks[key]
