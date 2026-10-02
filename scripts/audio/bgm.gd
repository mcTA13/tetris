extends Node
## BGM。ゲーム中（ひとり用・CPU対戦・デモ）に GO! の後から流し、タイトルに戻ったら止める。
## 曲のファイルはループの終わり（3:05.32）で切ってあり、終わりまで来たら LOOP_START に戻る。

const TRACK_PATH := "res://assets/bgm/korobushka.ogg"
const LOOP_START := 0.871       # ループで戻る位置（秒）
const BASE_VOLUME := 0.6        # 効果音より少し控えめにする

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var track: AudioStreamOggVorbis = load(TRACK_PATH)
	track.loop = true
	track.loop_offset = LOOP_START
	_player.stream = track
	add_child(_player)


## 流れていなければ最初から流す（流れていればそのまま続ける）
func play() -> void:
	update_volume()
	if not _player.playing:
		_player.play()


func stop() -> void:
	_player.stop()


## ポーズ中は止めておく
func set_paused(value: bool) -> void:
	_player.stream_paused = value


func update_volume() -> void:
	_player.volume_linear = BASE_VOLUME * App.settings.bgm_volume / 10.0
