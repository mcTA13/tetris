class_name RenPractice
extends Practice
## REN 練習（左 4 列）。右 6 列を中段まで積み、左 4 列の底に 3 マス残した形から始める。
## 消した分だけ右 6 列を積み足して、いつも中段の高さを保つ（下からせり上げると左 4 列の底に穴ができるので、
## 右 6 列の上に足す）。ゲームオーバーまで続け、最大 REN を記録する。

const WELL := 4                 # 左の空けておく列数
const STACK_H := 10             # 右 6 列の高さ
# 左 4 列の底に残しておく 3 マス（よく使う形）。(x, 下からの段)
const RESIDUES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)],
]

var _max_ren := 0
var _new_record := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func setup(game: GameState) -> void:
	_max_ren = 0
	_new_record = false
	_refill(game.board)
	for c in RESIDUES[_rng.randi_range(0, RESIDUES.size() - 1)]:
		game.board.grid[Board.HEIGHT - 1 - c.y][c.x] = PieceData.GARBAGE


func continuous() -> bool:
	return true


func judge(kind: String, data: Dictionary, game: GameState) -> String:
	match kind:
		"clear":
			_max_ren = maxi(_max_ren, data.combo)
		"rows_collapsed":
			_refill(game.board)
		"game_over":
			_new_record = App.submit_ren(_max_ren)
	return ""


## 右 6 列を下から STACK_H 段まで埋める（その段が全部埋まってしまうマスは埋めない）
func _refill(board: Board) -> void:
	for y in range(Board.HEIGHT - STACK_H, Board.HEIGHT):
		var row: PackedByteArray = board.grid[y]
		for x in range(WELL, Board.WIDTH):
			if row[x] != PieceData.NONE:
				continue
			if row.count(PieceData.NONE) == 1:
				break
			row[x] = PieceData.GARBAGE
		board.grid[y] = row


func stats() -> Array:
	return [[Loc.t("ren_max"), str(_max_ren)], [Loc.t("best"), str(App.ren_best)]]


func result_lines() -> Array:
	return ["%s %d" % [Loc.t("ren_max"), _max_ren], Loc.t("new_record") if _new_record else "%s %d" % [Loc.t("best"), App.ren_best]]
