class_name CpuPlayer
extends RefCounted
## CPU の操作役。新しいミノが出たら置き場所を決め（Lv.4 以上は Cold Clear 2、
## それ以外や Cold Clear 2 が使えないときは自前の CpuBrain）、決まった置き場所までの操作
## （ホールド・移動・回転・その場落下・ハードドロップ）を人間と同じように 1 つずつ入力する。
## 重力でずれたら操作列を求め直す。

const TAS_LEVEL := 6
## 強さごとの設定
##  pps: 1秒に置く数の上限 / interval: 操作 1 回の間隔（tick、0 は 1 tick にまとめて）
##  depth: 何手先まで読むか / beam: 読むときに残す候補の数
##  spins: 回転やソフトドロップで入れる場所も探すか（Tスピン） / use_hold: ホールドを使うか
##  mistake: 最善でない手を選ぶ確率
##  cold_clear: Cold Clear 2 に考えさせる / think_ticks: そのとき考えさせる時間（tick）
const CONFIG := {
	1: {"pps": 0.7, "interval": 6, "depth": 1, "beam": 1, "spins": false, "use_hold": false, "mistake": 0.3},
	2: {"pps": 1.2, "interval": 5, "depth": 1, "beam": 1, "spins": false, "use_hold": true, "mistake": 0.12},
	3: {"pps": 1.8, "interval": 4, "depth": 1, "beam": 1, "spins": true, "use_hold": true, "mistake": 0.04},
	4: {"pps": 2.5, "interval": 3, "depth": 2, "beam": 4, "spins": true, "use_hold": true, "mistake": 0.0,
		"cold_clear": true, "think_ticks": 6},
	5: {"pps": 3.5, "interval": 2, "depth": 2, "beam": 6, "spins": true, "use_hold": true, "mistake": 0.0,
		"cold_clear": true, "think_ticks": 15},
	TAS_LEVEL: {"pps": 10.0, "interval": 0, "depth": 2, "beam": 4, "spins": true, "use_hold": true, "mistake": 0.0,
		"cold_clear": true, "think_ticks": 4},
}
const TAS_STEPS_PER_TICK := 12

var game: GameState
var level := 3
var use_thread := true          # シミュレーションでは false にして同じ結果を得る

var _config: Dictionary
var _rng := RandomNumberGenerator.new()
var _mutex := Mutex.new()
var _result := {}
var _result_ready := false
var _thinking_for := -1         # 考えている対象のミノ（pieces_placed の値）
var _target := {}
var _path = null                # Array（操作列）か null（未計算）
var _hold_done := false
var _last_y := 0
var _piece_ticks := 0
var _input_cooldown := 0
var _bot: ColdClearBot          # Cold Clear 2（使わないときは null）
var _bot_wait := -1             # 置き場所を聞くまでの残り tick。-1 は聞き済み / 使っていない
var _bot_asked := false


func _init(target_game: GameState, cpu_level: int) -> void:
	game = target_game
	level = cpu_level
	_config = CONFIG[level]
	# ミノの形のキャッシュを先に作っておく（別スレッドから同時に作らないように）
	for type in PieceData.ALL:
		for rot in 4:
			PieceData.cells(type, rot)
	if _config.get("cold_clear", false) and ColdClearBot.available():
		_bot = ColdClearBot.new()
		if not _bot.launch():
			_bot = null


## Cold Clear 2 のプロセスを終わらせる（ラウンドの終わりや画面を離れるとき）
func shutdown() -> void:
	if _bot != null:
		_bot.quit()
		_bot = null


func uses_cold_clear() -> bool:
	return _bot != null


func tick() -> void:
	_poll_bot()
	if not game.can_control():
		return
	if _thinking_for != game.pieces_placed:
		_start_thinking()
	_piece_ticks += 1
	if _bot_wait > 0:
		_bot_wait -= 1
		if _bot_wait == 0:
			_bot.suggest()
			_bot_asked = true
			_bot_wait = -1

	if _target.is_empty():
		if not _take_result():
			return
	if _input_cooldown > 0:
		_input_cooldown -= 1
		return
	var steps: int = TAS_STEPS_PER_TICK if _config.interval == 0 else 1
	for _i in steps:
		if not _step():
			break
	_input_cooldown = _config.interval


func _start_thinking() -> void:
	_thinking_for = game.pieces_placed
	_target = {}
	_path = null
	_hold_done = false
	_piece_ticks = 0
	_result_ready = false
	_bot_asked = false
	_bot_wait = -1
	if _bot != null and _bot.is_ready:
		_bot.start(game)
		_bot_wait = maxi(_config.think_ticks, 1)
		return
	var snapshot := {
		"rows": CpuBrain.rows_from(game.board),
		"piece": game.piece, "pos": Vector3i(game.pos.x, game.pos.y, game.rot),
		"hold": game.hold_piece, "hold_used": game.hold_used,
		"queue": Array(game.next_queue()), "b2b": game.b2b, "combo": game.combo,
		"incoming": game.incoming_total(),
	}
	var config := _config
	var id := _thinking_for
	var job := func():
		var r := CpuBrain.think(snapshot, config)
		_mutex.lock()
		if id == _thinking_for:
			_result = r
			_result_ready = true
		_mutex.unlock()
	if use_thread:
		WorkerThreadPool.add_task(job)
	else:
		job.call()


## Cold Clear 2 からの返事を受け取る
func _poll_bot() -> void:
	if _bot == null:
		return
	var r := _bot.poll()
	if r.is_empty() or not _bot_asked:
		return
	_bot_asked = false
	if not r.has("none"):
		r["hold"] = r.type != game.piece
	_mutex.lock()
	_result = r
	_result_ready = true
	_mutex.unlock()


## 考え終わっていれば目標にする
func _take_result() -> bool:
	_mutex.lock()
	var ready := _result_ready
	var r := _result
	_mutex.unlock()
	if not ready:
		return false
	if r.is_empty():
		_target = {"none": true}
		return true
	_target = r
	var candidates: Array = r.get("candidates", [])
	if candidates.size() > 1 and _rng.randf() < _config.mistake:
		_target = candidates[_rng.randi_range(1, mini(candidates.size() - 1, 4))]
	return true


## 1 操作ぶん進める。続けて操作してよければ true
func _step() -> bool:
	if _target.has("none"):
		return _drop()
	if _target.hold and not _hold_done:
		_hold_done = true
		_path = null
		game.hold()
		return true
	# 重力で下がった・操作が効かなかったときは操作列を求め直す
	if _path == null or game.pos.y != _last_y:
		_path = CpuBrain.path_to(CpuBrain.rows_from(game.board), game.piece, Vector3i(game.pos.x, game.pos.y, game.rot), _target)
		if _path == null:
			# 行けない置き場所だったら、自前の思考でその場で選び直す
			_target = _fallback_target()
			_path = null
			if _target.has("none"):
				return _drop()
			_path = CpuBrain.path_to(CpuBrain.rows_from(game.board), game.piece, Vector3i(game.pos.x, game.pos.y, game.rot), _target)
			if _path == null:
				_target = {"none": true}
				return _drop()
	if _path.is_empty():
		return _drop()
	var ok := true
	match _path.pop_front():
		CpuBrain.Act.LEFT:
			ok = game.move(-1)
		CpuBrain.Act.RIGHT:
			ok = game.move(1)
		CpuBrain.Act.CW:
			ok = game.rotate(1)
		CpuBrain.Act.CCW:
			ok = game.rotate(-1)
		CpuBrain.Act.DROP:
			game.sonic_drop()
	_last_y = game.pos.y
	if not ok:
		_path = null
	return true


## 今のミノだけで置き場所を選ぶ（ホールドはしない）
func _fallback_target() -> Dictionary:
	var state := {
		"rows": CpuBrain.rows_from(game.board),
		"piece": game.piece, "pos": Vector3i(game.pos.x, game.pos.y, game.rot),
		"hold": game.hold_piece, "hold_used": true,
		"queue": Array(game.next_queue()), "b2b": game.b2b, "combo": game.combo,
		"incoming": game.incoming_total(),
	}
	var r := CpuBrain.think(state, {"depth": 1, "beam": 1, "spins": true, "use_hold": false})
	if r.is_empty():
		return {"none": true}
	r["hold"] = false
	return r


## 速さの上限を守ってハードドロップする
func _drop() -> bool:
	if _piece_ticks < 60.0 / _config.pps:
		return false
	game.hard_drop()
	return false
