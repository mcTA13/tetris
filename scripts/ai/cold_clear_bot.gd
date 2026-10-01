class_name ColdClearBot
extends RefCounted
## Cold Clear 2（MinusKelvin 作、MIT / Apache-2.0）を外部プロセスとして動かし、
## Tetris Bot Protocol（1 行 1 件の JSON を標準入出力でやり取り）で置き場所を聞く。
## ミノが出るたびに盤面ごと送り直す（おじゃまのせり上がりでずれないように）。

const EXE_NAME := "cold-clear-2.exe"
const ORIENTATIONS := ["north", "east", "south", "west"]
# TBP の「ミノの中心」が、このゲームのバウンディングボックスのどこにあたるか（回転状態ごと）
const I_CENTER := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2)]
const O_CENTER := [Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
const JLSTZ_CENTER := Vector2i(1, 1)
const SPINS := {"none": GameState.Spin.NONE, "mini": GameState.Spin.MINI, "full": GameState.Spin.FULL}

var is_ready := false           # rules に ready が返ってきた

var _pid := -1
var _stdio: FileAccess
var _reader: Thread
var _mutex := Mutex.new()
var _lines: Array[String] = []
var _running := false           # start を送って計算中


## 実行ファイルの場所（書き出し後はゲームの exe の隣の lib/、エディタではプロジェクトの lib/）
static func exe_path() -> String:
	var candidates := [
		OS.get_executable_path().get_base_dir().path_join("lib").path_join(EXE_NAME),
		ProjectSettings.globalize_path("res://lib/" + EXE_NAME),
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""


static func available() -> bool:
	return exe_path() != ""


## 起動して rules を送る。失敗したら false。
## config_name を渡すと、exe と同じフォルダのその設定ファイル（評価の重み）で起動する
func launch(config_name := "") -> bool:
	var path := exe_path()
	if path == "":
		return false
	var args := []
	if config_name != "":
		var config := path.get_base_dir().path_join(config_name)
		if FileAccess.file_exists(config):
			args = ["--config", config]
	var info := OS.execute_with_pipe(path, args)
	if info.is_empty():
		return false
	_pid = info.pid
	_stdio = info.stdio
	_reader = Thread.new()
	_reader.start(_read_loop)
	_send({"type": "rules"})
	return true


func _read_loop() -> void:
	# quit() で _stdio が null にされても困らないよう、自分用の参照で読む
	var io := _stdio
	while io != null and io.is_open():
		var line := io.get_line()
		if line == "" and io.get_error() != OK:
			break
		if line.strip_edges() == "":
			continue
		_mutex.lock()
		_lines.append(line)
		_mutex.unlock()


## 届いたメッセージを処理する。suggestion が来ていればその手（このゲームの形）を返す
func poll() -> Dictionary:
	_mutex.lock()
	var lines := _lines.duplicate()
	_lines.clear()
	_mutex.unlock()
	var result := {}
	for line in lines:
		var msg = JSON.parse_string(line)
		if not msg is Dictionary:
			continue
		match msg.get("type", ""):
			"ready":
				is_ready = true
			"suggestion":
				var moves: Array = msg.get("moves", [])
				result = {"none": true} if moves.is_empty() else to_target(moves[0])
	return result


## 今の状態から計算を始めさせる
func start(game: GameState) -> void:
	if _running:
		_send({"type": "stop"})
	var board := []
	for y in range(Board.HEIGHT - 1, -1, -1):  # TBP は一番下の行が先頭
		var row := []
		for x in Board.WIDTH:
			var v: int = game.board.grid[y][x]
			row.append(null if v == PieceData.NONE else PieceData.NAMES[v])
		board.append(row)
	var queue := [PieceData.NAMES[game.piece]]
	for p in game.next_queue():
		queue.append(PieceData.NAMES[p])
	# TBP には「このミノではもうホールドした」を伝える項目がない。ホールド済みのときは
	# ホールドを今のミノと同じ種類と伝え、ホールドしてもしなくても今のミノを置く手になるようにする
	var hold = null if game.hold_piece == PieceData.NONE else PieceData.NAMES[game.hold_piece]
	if game.hold_used:
		hold = PieceData.NAMES[game.piece]
	_send({
		"type": "start",
		"hold": hold,
		"queue": queue,
		"combo": game.combo + 1 if game.combo >= 0 else 0,
		"back_to_back": game.b2b >= 0,
		"board": board,
	})
	_running = true


func suggest() -> void:
	_send({"type": "suggest"})


func quit() -> void:
	if _stdio != null:
		_send({"type": "quit"})
		_stdio.close()
		_stdio = null
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _reader != null and _reader.is_started():
		_reader.wait_to_finish()
	_reader = null


## TBP の手 → {"hold"?: 判定は呼び出し側, "type", "x", "y", "rot", "spin"}（このゲームの座標）
static func to_target(move: Dictionary) -> Dictionary:
	var loc: Dictionary = move.location
	var type: int = PieceData.NAMES.find(loc.type)
	var rot: int = ORIENTATIONS.find(loc.orientation)
	var center: Vector2i = JLSTZ_CENTER
	if type == PieceData.I:
		center = I_CENTER[rot]
	elif type == PieceData.O:
		center = O_CENTER[rot]
		rot = 0  # O はどの向きでも同じ形
	var row := Board.HEIGHT - 1 - int(loc.y)
	return {
		"type": type,
		"x": int(loc.x) - center.x,
		"y": row - center.y,
		"rot": rot,
		"spin": SPINS.get(move.get("spin", "none"), GameState.Spin.NONE),
	}


func _send(msg: Dictionary) -> void:
	if _stdio == null:
		return
	_stdio.store_line(JSON.stringify(msg))
	_stdio.flush()
