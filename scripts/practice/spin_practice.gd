class_name SpinPractice
extends Practice
## スピン練習。課題の盤面に 1 個だけミノを置き、決められた置き場所に置けたら成功。
## 種類: spin_t（T）/ spin_sz（S・Z）/ spin_lj（L・J）/ spin_random（全部からランダム）

var _drills: Array
var _index := 0
var _random := false
var _rng := RandomNumberGenerator.new()


func _init(kind: String) -> void:
	_rng.randomize()
	match kind:
		"spin_sz":
			_drills = SpinDrills.all(["sz"])
		"spin_lj":
			_drills = SpinDrills.all(["lj"])
		"spin_random":
			_drills = SpinDrills.all()
			_random = true
			_index = _rng.randi_range(0, _drills.size() - 1)
		_:
			_drills = SpinDrills.all(["t"])


func drill() -> Dictionary:
	return _drills[_index]


func setup(game: GameState) -> void:
	SpinDrills.apply(drill(), game.board)


func start(game: GameState) -> void:
	game.start_with(drill().piece)


func allow_hold() -> bool:
	return false


## 置いたマスが正解の置き場所と同じなら成功
func judge(kind: String, data: Dictionary, game: GameState) -> String:
	if kind != "lock":
		return ""
	var sol := _solution(game)
	if sol.is_empty():
		return _result(false)
	var placed := SpinDrills.cells_at(data.piece, data.rot, data.pos)
	return _result(placed == SpinDrills.cells_at(data.piece, sol.rot, Vector2i(sol.x, sol.y)))


func advance(success: bool) -> void:
	super.advance(success)
	if not success:
		return
	if _random:
		var next := _rng.randi_range(0, _drills.size() - 2)
		_index = next if next < _index else next + 1  # 同じ課題が続かないように
	else:
		_index = (_index + 1) % _drills.size()


func guide(game: GameState) -> Dictionary:
	if not show_hint:
		return {}
	var sol := SpinDrills.solution(drill(), game.board, Vector3i(game.pos.x, game.pos.y, game.rot))
	if sol.is_empty():
		return {}
	return {"type": drill().piece, "x": sol.x, "y": sol.y, "rot": sol.rot, "hold": false}


func stats() -> Array:
	var side := Loc.t("practice_left") if drill().side == "left" else Loc.t("practice_right")
	return [[Loc.t("practice_drill"), "%s %s" % [drill().name, side]]] + super.stats()


## 置く前の盤面での正解（置いたあとの盤面ではミノが入ってしまっているので、ミノを除いて探す）
func _solution(_game: GameState) -> Dictionary:
	var board := Board.new()
	SpinDrills.apply(drill(), board)
	return SpinDrills.solution(drill(), board, Vector3i(GameState.SPAWN_POS.x, GameState.SPAWN_POS.y, 0))
