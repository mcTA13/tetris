extends Node
## 練習モードの部品の確認（Loc・App などの autoload を使うので、シーンとして動かす）
## 実行: godot --headless --path . tests/practice_check.tscn

var _checks := 0
var _failed := 0


func _ready() -> void:
	test_spin_practice_judges_placement()
	test_ren_practice_keeps_stack()
	print("practice: %d checks, %d failed" % [_checks, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failed += 1
		print("FAIL: ", msg)


func test_spin_practice_judges_placement() -> void:
	var p := SpinPractice.new("spin_sz")
	var g := GameState.new(1)
	p.setup(g)
	p.start(g)
	var sol := SpinDrills.solution(p.drill(), g.board, Vector3i(g.pos.x, g.pos.y, g.rot))
	var ok := p.judge("lock", {"piece": p.drill().piece, "rot": sol.rot, "pos": Vector2i(sol.x, sol.y)}, g)
	var ng := p.judge("lock", {"piece": p.drill().piece, "rot": 0, "pos": Vector2i(0, 30)}, g)
	check(ok == "success" and ng == "fail", "スピン練習: 正解の場所なら成功、違えば失敗 (%s, %s)" % [ok, ng])
	check(p.stats()[1][1] == "1 / 2", "スピン練習: 成功数を数える (%s)" % p.stats()[1][1])


func test_ren_practice_keeps_stack() -> void:
	var p := RenPractice.new()
	var g := GameState.new(1)
	p.setup(g)
	var right_full := true
	for y in range(Board.HEIGHT - RenPractice.STACK_H, Board.HEIGHT):
		for x in range(RenPractice.WELL, Board.WIDTH):
			right_full = right_full and g.board.grid[y][x] != PieceData.NONE
	check(right_full, "REN練習: 右 6 列が中段まで埋まっている")
	var well := 0
	for y in Board.HEIGHT:
		for x in RenPractice.WELL:
			if g.board.grid[y][x] != PieceData.NONE:
				well += 1
	check(well == 3, "REN練習: 左 4 列の底に 3 マス残してある (%d)" % well)
	# 一番下の段を消したあと、右側が積み足される
	g.board.remove_rows([Board.HEIGHT - 1])
	p.judge("rows_collapsed", {}, g)
	var top_ok := true
	for x in range(RenPractice.WELL, Board.WIDTH):
		top_ok = top_ok and g.board.grid[Board.HEIGHT - RenPractice.STACK_H][x] != PieceData.NONE
	check(top_ok, "REN練習: 消したら右 6 列を中段まで積み足す")
