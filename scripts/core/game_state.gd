class_name GameState
extends RefCounted
## 1プレイヤー分のゲーム進行。描画・入力には依存しない。
## 60Hz の tick() と、行動コマンド（move / rotate / hold / hard_drop）で動かす。

signal event(kind: String, data: Dictionary)

enum Phase { PLAYING, CLEARING, ARE, GAME_OVER, CLEARED }
enum Spin { NONE, MINI, FULL }

const NEXT_COUNT := 5
const LOCK_DELAY := 30          # 0.5秒
const MAX_LOCK_RESETS := 15
const SPAWN_POS := Vector2i(3, Board.HIDDEN_ROWS - 2)
const SOFT_DROP_POINTS := 1
const HARD_DROP_POINTS := 2

const LINE_POINTS := [0, 100, 300, 500, 800]
const TSPIN_POINTS := [400, 800, 1200, 1600]
const MINI_POINTS := [100, 200, 400]
const PERFECT_CLEAR_POINTS := [0, 800, 1200, 1800, 2000]
const B2B_TETRIS_PC_POINTS := 3200
# 対戦用の送りライン（ガイドライン準拠）
const LINE_ATTACK := [0, 0, 1, 2, 4]
const TSPIN_ATTACK := [0, 2, 4, 6]
const MINI_ATTACK := [0, 0, 1]
const COMBO_ATTACK := [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5]
const PERFECT_CLEAR_ATTACK := 10
const MAX_GARBAGE_PER_LOCK := 8     # 1回にせり上がる最大行数（残りは持ち越し）
const GARBAGE_HOLE_CHANGE := 0.7    # 次の攻撃で穴の列が変わる確率

# 設定（フレーム単位）
var are_frames := 0
var line_clear_frames := 18
var soft_drop_factor := 20.0
var fixed_level := 0            # 0 以外なら落下速度をこのレベルで固定（40ライン用）
var line_goal := 0              # 0 以外ならこのライン数でクリア
var allow_hold := true          # false ならホールドできない（Tスピン練習）

var board := Board.new()
var bag: Bag
var phase := Phase.ARE
var ticks := 0

# 操作中のミノ
var piece := PieceData.NONE
var rot := 0
var pos := Vector2i.ZERO
var hold_piece := PieceData.NONE
var hold_used := false

var soft_dropping := false
var _gravity_acc := 0.0
var _lock_timer := 0
var _lock_resets := 0
var _lowest_y := 0
var _last_was_rotation := false
var _last_kick_index := 0
var _phase_timer := 0
var _pending_rows: Array[int] = []
var _buffered_rotation := 0
var _buffered_hold := false

# 対戦: 届いた攻撃の予告。[{"lines": int, "hole": int}, ...] 先に届いたものから順に
var incoming: Array[Dictionary] = []
var _garbage_rng := RandomNumberGenerator.new()
var _last_hole := -1

# 成績
var level := 1
var lines := 0
var score := 0
var combo := -1
var b2b := -1                   # 連続回数。-1 は未継続
var pieces_placed := 0
var lines_sent := 0


func _init(seed_value: int = 0) -> void:
	bag = Bag.new(seed_value)
	if seed_value == 0:
		_garbage_rng.randomize()
	else:
		_garbage_rng.seed = seed_value + 1


func start() -> void:
	_spawn(bag.pop())


## 最初のミノを決めて始める（Tスピン練習）
func start_with(type: int) -> void:
	_spawn(type)


## 時間切れなどで終わらせる（ウルトラ）
func finish() -> void:
	if is_finished():
		return
	phase = Phase.CLEARED
	event.emit("finished", {"ticks": ticks})


func next_queue() -> Array[int]:
	return bag.peek(NEXT_COUNT)


func can_control() -> bool:
	return phase == Phase.PLAYING


func is_finished() -> bool:
	return phase == Phase.GAME_OVER or phase == Phase.CLEARED


func pending_rows() -> Array[int]:
	return _pending_rows


## 消去待ちの進み具合。0（消え始め）→ 1（消え終わり）
func clear_progress() -> float:
	if phase != Phase.CLEARING or line_clear_frames <= 0:
		return 0.0
	return 1.0 - float(_phase_timer) / line_clear_frames


# ---------------- 対戦 ----------------

## 相手からの攻撃を予告に積む。穴の列は攻撃ごとに決める
func receive(lines_count: int) -> void:
	if lines_count <= 0:
		return
	var hole := _last_hole
	if hole < 0 or _garbage_rng.randf() < GARBAGE_HOLE_CHANGE:
		hole = _garbage_rng.randi_range(0, Board.WIDTH - 1)
		if hole == _last_hole:
			hole = (hole + _garbage_rng.randi_range(1, Board.WIDTH - 1)) % Board.WIDTH
	_last_hole = hole
	incoming.append({"lines": lines_count, "hole": hole})
	event.emit("garbage_incoming", {"total": incoming_total()})


func incoming_total() -> int:
	var total := 0
	for g in incoming:
		total += g.lines
	return total


## 自分の攻撃で予告を打ち消す。余った攻撃量を返す
func _cancel_incoming(attack: int) -> int:
	while attack > 0 and not incoming.is_empty():
		var used := mini(attack, incoming[0].lines)
		attack -= used
		incoming[0].lines -= used
		if incoming[0].lines == 0:
			incoming.pop_front()
	return attack


## 予告を最大 MAX_GARBAGE_PER_LOCK 行せり上げる。あふれたら true
func _raise_garbage() -> bool:
	var budget := MAX_GARBAGE_PER_LOCK
	var raised := 0
	var overflow := false
	while budget > 0 and not incoming.is_empty():
		var n := mini(budget, incoming[0].lines)
		overflow = board.add_garbage(n, incoming[0].hole) or overflow
		budget -= n
		raised += n
		incoming[0].lines -= n
		if incoming[0].lines == 0:
			incoming.pop_front()
	if raised > 0:
		event.emit("garbage_rise", {"lines": raised, "total": incoming_total()})
	return overflow


## 操作できない間（消去待ち・出現待ち）に押された回転・ホールドを覚えておく（IRS/IHS）
func buffer_rotation(dir: int) -> void:
	_buffered_rotation = dir


func buffer_hold() -> void:
	_buffered_hold = true


# ---------------- 行動コマンド ----------------

func move(dx: int) -> bool:
	if not can_control() or not board.fits(piece, rot, pos + Vector2i(dx, 0)):
		return false
	pos.x += dx
	_last_was_rotation = false
	_on_moved()
	event.emit("move", {})
	return true


## dir: 1=右回転, -1=左回転
func rotate(dir: int) -> bool:
	if not can_control():
		return false
	var to_rot := (rot + dir + 4) % 4
	var kicks := PieceData.kicks(piece, rot, to_rot)
	for i in kicks.size():
		var p: Vector2i = pos + kicks[i]
		if board.fits(piece, to_rot, p):
			rot = to_rot
			pos = p
			_last_was_rotation = true
			_last_kick_index = i
			_on_moved()
			_update_lowest()
			# この位置で固定したらスピンになるか（回した瞬間の効果音用）
			event.emit("rotate", {"kick": i, "spin": _detect_spin().spin})
			return true
	return false


func hold() -> bool:
	if not can_control() or hold_used or not allow_hold:
		return false
	var current := piece
	hold_used = true
	if hold_piece == PieceData.NONE:
		hold_piece = current
		_spawn(bag.pop(), true)
	else:
		var next := hold_piece
		hold_piece = current
		_spawn(next, true)
	event.emit("hold", {})
	return true


func hard_drop() -> void:
	if not can_control():
		return
	var dist := 0
	while board.fits(piece, rot, pos + Vector2i(0, 1)):
		pos.y += 1
		dist += 1
	if dist > 0:
		_last_was_rotation = false
	score += dist * HARD_DROP_POINTS
	event.emit("hard_drop", {"distance": dist, "piece": piece, "rot": rot, "pos": pos})
	_lock()


## その場で一番下まで落とす（固定はしない）。ソフトドロップを最速にしたのと同じ。CPU が使う
func sonic_drop() -> void:
	if not can_control():
		return
	var dist := 0
	while board.fits(piece, rot, pos + Vector2i(0, 1)):
		pos.y += 1
		dist += 1
	if dist > 0:
		_last_was_rotation = false
		score += dist * SOFT_DROP_POINTS
		_update_lowest()
		event.emit("fall", {"soft": true})


func ghost_y() -> int:
	var y := pos.y
	while board.fits(piece, rot, Vector2i(pos.x, y + 1)):
		y += 1
	return y


func is_grounded() -> bool:
	return not board.fits(piece, rot, pos + Vector2i(0, 1))


# ---------------- 時間経過 ----------------

func tick() -> void:
	if is_finished():
		return
	ticks += 1
	match phase:
		Phase.PLAYING:
			_tick_playing()
		Phase.CLEARING:
			_phase_timer -= 1
			if _phase_timer <= 0:
				board.remove_rows(_pending_rows)
				event.emit("rows_collapsed", {"rows": _pending_rows})
				_pending_rows = []
				_enter_are()
		Phase.ARE:
			_phase_timer -= 1
			if _phase_timer <= 0:
				_spawn(bag.pop())


func _tick_playing() -> void:
	var g := gravity()
	if soft_dropping:
		g *= soft_drop_factor
	_gravity_acc += g
	while _gravity_acc >= 1.0:
		_gravity_acc -= 1.0
		if not board.fits(piece, rot, pos + Vector2i(0, 1)):
			_gravity_acc = 0.0
			break
		pos.y += 1
		_last_was_rotation = false
		if soft_dropping:
			score += SOFT_DROP_POINTS
		_update_lowest()
		event.emit("fall", {"soft": soft_dropping})

	if is_grounded():
		_lock_timer += 1
		if _lock_timer >= LOCK_DELAY:
			_lock()
	else:
		_lock_timer = 0


## 1フレームに落ちる行数（G）
func gravity() -> float:
	var lv := fixed_level if fixed_level > 0 else level
	var seconds_per_row := pow(0.8 - (lv - 1) * 0.007, lv - 1)
	return 1.0 / (seconds_per_row * 60.0)


# ---------------- 内部処理 ----------------

func _on_moved() -> void:
	# 接地中の移動・回転で固定までの時間を延ばす（15回まで）
	if _lock_resets < MAX_LOCK_RESETS:
		if _lock_timer > 0 or is_grounded():
			_lock_resets += 1
		_lock_timer = 0


func _update_lowest() -> void:
	if pos.y > _lowest_y:
		_lowest_y = pos.y
		_lock_resets = 0
		_lock_timer = 0


func _spawn(type: int, from_hold := false) -> void:
	piece = type
	rot = 0
	pos = SPAWN_POS
	if type == PieceData.O:
		pos.x += 1
	_gravity_acc = 0.0
	_lock_timer = 0
	_lock_resets = 0
	_lowest_y = pos.y
	_last_was_rotation = false
	phase = Phase.PLAYING

	if not from_hold and _buffered_hold and not hold_used:
		_buffered_hold = false
		hold()
		return
	_buffered_hold = false

	if _buffered_rotation != 0:
		var to_rot := (rot + _buffered_rotation + 4) % 4
		if board.fits(piece, to_rot, pos):
			rot = to_rot
		_buffered_rotation = 0

	if not board.fits(piece, rot, pos):
		_game_over("block_out")
		return
	# 出現したらすぐ1段下げる（ガイドライン準拠）
	if board.fits(piece, rot, pos + Vector2i(0, 1)):
		pos.y += 1
		_lowest_y = pos.y
	event.emit("spawn", {"piece": piece})


func _lock() -> void:
	var spin_info := _detect_spin()
	board.place(piece, rot, pos)
	pieces_placed += 1
	hold_used = false

	var lock_out := true
	for c in PieceData.cells(piece, rot):
		if pos.y + c.y >= Board.HIDDEN_ROWS:
			lock_out = false
	event.emit("lock", {"piece": piece, "rot": rot, "pos": pos})

	var rows := board.full_rows()
	var cleared := rows.size()
	var result := _score_clear(cleared, spin_info)
	if cleared > 0 or spin_info.spin != Spin.NONE:
		event.emit("clear", result)

	if lock_out and cleared == 0:
		_game_over("lock_out")
		return

	if cleared > 0:
		# 攻撃はまず予告を相殺し、余りを相手に送る
		var attack: int = result.attack
		var remaining := _cancel_incoming(attack)
		if attack > 0:
			lines_sent += remaining
			event.emit("attack", {"lines": remaining, "cancelled": attack - remaining, "total": incoming_total()})
	elif _raise_garbage():
		_game_over("top_out")
		return

	if cleared > 0:
		lines += cleared
		if fixed_level == 0:
			level = mini(1 + lines / 10, 15)
		if line_goal > 0 and lines >= line_goal:
			board.remove_rows(rows)
			phase = Phase.CLEARED
			event.emit("finished", {"ticks": ticks})
			return
		_pending_rows = rows
		phase = Phase.CLEARING
		_phase_timer = line_clear_frames
		if _phase_timer <= 0:
			board.remove_rows(rows)
			_pending_rows = []
			_enter_are()
	else:
		_enter_are()


func _enter_are() -> void:
	phase = Phase.ARE
	_phase_timer = are_frames
	if _phase_timer <= 0:
		_spawn(bag.pop())


func _game_over(reason: String) -> void:
	phase = Phase.GAME_OVER
	event.emit("game_over", {"reason": reason})


## 固定する直前に呼ぶ。戻り値は {"spin": Spin, "piece": int}
func _detect_spin() -> Dictionary:
	var none := {"spin": Spin.NONE, "piece": piece}
	if not _last_was_rotation or piece == PieceData.O:
		return none

	if piece == PieceData.T:
		# 3x3 ボックスの四隅。正面側の2隅は回転状態で決まる
		var corners := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2), Vector2i(0, 2)]
		var filled := []
		for c in corners:
			filled.append(board.is_blocked(pos.x + c.x, pos.y + c.y))
		var count := filled.count(true)
		if count < 3:
			return none
		# rot 0: 上(0,1) / 1: 右(1,2) / 2: 下(2,3) / 3: 左(3,0)
		var front_a: bool = filled[rot]
		var front_b: bool = filled[(rot + 1) % 4]
		if (front_a and front_b) or _last_kick_index == 4:
			return {"spin": Spin.FULL, "piece": piece}
		return {"spin": Spin.MINI, "piece": piece}

	# T 以外のミノはスピン扱いしない（ガイドライン準拠。得点・攻撃・B2B も普通の消去と同じ）
	return none


func _score_clear(cleared: int, spin_info: Dictionary) -> Dictionary:
	var spin: int = spin_info.spin
	var spin_piece: int = spin_info.piece
	var points := 0
	var attack := 0

	if spin == Spin.FULL:
		points = TSPIN_POINTS[cleared]
		attack = TSPIN_ATTACK[cleared]
	elif spin == Spin.MINI:
		points = maxi(MINI_POINTS[mini(cleared, 2)], LINE_POINTS[cleared])
		attack = maxi(MINI_ATTACK[mini(cleared, 2)], LINE_ATTACK[cleared])
	else:
		points = LINE_POINTS[cleared]
		attack = LINE_ATTACK[cleared]

	var difficult := cleared == 4 or (spin != Spin.NONE and cleared > 0)
	var is_b2b := false
	if cleared > 0:
		if difficult:
			b2b += 1
			is_b2b = b2b >= 1
		else:
			b2b = -1
	if is_b2b:
		points = points * 3 / 2
		attack += 1

	if cleared > 0:
		combo += 1
	else:
		combo = -1
	if combo >= 1:
		points += 50 * combo
		attack += COMBO_ATTACK[mini(combo, COMBO_ATTACK.size() - 1)]

	var perfect := false
	if cleared > 0 and _only_full_rows_left():
		perfect = true
		if cleared == 4 and is_b2b:
			points += B2B_TETRIS_PC_POINTS
		else:
			points += PERFECT_CLEAR_POINTS[cleared]
		attack = PERFECT_CLEAR_ATTACK

	score += points * level
	return {
		"lines": cleared,
		"spin": spin,
		"piece": spin_piece,
		"b2b": b2b if is_b2b else 0,
		"combo": maxi(combo, 0),
		"perfect": perfect,
		"points": points * level,
		"attack": attack,
	}


## 揃った行を消したら盤面が空になるか（パーフェクトクリア判定）
func _only_full_rows_left() -> bool:
	for row in board.grid:
		if row.has(PieceData.NONE) and row.count(PieceData.NONE) != Board.WIDTH:
			return false
	return true
