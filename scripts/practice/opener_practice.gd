class_name OpenerPractice
extends Practice
## 開幕テンプレ練習。空の盤面から、テンプレどおりの順番で出てくるミノを決められた場所に置き、
## 最後の Tスピン（パフェ開幕は全消し）まで決めたら成功。違う場所に置いたらその時点で失敗。

var _id: String
var _rng := RandomNumberGenerator.new()
var _drill := {}
var _next := 0                  # 次に置く手順


func _init(id: String) -> void:
	_id = id
	_rng.randomize()
	_drill = OpenerDrills.build(_id, _rng)


func setup(_game: GameState) -> void:
	_next = 0


func start(game: GameState) -> void:
	game.start_with_queue(_drill.queue)


func judge(kind: String, data: Dictionary, _game: GameState) -> String:
	if kind != "lock":
		return ""
	var step: Dictionary = _drill.steps[_next]
	if data.piece != step.type or SpinDrills.cells_at(data.piece, data.rot, data.pos) != step.cells:
		return _result(false)
	_next += 1
	return _result(true) if _next >= _drill.steps.size() else ""


func advance(success: bool) -> void:
	super.advance(success)
	if success:
		_drill = OpenerDrills.build(_id, _rng)  # 次は別の置く順番で


func guide(game: GameState) -> Dictionary:
	if not show_hint or _next >= _drill.steps.size():
		return {}
	var step: Dictionary = _drill.steps[_next]
	if step.type != game.piece:
		return {}
	return {"type": step.type, "x": step.x, "y": step.y, "rot": step.rot, "hold": false}


func stats() -> Array:
	return [[Loc.t("opener_progress"), "%d / %d" % [_next, _drill.steps.size()]]] + super.stats()
