extends Node
## 40ラインのアシスト（6-3 積み）のガイドどおりに自動で置き続け、積み方を確かめる
## 実行: godot --headless --path . tests/assist_follow.tscn

var scene: Node
var placed_for := -1


func _ready() -> void:
	App.mode = App.Mode.SPRINT_40L
	App.settings.assist = "six_three"  # 保存はしない
	scene = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(25.0).timeout
	var g: GameState = scene.game
	print("pieces=%d lines=%d finished=%s" % [g.pieces_placed, g.lines, g.is_finished()])
	for y in range(Board.HEIGHT - 12, Board.HEIGHT):
		var line := ""
		for x in Board.WIDTH:
			line += "#" if g.board.grid[y][x] != PieceData.NONE else "."
		print(line)
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	if scene == null:
		return
	var g: GameState = scene.game
	var guide: Dictionary = scene._field._guide
	if guide.is_empty() or not g.can_control():
		return
	if guide.hold:
		g.hold()  # ホールドすると新しいおすすめが来る
		return
	# ガイドはスピンの種類を持たないので、どの種類でも行ければよい
	var path = null
	for spin in [GameState.Spin.NONE, GameState.Spin.MINI, GameState.Spin.FULL]:
		var target := {"x": guide.pos.x, "y": guide.pos.y, "rot": guide.rot, "spin": spin}
		path = CpuBrain.path_to(CpuBrain.rows_from(g.board), g.piece, Vector3i(g.pos.x, g.pos.y, g.rot), target)
		if path != null:
			break
	if path == null:
		print("unreachable guide: ", guide)
		g.hard_drop()
		return
	for a in path:
		match a:
			CpuBrain.Act.LEFT: g.move(-1)
			CpuBrain.Act.RIGHT: g.move(1)
			CpuBrain.Act.CW: g.rotate(1)
			CpuBrain.Act.CCW: g.rotate(-1)
			CpuBrain.Act.DROP: g.sonic_drop()
	g.hard_drop()
