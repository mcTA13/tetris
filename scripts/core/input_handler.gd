class_name InputHandler
extends RefCounted
## ボタンの状態（1 tick 分）を GameState への行動コマンドに変換する。DAS/ARR を担当。
## Godot の Input には触らない（テストと CPU 差し替えのため）。

# 設定（フレーム単位）
var das := 10
var arr := 2
var das_cut_on_switch := true   # 左右を切り替えたら溜めをリセットする

var _game: GameState
var _prev := {}
var _dir := 0                   # 今効いている左右方向（-1 / 0 / 1）
var _das_timer := 0
var _arr_timer := 0
var _first_shift_pending := false


func _init(game: GameState) -> void:
	_game = game


## 開始時点で押しっぱなしのボタンを「押した」と扱わないようにする（左右は DAS を溜めるので除く）
func prime(held: Dictionary) -> void:
	_prev = held.duplicate()
	_prev.erase("left")
	_prev.erase("right")


## held: {"left","right","soft_drop","hard_drop","rotate_cw","rotate_ccw","hold"} → bool
## pressed: この tick の間に押された（短いタップの取りこぼし防止）
func update(held: Dictionary, pressed: Dictionary) -> void:
	var just := func(a: String) -> bool:
		return pressed.get(a, false) or (held.get(a, false) and not _prev.get(a, false))

	_update_direction(held, just)

	if _game.can_control():
		if just.call("hold"):
			_game.hold()
		if just.call("rotate_cw"):
			_game.rotate(1)
		if just.call("rotate_ccw"):
			_game.rotate(-1)
		_apply_shift()
		_game.soft_dropping = held.get("soft_drop", false)
		if just.call("hard_drop"):
			_game.hard_drop()
	else:
		# 消去待ち・出現待ち中の入力は次のミノに持ち越す（IRS/IHS）
		if just.call("hold"):
			_game.buffer_hold()
		if just.call("rotate_cw"):
			_game.buffer_rotation(1)
		if just.call("rotate_ccw"):
			_game.buffer_rotation(-1)
		_game.soft_dropping = false

	_prev = held.duplicate()


func _update_direction(held: Dictionary, just: Callable) -> void:
	var left: bool = held.get("left", false)
	var right: bool = held.get("right", false)
	var new_dir := _dir
	# 後から押した方向を優先
	if just.call("left"):
		new_dir = -1
	elif just.call("right"):
		new_dir = 1
	elif _dir == -1 and not left:
		new_dir = 1 if right else 0
	elif _dir == 1 and not right:
		new_dir = -1 if left else 0

	if new_dir != _dir:
		var was_switch := _dir != 0 and new_dir != 0
		_dir = new_dir
		if not was_switch or das_cut_on_switch:
			_das_timer = 0
		_arr_timer = 0
		_first_shift_pending = _dir != 0
	elif _dir != 0:
		_das_timer += 1


func _apply_shift() -> void:
	if _dir == 0:
		return
	if _first_shift_pending:
		_first_shift_pending = false
		_game.move(_dir)
		return
	if _das_timer < das:
		return
	if arr == 0:
		while _game.move(_dir):
			pass
		return
	if _das_timer == das:
		_arr_timer = 0
		_game.move(_dir)
		return
	_arr_timer += 1
	if _arr_timer >= arr:
		_arr_timer = 0
		_game.move(_dir)
