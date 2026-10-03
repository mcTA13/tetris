class_name PcPractice
extends Practice
## パフェ練習。下 4 段の途中まで積んである盤面から、NEXT のミノで全部消せたら成功。
## 4 段より上に積んだり、決められた数を置いても消しきれなかったら失敗。

const MIN_PIECES := 4           # 自分で置くミノの数（課題ごとにこの間でランダム）
const MAX_PIECES := 6

var _rng := RandomNumberGenerator.new()
var _drill := {}


func _init() -> void:
	_rng.randomize()
	_new_drill()


func _new_drill() -> void:
	_drill = PcDrills.generate(_rng, _rng.randi_range(MIN_PIECES, MAX_PIECES))


func setup(game: GameState) -> void:
	var src: Board = _drill.board
	for y in Board.HEIGHT:
		game.board.grid[y] = src.grid[y].duplicate()


func start(game: GameState) -> void:
	game.start_with_queue(_drill.queue)


func judge(kind: String, _data: Dictionary, game: GameState) -> String:
	if kind != "lock":
		return ""
	# 置いた時点で、すべての段が「空」か「埋まっている」なら全消し
	var perfect := true
	var top := Board.HEIGHT - (PcDrills.ROWS - game.lines)
	var over := false
	for y in Board.HEIGHT:
		var filled: int = Board.WIDTH - game.board.grid[y].count(PieceData.NONE)
		if filled != 0 and filled != Board.WIDTH:
			perfect = false
		if filled != 0 and y < top:
			over = true
	if perfect:
		return _result(true)
	if over or game.pieces_placed >= _drill.steps.size():
		return _result(false)
	return ""


func advance(success: bool) -> void:
	super.advance(success)
	if success:
		_new_drill()


## お手本: 手順どおりに来ていれば、次に置く場所を見せる
func guide(game: GameState) -> Dictionary:
	if not show_hint or game.pieces_placed >= _drill.steps.size():
		return {}
	var step: Dictionary = _drill.steps[game.pieces_placed]
	if step.type != game.piece or CpuBrain.rows_from(game.board) != step.rows:
		return {}
	return {"type": step.type, "x": step.x, "y": step.y, "rot": step.rot, "hold": false}


func stats() -> Array:
	return [[Loc.t("pc_pieces"), str(_drill.steps.size())]] + super.stats()
