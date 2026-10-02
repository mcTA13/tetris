class_name ClassicSkin
extends PopSkin
## クラシック: 濃い紺の夜空に星、黒い盤面と細いグリッド、平らで縁取りのあるはっきりした色のミノ。
## 効果音はポップと同じものを使い、見た目の描き方だけを上書きする。

const NIGHT := Color("060a1c")
const STAR_COUNT := 90
const STAR_SPEED := 10.0

var _stars := []


func _init() -> void:
	colors = {
		"bg_top": Color("101a46"), "bg_bottom": Color("03040c"),
		"panel": Color(0.03, 0.05, 0.14, 0.88), "panel_border": Color(0.75, 0.82, 1.0, 0.45), "shadow": Color(0, 0, 0, 0.35),
		"board": Color(0.0, 0.0, 0.02, 0.82), "grid": Color(0.6, 0.7, 1.0, 0.09),
		"text": Color("eef2ff"), "text_dim": Color(0.7, 0.76, 0.92, 0.75), "text_on_accent": Color.WHITE,
		"accent": Color("2f7dff"), "highlight": Color("ffd84a"), "outline": NIGHT,
		"title": Color.WHITE,
	}
	piece_colors = {
		PieceData.I: Color("19d3f2"), PieceData.O: Color("ffd60a"), PieceData.T: Color("b14ee6"),
		PieceData.S: Color("44d64a"), PieceData.Z: Color("f2353a"), PieceData.J: Color("3d5ef5"),
		PieceData.L: Color("ff8a1c"), PieceData.GARBAGE: Color("7d8090"),
	}
	font = load("res://assets/fonts/MPLUS1p-Bold.ttf")
	font_heavy = load("res://assets/fonts/MPLUS1p-ExtraBold.ttf")
	radius = 6
	border = 2
	# 星の位置は固定の乱数で決める（毎回同じ夜空）
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in STAR_COUNT:
		_stars.append({"pos": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			"size": rng.randf_range(0.8, 2.2), "twinkle": rng.randf_range(0, TAU), "depth": rng.randf_range(0.3, 1.0)})


func display_name() -> String:
	return "CLASSIC"


# ---------------- 背景・パネル ----------------

func draw_background(ci: CanvasItem, size: Vector2, time: float) -> void:
	# 縦のグラデーション（ポップの背景を呼ぶと水玉まで描かれるので、ここで描く）
	var m := 60.0
	ci.draw_polygon(
		PackedVector2Array([Vector2(-m, -m), Vector2(size.x + m, -m), size + Vector2(m, m), Vector2(-m, size.y + m)]),
		PackedColorArray([colors.bg_top, colors.bg_top, colors.bg_bottom, colors.bg_bottom]))
	# ゆっくり横に流れる星（奥の星ほど遅く暗い）
	for s in _stars:
		var x: float = fmod(s.pos.x + time * STAR_SPEED * s.depth, size.x + 40.0) - 20.0
		var a: float = (0.35 + 0.35 * sin(time * 1.5 + s.twinkle)) * s.depth
		ci.draw_circle(Vector2(x, s.pos.y), s.size, Color(0.85, 0.9, 1.0, a))


func draw_item(ci: CanvasItem, rect: Rect2, selected: bool, time: float) -> void:
	if not selected:
		return
	# 選択中は青く光る板（ゆっくり明滅）
	var glow := 0.15 + 0.1 * sin(time * 5.0)
	_box(Color(colors.accent, 0.85), Color(0.75, 0.88, 1.0, 0.9), 2, radius, Color(colors.accent, glow + 0.2)).draw(ci.get_canvas_item(), rect)


# ---------------- ブロック ----------------

func draw_cell(ci: CanvasItem, rect: Rect2, type: int, style := CellStyle.NORMAL, flash := 0.0) -> void:
	var color: Color = piece_colors[type]
	var r := rect.grow(-1)
	match style:
		CellStyle.GHOST:
			ci.draw_rect(r, Color(color, 0.14))
			ci.draw_rect(r.grow(-1), Color(color, 0.8), false, 2.0)
			return
		CellStyle.GHOST_MATCH:
			ci.draw_rect(r, Color(color.lerp(Color.WHITE, 0.5), 0.4 + 0.25 * flash))
			ci.draw_rect(r.grow(-1), Color(1, 1, 1, 0.85 + 0.15 * flash), false, 2.0)
			return
		CellStyle.DIM:
			color = Color("4a4e60")
	color = color.lerp(Color.WHITE, flash)
	# 平らな面に、左上は明るく右下は暗い縁取り（立体感は控えめ）
	var edge := maxf(r.size.x * 0.12, 2.0)
	ci.draw_rect(r, color)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, edge)), color.lightened(0.35))
	ci.draw_rect(Rect2(r.position, Vector2(edge, r.size.y)), color.lightened(0.2))
	ci.draw_rect(Rect2(r.position.x, r.end.y - edge, r.size.x, edge), color.darkened(0.35))
	ci.draw_rect(Rect2(r.end.x - edge, r.position.y, edge, r.size.y), color.darkened(0.25))
	ci.draw_rect(r.grow(-edge), color.lightened(0.06))


func draw_logo(ci: CanvasItem, center: Vector2, time: float) -> void:
	# 白い太字に、ミノの色の細い帯
	var text := "TETRIS"
	var size := 96
	var width := text_width(text, size, true)
	var pos := Vector2(center.x - width / 2.0, center.y + 30)
	ci.draw_string_outline(font_heavy, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, NIGHT)
	ci.draw_string(font_heavy, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	var bar_w := width / 7.0
	var order := [PieceData.Z, PieceData.L, PieceData.O, PieceData.S, PieceData.I, PieceData.J, PieceData.T]
	for i in order.size():
		var a := 0.75 + 0.25 * sin(time * 3.0 - i * 0.6)
		ci.draw_rect(Rect2(pos.x + i * bar_w, pos.y + 18, bar_w - 4, 8), Color(piece_colors[order[i]], a))


# ---------------- 演出 ----------------

func draw_clearing_cell(ci: CanvasItem, rect: Rect2, type: int, progress: float) -> void:
	# 白く光ってから、横に細くなって消える
	var w := 1.0 - progress
	if w <= 0.0:
		return
	var r := Rect2(rect.position.x, rect.get_center().y - rect.size.y * w / 2.0, rect.size.x, rect.size.y * w)
	ci.draw_rect(r, Color(piece_colors[type].lerp(Color.WHITE, clampf(1.0 - progress * 1.2, 0.0, 1.0)), 0.5 + 0.5 * w))


func draw_particle(ci: CanvasItem, pos: Vector2, size: float, color: Color, _rotation: float, alpha: float) -> void:
	# 小さな光の粒
	ci.draw_circle(pos, size * 0.45, Color(color.lerp(Color.WHITE, 0.4), alpha))
	ci.draw_circle(pos, size * 0.2, Color(1, 1, 1, alpha))


func draw_trail(ci: CanvasItem, rect: Rect2, color: Color, alpha: float) -> void:
	var top := Color(color, 0.0)
	var bottom := Color(color.lerp(Color.WHITE, 0.5), 0.45 * alpha)
	ci.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func draw_flash(ci: CanvasItem, rect: Rect2, alpha: float) -> void:
	ci.draw_rect(rect, Color(0.85, 0.92, 1.0, alpha * 0.8))


func draw_popup(ci: CanvasItem, center: Vector2, lines: Array, t: float, duration: float, size_scale := 1.0) -> void:
	# 白い文字に青い縁取り。少し大きく出てから落ち着き、最後は薄くなって消える
	var appear := clampf(t / (duration * 0.15), 0.0, 1.0)
	var scale := (1.3 - 0.3 * appear) * size_scale
	var alpha := clampf((duration - t) / (duration * 0.25), 0.0, 1.0) * appear
	var y := center.y - (lines.size() - 1) * 28.0 * size_scale
	for li in lines.size():
		var size := int((48 if li == lines.size() - 1 else 30) * scale)
		var line: String = lines[li]
		var pos := Vector2(center.x - 400, y)
		ci.draw_string_outline(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, 12, Color(colors.accent, 0.6 * alpha))
		ci.draw_string_outline(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, 5, Color(NIGHT, alpha))
		ci.draw_string(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, Color(1, 1, 1, alpha))
		y += 56 * size_scale


func draw_counter(ci: CanvasItem, pos: Vector2, label: String, value: String, bounce: float) -> void:
	var scale := 1.0 + 0.3 * bounce
	var text := "%s %s" % [label, value]
	var size := int(22 * scale)
	var w := text_width(text, size, true) + 30
	var h := 40.0 * scale
	var r := Rect2(pos.x, pos.y - h / 2.0, w, h)
	_box(colors.panel, colors.accent, 2, radius, Color.TRANSPARENT).draw(ci.get_canvas_item(), r)
	draw_text(ci, Vector2(r.position.x, r.position.y + h * 0.5 + size * 0.36), text, size, "highlight", HORIZONTAL_ALIGNMENT_CENTER, w, true)


func draw_garbage_meter(ci: CanvasItem, rect: Rect2, lines: int, cell: float, time: float) -> void:
	if lines <= 0:
		return
	var color := Color("ffcc33") if lines < 4 else (Color("ff7a1f") if lines < 8 else Color("ff2d3a"))
	var pulse := 0.0 if lines < 8 else 0.3 * (0.5 + 0.5 * sin(time * 14.0))
	var h := minf(lines * cell, rect.size.y)
	var r := Rect2(rect.position.x, rect.end.y - h, rect.size.x, h)
	ci.draw_rect(r, color.lerp(Color.WHITE, pulse))
	var y := r.end.y - cell
	while y > r.position.y + 1:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.4), 1.0)
		y -= cell


func draw_attack_orb(ci: CanvasItem, pos: Vector2, lines: int, _t: float) -> void:
	var r := 6.0 + lines * 2.0
	ci.draw_circle(pos, r * 2.0, Color(colors.accent, 0.25))
	ci.draw_circle(pos, r, Color(0.7, 0.85, 1.0))
	ci.draw_circle(pos, r * 0.5, Color.WHITE)


func draw_guide_box(ci: CanvasItem, rect: Rect2, pulse: float) -> void:
	_box(Color.TRANSPARENT, Color(colors.accent, 0.5 + 0.5 * pulse), 4, radius + 3, Color.TRANSPARENT).draw(ci.get_canvas_item(), rect.grow(4))
