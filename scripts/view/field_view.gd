class_name FieldView
extends Node2D
## 1人分の盤面（盤面・ミノ・ホールド・NEXT・予告ゲージ・演出）を描く。
## 1人用画面と対戦画面の両方で使う。配置は layout で決め、座標はこのノードからの相対。
## is_player が true なら操作音と振動も出す（CPU 側は消去の音だけ小さめに）。

const LOCK_FLASH_TIME := 0.15
const SHOW_HIDDEN_ROWS := 2     # 盤面の上にはみ出して見せる行数
const MESSAGE_TIME := 1.5
const SPIN_NAMES := ["", "MINI ", ""]
const LINE_NAMES := ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS"]
const TSPIN_PITCH := 1.26       # Tスピンの形に入ったら回転音を約4半音上げる
const TSPIN_MINI_PITCH := 1.12  # Mini は約2半音
const CPU_VOLUME := 0.5

var game: GameState
var is_player := true

# 配置（このノードからの相対座標）
var cell := 30.0
var board_pos := Vector2.ZERO
var hold_rect := Rect2()
var next_rect := Rect2()
var counter_pos := Vector2.ZERO
var message_rect := Rect2()     # 直前の消し方の表示（中央揃え）。size.x が 0 なら出さない
var show_meter := false
var show_side := true           # false ならホールド・NEXT・カウンター・技名を出さない（タイトルのデモ）
var muted := false              # true なら音を出さない

var fx := Effects.new()
var _guide := {}                # アシストのおすすめ {"type", "pos", "rot", "hold"}
var _base_position := Vector2.ZERO
var _lock_flash := {}
var _hard_dropped := false
var _message := ""
var _message_timer := 0.0
var _time := 0.0


func setup(new_game: GameState, player: bool) -> void:
	game = new_game
	is_player = player
	game.event.connect(_on_game_event)
	fx.clear()
	_lock_flash.clear()
	_message_timer = 0.0
	_hard_dropped = false


## アシストのおすすめの置き場所を出す。hold なら先にホールドをすすめる
func set_guide(type: int, pos: Vector2i, rot: int, hold: bool) -> void:
	_guide = {"type": type, "pos": pos, "rot": rot, "hold": hold}


func clear_guide() -> void:
	_guide = {}


func set_base_position(p: Vector2) -> void:
	_base_position = p
	position = p


func board_rect() -> Rect2:
	return Rect2(board_pos, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * cell)


## 予告ゲージの枠（盤面の左）
func meter_rect() -> Rect2:
	var w := maxf(cell * 0.4, 8.0)
	return Rect2(board_pos.x - w - 4, board_pos.y, w, Board.VISIBLE_ROWS * cell)


## 攻撃の玉を飛ばす先・元（画面上の座標）
func meter_global_point() -> Vector2:
	var r := meter_rect()
	return _base_position + Vector2(r.get_center().x, r.end.y - cell * 2)


func board_global_center() -> Vector2:
	return _base_position + board_rect().get_center()


func _process(delta: float) -> void:
	_time += delta
	_message_timer = maxf(_message_timer - delta, 0.0)
	for k in _lock_flash.keys():
		_lock_flash[k] -= delta
		if _lock_flash[k] <= 0.0:
			_lock_flash.erase(k)
	fx.update(delta, App.skin.fx.particle_gravity)
	position = _base_position + fx.screen_offset()
	queue_redraw()


# ---------------- イベント ----------------

func _on_game_event(kind: String, data: Dictionary) -> void:
	var skin_fx: Dictionary = App.skin.fx
	match kind:
		"move":
			_player_sound("move")
		"rotate":
			var pitch := 1.0
			if game.piece == PieceData.T and data.spin != GameState.Spin.NONE:
				pitch = TSPIN_PITCH if data.spin == GameState.Spin.FULL else TSPIN_MINI_PITCH
			_player_sound("rotate", pitch)
		"hold":
			_player_sound("hold")
		"hard_drop":
			_hard_drop_trail(data)
			fx.bump(skin_fx.hard_drop_bump * cell / 30.0)
			_player_sound("hard_drop")
			if is_player:
				InputSetup.vibrate(0.3, 0.0, 0.05)
			_hard_dropped = true
		"lock":
			for c in PieceData.cells(data.piece, data.rot):
				_lock_flash[data.pos + c] = LOCK_FLASH_TIME
			if not _hard_dropped:
				_player_sound("lock")
			_hard_dropped = false
		"clear":
			_on_clear(data)
		"garbage_rise":
			fx.shake(3.0)
			_sound("garbage_rise")
		"game_over":
			fx.shake(6.0)


func _on_clear(data: Dictionary) -> void:
	var skin_fx: Dictionary = App.skin.fx
	_message = clear_name(data)
	_message_timer = MESSAGE_TIME

	# 消える行のブロックから粒を飛ばす（この時点ではまだ盤面に残っている）
	var per_cell: int = skin_fx.particles_per_cell * (1 + data.lines / 4)
	for y in game.board.full_rows():
		for x in Board.WIDTH:
			var type: int = game.board.grid[y][x]
			fx.burst(_cell_rect(Vector2i(x, y)).get_center(), App.skin.piece_colors[type], per_cell, skin_fx.particle_speed * cell / 30.0)

	var big := false
	if data.perfect:
		_sound("perfect")
		fx.shake(skin_fx.shake_perfect)
		big = true
	elif data.spin != GameState.Spin.NONE and data.piece == PieceData.T:
		_sound("spin")
		if data.lines > 0:
			fx.shake(skin_fx.shake_spin)
		big = true
	elif data.lines == 4:
		_sound("tetris")
		fx.shake(skin_fx.shake_tetris)
		big = true
	elif data.lines > 0:
		_sound("clear%d" % data.lines)

	if big:
		var lines := Array(_message.split("\n")).filter(func(l): return not l.begins_with("REN"))
		fx.popup(lines)
		_message_timer = 0.0  # 中央に大きく出すので横の表示は出さない
		if data.lines > 0:
			fx.flash(skin_fx.flash_alpha)
			if is_player:
				InputSetup.vibrate(0.6, 0.8, 0.25)
	if data.b2b > 0:
		_sound("b2b")
		fx.bounce("b2b")
	if data.combo > 0:
		_sound("combo", pow(2.0, mini(data.combo, 12) / 12.0))
		fx.bounce("ren")


## 操作音（自分のときだけ）
func _player_sound(sound: String, pitch := 1.0) -> void:
	if is_player and not muted:
		Sfx.play(sound, pitch)


## 消去などの音（CPU は小さめ）
func _sound(sound: String, pitch := 1.0) -> void:
	if muted:
		return
	Sfx.play(sound, pitch, 1.0 if is_player else CPU_VOLUME)


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
		fx.trail(Rect2(top_rect.position, bottom_rect.end - top_rect.position), App.skin.piece_colors[data.piece])


static func clear_name(data: Dictionary) -> String:
	var parts := []
	if data.b2b > 0:
		parts.append("B2B x%d" % data.b2b)
	var title := ""
	# スピンの演出は T だけ（ほかのミノのスピンは普通の消去と同じ見せ方）
	if data.spin != GameState.Spin.NONE and data.piece == PieceData.T:
		title = "%s-SPIN %s" % [PieceData.NAMES[data.piece], SPIN_NAMES[data.spin]]
	if data.lines > 0:
		title += LINE_NAMES[data.lines]
	if title.strip_edges() != "":
		parts.append(title.strip_edges())
	if data.combo > 0:
		parts.append("REN %d" % data.combo)
	if data.perfect:
		parts.append("PERFECT CLEAR")
	return "\n".join(parts)


# ---------------- 描画 ----------------

func _draw() -> void:
	if game == null:
		return
	var skin: UiSkin = App.skin
	var board_origin := board_pos + fx.board_offset()
	var rect := Rect2(board_origin, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * cell)
	skin.draw_board(self, rect, cell)
	fx.draw_trails(self, skin)

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

	# アシストのガイド（ゴーストより奥）、ゴースト、操作中のミノ
	if game.can_control():
		var ghost := Vector2i(game.pos.x, game.ghost_y())
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		var on_guide := _ghost_on_guide(ghost)
		if not _guide.is_empty() and not on_guide:
			skin.draw_guide_outline(self, _outline_segments(_guide.type, _guide.rot, _guide.pos), _guide.type, pulse)
		# ゴーストがガイドにぴったり重なったら、ゴーストを光らせて知らせる
		var ghost_style := UiSkin.CellStyle.GHOST_MATCH if on_guide else UiSkin.CellStyle.GHOST
		for c in PieceData.cells(game.piece, game.rot):
			_draw_board_cell(ghost + c, game.piece, ghost_style, pulse)
		for c in PieceData.cells(game.piece, game.rot):
			_draw_board_cell(game.pos + c, game.piece)

	if show_meter:
		skin.draw_garbage_meter(self, meter_rect(), game.incoming_total(), cell, _time)

	if not show_side:
		fx.draw_particles(self, skin)
		fx.draw_popups(self, skin, rect.get_center() + Vector2(0, -2 * cell), cell / 30.0)
		return

	# ホールド
	var preview := cell * 0.8
	_draw_box_header(hold_rect, Loc.t("hold"))
	if not _guide.is_empty() and _guide.hold:
		skin.draw_guide_box(self, hold_rect, 0.5 + 0.5 * sin(_time * 8.0))
	if game.hold_piece != PieceData.NONE:
		var style := UiSkin.CellStyle.DIM if game.hold_used else UiSkin.CellStyle.PREVIEW
		_draw_preview(game.hold_piece, Rect2(hold_rect.position + Vector2(0, preview * 1.5), Vector2(hold_rect.size.x, hold_rect.size.y - preview * 1.5)), preview, style)

	# ネクスト（先頭だけ大きく）
	_draw_box_header(next_rect, Loc.t("next"))
	var queue := game.next_queue()
	var y := next_rect.position.y + preview * 1.5
	var step := (next_rect.size.y - preview * 1.5 - 8) / (queue.size() + 0.2)
	for i in queue.size():
		var h := step * 1.2 if i == 0 else step
		_draw_preview(queue[i], Rect2(next_rect.position.x, y, next_rect.size.x, h), preview if i == 0 else preview * 0.8)
		y += h

	_draw_counters()
	_draw_message()
	fx.draw_particles(self, skin)
	fx.draw_popups(self, skin, rect.get_center() + Vector2(0, -2 * cell), cell / 30.0)
	fx.draw_flash(self, skin, rect.grow(skin.border))


## ゴーストがガイドと同じマスを占めているか（O のように向きが違っても同じ形なら一致）
func _ghost_on_guide(ghost: Vector2i) -> bool:
	if _guide.is_empty() or _guide.hold or _guide.type != game.piece:
		return false
	var a := {}
	for c in PieceData.cells(game.piece, game.rot):
		a[ghost + c] = true
	for c in PieceData.cells(_guide.type, _guide.rot):
		if not a.has(_guide.pos + c):
			return false
	return true


## ミノの外周の線分（始点・終点の組）。隣にもミノのマスがある辺は描かない
func _outline_segments(type: int, rot: int, pos: Vector2i) -> PackedVector2Array:
	var cells := {}
	for c in PieceData.cells(type, rot):
		cells[pos + c] = true
	var segs := PackedVector2Array()
	for c in cells:
		if c.y - Board.HIDDEN_ROWS < -SHOW_HIDDEN_ROWS:
			continue
		var r := _cell_rect(c)
		if not cells.has(c + Vector2i.UP):
			segs.append_array([r.position, Vector2(r.end.x, r.position.y)])
		if not cells.has(c + Vector2i.DOWN):
			segs.append_array([Vector2(r.position.x, r.end.y), r.end])
		if not cells.has(c + Vector2i.LEFT):
			segs.append_array([r.position, Vector2(r.position.x, r.end.y)])
		if not cells.has(c + Vector2i.RIGHT):
			segs.append_array([Vector2(r.end.x, r.position.y), r.end])
	return segs


func _draw_counters() -> void:
	var y := counter_pos.y
	var scale := cell / 30.0
	if game.combo >= 1:
		App.skin.draw_counter(self, Vector2(counter_pos.x, y), "REN", str(game.combo), fx.bounce_amount("ren"))
		y += 56 * scale
	if game.b2b >= 1:
		App.skin.draw_counter(self, Vector2(counter_pos.x, y), "B2B", "x%d" % game.b2b, fx.bounce_amount("b2b"))


func _draw_message() -> void:
	if _message_timer <= 0.0 or message_rect.size.x <= 0.0:
		return
	var alpha := minf(_message_timer / 0.3, 1.0)
	var size := int(24 * cell / 30.0)
	var ty := message_rect.position.y
	for line in _message.split("\n"):
		App.skin.draw_text(self, Vector2(message_rect.position.x, ty), line, size, Color(App.skin.colors.highlight, alpha),
			HORIZONTAL_ALIGNMENT_CENTER, message_rect.size.x, true)
		ty += size * 1.35


func _cell_rect(c: Vector2i) -> Rect2:
	var row := c.y - Board.HIDDEN_ROWS
	return Rect2(board_pos + fx.board_offset() + Vector2(c.x, row) * cell, Vector2(cell, cell))


func _draw_board_cell(c: Vector2i, type: int, style := UiSkin.CellStyle.NORMAL, flash := 0.0) -> void:
	if c.y - Board.HIDDEN_ROWS < -SHOW_HIDDEN_ROWS:
		return
	App.skin.draw_cell(self, _cell_rect(c), type, style, flash)


func _draw_box_header(rect: Rect2, title: String) -> void:
	App.skin.draw_panel(self, rect)
	var size := int(20 * cell / 30.0)
	App.skin.draw_text(self, Vector2(rect.position.x, rect.position.y + size * 1.5), title, size, "text", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## area の中央にミノを描く
func _draw_preview(type: int, area: Rect2, size: float, style := UiSkin.CellStyle.PREVIEW) -> void:
	var cells := PieceData.cells(type, 0)
	var min_c := Vector2(99, 99)
	var max_c := Vector2(-99, -99)
	for c in cells:
		min_c = min_c.min(Vector2(c))
		max_c = max_c.max(Vector2(c))
	var extent := (max_c - min_c + Vector2.ONE) * size
	var origin := area.get_center() - extent / 2.0 - min_c * size
	for c in cells:
		App.skin.draw_cell(self, Rect2(origin + Vector2(c) * size, Vector2(size, size)), type, style)
