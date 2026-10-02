class_name ColdClearBot
extends RefCounted
## Cold Clear 2（MinusKelvin 作、MIT / Apache-2.0）を外部プロセスとして動かし、
## Tetris Bot Protocol（1 行 1 件の JSON を標準入出力でやり取り）で置き場所を聞く。
## 選んだ手を play で伝えると、Cold Clear 2 は次のミノの手を考え続ける（読みを捨てずに済む）。
## 次のミノが出たとき盤面が思った通りでなければ（おじゃまのせり上がりなど）、盤面ごと送り直す。

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
# Cold Clear 2 が思っている状態（play を送ったあと、そのまま続けられるか確かめるため）
var _known_queue: Array[int] = []  # 今のミノ＋NEXT
var _known_hold := PieceData.NONE
var _expected_rows := PackedInt32Array()
var _can_continue := false


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
				if moves.is_empty():
					result = {"none": true}
				else:
					result = to_target(moves[0])
					result["tbp"] = moves[0]
	return result


## 新しいミノが出たときに呼ぶ。前に play した続きのままなら、増えた NEXT だけを伝える。
## そうでなければ盤面ごと送り直す（このときは false を返す。一から考え直しになる）
func begin(game: GameState) -> bool:
	if _continue(game):
		return true
	start(game)
	return false


func _continue(game: GameState) -> bool:
	if not _can_continue or game.hold_used or game.hold_piece != _known_hold:
		return false
	if CpuBrain.rows_from(game.board) != _expected_rows:
		return false
	var queue: Array[int] = [game.piece]
	queue.append_array(game.next_queue())
	if queue.size() < _known_queue.size() or queue.slice(0, _known_queue.size()) != _known_queue:
		return false
	for p in queue.slice(_known_queue.size()):
		_send({"type": "new_piece", "piece": PieceData.NAMES[p]})
	_known_queue = queue
	return true


## 選んだ手を伝える。Cold Clear 2 はその後の状態で次の手を考え始める
func play(target: Dictionary) -> void:
	if not target.has("tbp") or _known_queue.is_empty():
		_can_continue = false
		return
	# JSON から読んだ数は小数になっているので、整数に戻して送る（Cold Clear 2 は小数を受け付けない）
	var loc: Dictionary = target.tbp.location
	_send({"type": "play", "move": {
		"location": {"type": loc.type, "orientation": loc.orientation, "x": int(loc.x), "y": int(loc.y)},
		"spin": target.tbp.get("spin", "none"),
	}})
	if _known_queue[0] != target.type:
		# ホールドした。ホールドが空なら次のミノを置いている
		var first: int = _known_queue.pop_front()
		if _known_hold == PieceData.NONE:
			_known_queue.pop_front()
		_known_hold = first
	else:
		_known_queue.pop_front()
	_expected_rows = CpuBrain.place(_expected_rows, target.type, target.rot, target.x, target.y)[0]
	_can_continue = true


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
	var bag_state := []
	for p in game.bag.remaining_after(GameState.NEXT_COUNT):
		bag_state.append(PieceData.NAMES[p])
	_send({
		"type": "start",
		"hold": hold,
		"queue": queue,
		"combo": game.combo + 1 if game.combo >= 0 else 0,
		"back_to_back": game.b2b >= 0,
		"board": board,
		"randomizer": {"type": "seven_bag", "bag_state": bag_state},
	})
	_running = true
	_known_queue.assign([game.piece] + Array(game.next_queue()))
	_known_hold = PieceData.NAMES.find(hold) if hold != null else PieceData.NONE
	_expected_rows = CpuBrain.rows_from(game.board)
	_can_continue = false


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
