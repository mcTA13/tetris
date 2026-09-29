extends Node2D
## ゲーム画面。モードは App.mode。演出の動きは Effects、描き方はスキン

const CELL := 30
const BOARD_ORIGIN := Vector2(490, 70)
const HOLD_RECT := Rect2(318, 70, 148, 124)
const NEXT_RECT := Rect2(814, 70, 148, 440)
const STATS_RECT := Rect2(298, 214, 168, 0)  # 高さは項目数で決まる
const STAT_H := 62
const LOCK_FLASH_TIME := 0.15
const SHOW_HIDDEN_ROWS := 2     # 盤面の上にはみ出して見せる行数
const SPIN_NAMES := ["", "MINI ", ""]
const LINE_NAMES := ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS"]
const READY_TICKS := 45
const GO_TICKS := 30
const MARATHON_GOAL := 150
const COUNTER_POS := Vector2(814, 548)
const TSPIN_PITCH := 1.26       # 回転音を約4半音上げる
const TSPIN_MINI_PITCH := 1.12  # 約2半音

var game: GameState
var input: InputHandler
var paused := false
var _countdown := 0             # READY 表示の残り tick
var _go_timer := 0
var _new_record := false
var _time := 0.0
var _message := ""
var _message_timer := 0.0
var _lock_flash := {}           # セル座標 → 残り時間
var _fx := Effects.new()
var _board_origin := BOARD_ORIGIN  # ハードドロップで沈むぶんを含めた盤面の位置
var _hard_dropped := false
var _last_level := 1


func _ready() -> void:
	_new_game()


func _new_game() -> void:
	game = GameState.new()
	if App.mode == App.Mode.SPRINT_40L:
		game.fixed_level = 1
		game.line_goal = 40
	else:
		game.line_goal = MARATHON_GOAL
	game.event.connect(_on_game_event)
	input = InputHandler.new(game)
	App.configure(game, input)
	input.prime(InputSetup.poll()[0])
	InputSetup.clear_pressed()
	paused = false
	_new_record = false
	_countdown = READY_TICKS
	_go_timer = 0
	_message = ""
	_lock_flash.clear()
	_fx.clear()
	_hard_dropped = false
	_last_level = game.level
	Sfx.play("ready")


func _physics_process(_delta: float) -> void:
	var state: Array = InputSetup.poll()
	var held: Dictionary = state[0]
	var pressed: Dictionary = state[1]
	if pressed.get("retry", false):
		_new_game()
		return
	if game.is_finished():
		if pressed.get("accept", false):
			_new_game()
		elif pressed.get("back", false):
			_to_title()
		return
	if paused:
		if pressed.get("pause", false) or pressed.get("accept", false):
			paused = false
		elif pressed.get("back", false):
			_to_title()
		return
	if pressed.get("pause", false):
		paused = true
		return

	# READY 中も DAS を溜めたり、回転・ホールドを先行入力できる
	input.update(held, pressed)
	if _countdown > 0:
		_countdown -= 1
		if _countdown == 0:
			game.start()
			_go_timer = GO_TICKS
			Sfx.play("go")
		return
	_go_timer = maxi(_go_timer - 1, 0)
	game.tick()
	if game.level > _last_level:
		_last_level = game.level
		Sfx.play("level_up")
		_fx.queue_popup(["LEVEL UP!", "LEVEL %d" % game.level])


func _to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _process(delta: float) -> void:
	_time += delta
	_message_timer = maxf(_message_timer - delta, 0.0)
	for k in _lock_flash.keys():
		_lock_flash[k] -= delta
		if _lock_flash[k] <= 0.0:
			_lock_flash.erase(k)
	_fx.update(delta, App.skin.fx.particle_gravity)
	position = _fx.screen_offset()
	queue_redraw()


func _on_game_event(kind: String, data: Dictionary) -> void:
	var fx: Dictionary = App.skin.fx
	match kind:
		"move":
			Sfx.play("move")
		"rotate":
			# Tスピンの形に入ったら、回転音を少し高くして知らせる（Mini は控えめに）
			var pitch := 1.0
			if game.piece == PieceData.T and data.spin != GameState.Spin.NONE:
				pitch = TSPIN_PITCH if data.spin == GameState.Spin.FULL else TSPIN_MINI_PITCH
			Sfx.play("rotate", pitch)
		"hold":
			Sfx.play("hold")
		"hard_drop":
			_hard_drop_trail(data)
			_fx.bump(fx.hard_drop_bump)
			Sfx.play("hard_drop")
			InputSetup.vibrate(0.3, 0.0, 0.05)
			_hard_dropped = true
		"lock":
			for c in PieceData.cells(data.piece, data.rot):
				_lock_flash[data.pos + c] = LOCK_FLASH_TIME
			if not _hard_dropped:
				Sfx.play("lock")
			_hard_dropped = false
		"clear":
			_on_clear(data)
		"finished":
			Sfx.play("finish")
			if App.mode == App.Mode.SPRINT_40L:
				_new_record = App.submit_40l(game.ticks)
			else:
				_new_record = App.submit_marathon(game.score)
		"game_over":
			Sfx.play("game_over")
			_fx.shake(6.0)
			if App.mode == App.Mode.MARATHON:
				_new_record = App.submit_marathon(game.score)


func _on_clear(data: Dictionary) -> void:
	var fx: Dictionary = App.skin.fx
	_message = _clear_name(data)
	_message_timer = 1.5

	# 消える行のブロックから粒を飛ばす（この時点ではまだ盤面に残っている）
	var per_cell: int = fx.particles_per_cell * (1 + data.lines / 4)
	for y in game.board.full_rows():
		for x in Board.WIDTH:
			var type: int = game.board.grid[y][x]
			_fx.burst(_cell_rect(Vector2i(x, y)).get_center(), App.skin.piece_colors[type], per_cell, fx.particle_speed)

	var big := false
	if data.perfect:
		Sfx.play("perfect")
		_fx.shake(fx.shake_perfect)
		big = true
	elif data.spin != GameState.Spin.NONE:
		Sfx.play("spin")
		if data.lines > 0:
			_fx.shake(fx.shake_spin)
		big = true
	elif data.lines == 4:
		Sfx.play("tetris")
		_fx.shake(fx.shake_tetris)
		big = true
	elif data.lines > 0:
		Sfx.play("clear%d" % data.lines)

	if big:
		var lines := Array(_message.split("\n")).filter(func(l): return not l.begins_with("REN"))
		_fx.popup(lines)
		_message_timer = 0.0  # 中央に大きく出すので横の表示は出さない
		if data.lines > 0:
			_fx.flash(fx.flash_alpha)
			InputSetup.vibrate(0.6, 0.8, 0.25)
	if data.b2b > 0:
		Sfx.play("b2b")
		_fx.bounce("b2b")
	if data.combo > 0:
		Sfx.play("combo", pow(2.0, mini(data.combo, 12) / 12.0))
		_fx.bounce("ren")


## ハードドロップの残像を、ミノの列ごとに落ち始めから着地まで引く
func _hard_drop_trail(data: Dictionary) -> void:
	if data.distance <= 0:
		return
	var columns := {}
	for c in PieceData.cells(data.piece, data.rot):
		var x: int = data.pos.x + c.x
		var bottom: int = data.pos.y + c.y
		var top: int = bottom - data.distance
		if columns.has(x):
			columns[x] = Vector2i(mini(columns[x].x, top), maxi(columns[x].y, bottom))
		else:
			columns[x] = Vector2i(top, bottom)
	for x in columns:
		var top_rect := _cell_rect(Vector2i(x, maxi(columns[x].x, Board.HIDDEN_ROWS - SHOW_HIDDEN_ROWS)))
		var bottom_rect := _cell_rect(Vector2i(x, columns[x].y))
		_fx.trail(Rect2(top_rect.position, bottom_rect.end - top_rect.position), App.skin.piece_colors[data.piece])


func _clear_name(data: Dictionary) -> String:
	var parts := []
	if data.b2b > 0:
		parts.append("B2B x%d" % data.b2b)
	var title := ""
	if data.spin != GameState.Spin.NONE:
		title = "%s-SPIN %s" % [PieceData.NAMES[data.piece], SPIN_NAMES[data.spin]]
	if data.lines > 0:
		title += LINE_NAMES[data.lines]
	parts.append(title.strip_edges())
	if data.combo > 0:
		parts.append("REN %d" % data.combo)
	if data.perfect:
		parts.append("PERFECT CLEAR")
	return "\n".join(parts)


# ---------------- 描画 ----------------

func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	_board_origin = BOARD_ORIGIN + _fx.board_offset()
	var board_rect := Rect2(_board_origin, Vector2(Board.WIDTH * CELL, Board.VISIBLE_ROWS * CELL))
	skin.draw_board(self, board_rect, CELL)
	_fx.draw_trails(self, skin)

	# 固定済みブロック（消える行は縮みながら消える）
	var clearing := game.pending_rows()
	var progress := game.clear_progress()
	for y in range(Board.HIDDEN_ROWS - SHOW_HIDDEN_ROWS, Board.HEIGHT):
		for x in Board.WIDTH:
			var v: int = game.board.grid[y][x]
			if v == PieceData.NONE:
				continue
			if y in clearing:
				skin.draw_clearing_cell(self, _cell_rect(Vector2i(x, y)), v, progress)
				continue
			var flash: float = _lock_flash.get(Vector2i(x, y), 0.0) / LOCK_FLASH_TIME * 0.7
			_draw_board_cell(Vector2i(x, y), v, UiSkin.CellStyle.NORMAL, flash)

	# ゴーストと操作中のミノ
	if game.can_control():
		var ghost := Vector2i(game.pos.x, game.ghost_y())
		for c in PieceData.cells(game.piece, game.rot):
			_draw_board_cell(ghost + c, game.piece, UiSkin.CellStyle.GHOST)
		for c in PieceData.cells(game.piece, game.rot):
			_draw_board_cell(game.pos + c, game.piece)

	# ホールド
	_draw_box_header(HOLD_RECT, Loc.t("hold"))
	if game.hold_piece != PieceData.NONE:
		var style := UiSkin.CellStyle.DIM if game.hold_used else UiSkin.CellStyle.PREVIEW
		_draw_preview(game.hold_piece, Rect2(HOLD_RECT.position + Vector2(0, 36), Vector2(HOLD_RECT.size.x, 80)), 24, style)

	# ネクスト（先頭だけ大きく）
	_draw_box_header(NEXT_RECT, Loc.t("next"))
	var queue := game.next_queue()
	var y := NEXT_RECT.position.y + 36
	for i in queue.size():
		var h := 90.0 if i == 0 else 76.0
		_draw_preview(queue[i], Rect2(NEXT_RECT.position.x, y, NEXT_RECT.size.x, h), 24 if i == 0 else 19)
		y += h

	_draw_stats()
	_draw_counters()

	# 状態表示（大技の文字はこれより上に重ねる）
	var center := board_rect.get_center()
	if _countdown > 0:
		_draw_banner(center, [Loc.t("ready")])
	elif _go_timer > 0 and not game.is_finished():
		_draw_banner(center, [Loc.t("go")])
	_fx.draw_particles(self, skin)
	_fx.draw_popups(self, skin, center + Vector2(0, -60))
	_fx.draw_flash(self, skin, Vector2(1280, 720))
	if game.is_finished():
		_draw_result(center)
	elif paused:
		_draw_banner(center, [Loc.t("pause"), "",
			"%s: %s" % [Loc.t("resume"), _pad_hint("accept")],
			"%s: %s" % [Loc.t("to_title"), _pad_hint("back")],
			"%s: %s" % [Loc.t("retry"), _pad_hint("retry")]])
	var hint := Loc.t("hint_game") % [InputSetup.action_hint("retry"), InputSetup.action_hint("pause")]
	skin.draw_text(self, Vector2(24, 700), hint, 15, "text")


func _draw_stats() -> void:
	var skin: UiSkin = App.skin
	var seconds := game.ticks / 60.0
	var pps := game.pieces_placed / seconds if seconds > 0 else 0.0
	var stats := []
	if App.mode == App.Mode.SPRINT_40L:
		stats = [[Loc.t("time"), App.format_time(game.ticks)], [Loc.t("lines"), "%d / 40" % mini(game.lines, 40)], [Loc.t("pps"), "%.2f" % pps]]
	else:
		stats = [[Loc.t("score"), str(game.score)], [Loc.t("level"), str(game.level)],
			[Loc.t("lines"), "%d / %d" % [game.lines, MARATHON_GOAL]], [Loc.t("time"), App.format_time(game.ticks)]]
	var rect := STATS_RECT
	rect.size.y = stats.size() * STAT_H + 16
	skin.draw_panel(self, rect)
	for i in stats.size():
		var top := rect.position.y + 10 + i * STAT_H
		skin.draw_text(self, Vector2(rect.position.x + 16, top + 20), stats[i][0], 15, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		skin.draw_text(self, Vector2(rect.position.x + 16, top + 50), stats[i][1], 26, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)

	# 直前の消し方（第5段階で演出を作り込む）
	if _message_timer > 0.0:
		var alpha := minf(_message_timer / 0.3, 1.0)
		var ty := rect.end.y + 44
		for line in _message.split("
"):
			var color := Color(skin.colors.highlight, alpha)
			skin.draw_text(self, Vector2(rect.position.x - 20, ty), line, 24, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 40, true)
			ty += 32


func _draw_result(center: Vector2) -> void:
	var lines := []
	var seconds := game.ticks / 60.0
	if App.mode == App.Mode.SPRINT_40L:
		if game.phase == GameState.Phase.CLEARED:
			lines = [Loc.t("finish"), App.format_time(game.ticks), "PPS %.2f" % (game.pieces_placed / maxf(seconds, 1.0 / 60.0))]
			lines.append(Loc.t("new_record") if _new_record else "%s %s" % [Loc.t("best"), App.format_time(App.best_40l_ticks)])
		else:
			lines = [Loc.t("game_over"), "%s %d / 40" % [Loc.t("lines"), game.lines]]
	else:
		lines = [Loc.t("complete") if game.phase == GameState.Phase.CLEARED else Loc.t("game_over"),
			"%s %d" % [Loc.t("score"), game.score],
			"%s %d  %s %d" % [Loc.t("level"), game.level, Loc.t("lines"), game.lines]]
		lines.append(Loc.t("new_record") if _new_record else "%s %d" % [Loc.t("high_score"), App.marathon_best_score])
	lines.append_array(["",
		"%s: %s / %s" % [Loc.t("retry"), _pad_hint("accept"), _pad_hint("retry")],
		"%s: %s" % [Loc.t("to_title"), _pad_hint("back")]])
	_draw_banner(center, lines)


func _draw_counters() -> void:
	var y := COUNTER_POS.y
	if game.combo >= 1:
		App.skin.draw_counter(self, Vector2(COUNTER_POS.x, y), "REN", str(game.combo), _fx.bounce_amount("ren"))
		y += 56
	if game.b2b >= 1:
		App.skin.draw_counter(self, Vector2(COUNTER_POS.x, y), "B2B", "x%d" % game.b2b, _fx.bounce_amount("b2b"))


func _cell_rect(cell: Vector2i) -> Rect2:
	var row := cell.y - Board.HIDDEN_ROWS
	return Rect2(_board_origin + Vector2(cell.x * CELL, row * CELL), Vector2(CELL, CELL))


func _draw_board_cell(cell: Vector2i, type: int, style := UiSkin.CellStyle.NORMAL, flash := 0.0) -> void:
	if cell.y - Board.HIDDEN_ROWS < -SHOW_HIDDEN_ROWS:
		return
	App.skin.draw_cell(self, _cell_rect(cell), type, style, flash)


func _draw_box_header(rect: Rect2, title: String) -> void:
	App.skin.draw_panel(self, rect)
	App.skin.draw_text(self, Vector2(rect.position.x, rect.position.y + 30), title, 20, "text", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## area の中央にミノを描く
func _draw_preview(type: int, area: Rect2, cell: float, style := UiSkin.CellStyle.PREVIEW) -> void:
	var cells := PieceData.cells(type, 0)
	var min_c := Vector2(99, 99)
	var max_c := Vector2(-99, -99)
	for c in cells:
		min_c = min_c.min(Vector2(c))
		max_c = max_c.max(Vector2(c))
	var size := (max_c - min_c + Vector2.ONE) * cell
	var origin := area.get_center() - size / 2.0 - min_c * cell
	for c in cells:
		App.skin.draw_cell(self, Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), type, style)


## コントローラーのボタン名だけ（バナー内は短く）
func _pad_hint(action: String) -> String:
	var buttons := InputSetup.bindings_of("pad", action)
	return InputSetup.button_label(buttons[0]) if buttons.size() > 0 else "---"


func _draw_banner(center: Vector2, lines: Array) -> void:
	var skin: UiSkin = App.skin
	var w := 360.0
	var line_h := 36.0
	var first_h := 58.0
	var h := first_h + (lines.size() - 1) * line_h + 24
	var rect := Rect2(center.x - w / 2, center.y - h / 2, w, h)
	skin.draw_panel(self, rect)
	skin.draw_text(self, Vector2(rect.position.x, rect.position.y + 50), lines[0], 40, "highlight", HORIZONTAL_ALIGNMENT_CENTER, w, true)
	for i in range(1, lines.size()):
		var role := "highlight" if lines[i] == Loc.t("new_record") else "text"
		skin.draw_text(self, Vector2(rect.position.x, rect.position.y + first_h + 12 + i * line_h), lines[i], 22, role, HORIZONTAL_ALIGNMENT_CENTER, w, true)
