class_name NeonSkin
extends PopSkin
## ネオン: 黒に近い夜空と、奥へ続く光の床。ミノは暗い面に光るふちのネオン管。
## 演出は強め（粒・揺れ・フラッシュを大きくし、消える行は光の帯、大技の文字は色ずれして叩きつける）。
## 効果音はポップと同じものを使う。

const NIGHT := Color("05030d")
const CYAN := Color("3ff0ff")
const MAGENTA := Color("ff2fb9")
const HORIZON := 0.66           # 光の床の地平線（画面の高さに対する割合）
const STAR_COUNT := 60
const MOTE_COUNT := 36

var _stars := []
var _motes := []


func _init() -> void:
	colors = {
		"bg_top": Color("0d0826"), "bg_bottom": Color("010103"),
		"panel": Color(0.02, 0.02, 0.06, 0.88), "panel_border": Color(CYAN, 0.6), "shadow": Color.TRANSPARENT,
		"board": Color(0.0, 0.0, 0.015, 0.9), "grid": Color(0.4, 0.8, 1.0, 0.07),
		"text": Color("eaf6ff"), "text_dim": Color(0.62, 0.74, 0.9, 0.72), "text_on_accent": Color.WHITE,
		"accent": MAGENTA, "highlight": CYAN, "outline": NIGHT,
		"title": Color.WHITE,
	}
	piece_colors = {
		PieceData.I: Color("21e6ff"), PieceData.O: Color("ffe234"), PieceData.T: Color("c04dff"),
		PieceData.S: Color("3dff7a"), PieceData.Z: Color("ff3355"), PieceData.J: Color("3d6bff"),
		PieceData.L: Color("ff8c1a"), PieceData.GARBAGE: Color("6b6f85"),
	}
	font = load("res://assets/fonts/MPLUS1p-Bold.ttf")
	font_heavy = load("res://assets/fonts/MPLUS1p-ExtraBold.ttf")
	radius = 4
	border = 2
	fx.particles_per_cell = 6
	fx.particle_speed = 640.0
	fx.particle_gravity = 700.0     # 少しふわっと舞う火花
	fx.shake_tetris = 18.0
	fx.shake_spin = 14.0
	fx.shake_perfect = 28.0
	fx.hard_drop_sparks = 4
	fx.flash_alpha = 0.6
	cursor_motion = {"stiffness": 2600.0, "damping": 1.0}  # 行き過ぎずに素早く移る
	# 星と光の粒の位置は固定の乱数で決める
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	for i in STAR_COUNT:
		_stars.append({"pos": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720 * HORIZON)),
			"size": rng.randf_range(0.6, 1.8), "twinkle": rng.randf_range(0, TAU)})
	for i in MOTE_COUNT:
		_motes.append({"x": rng.randf_range(0, 1280), "y": rng.randf_range(0, 760), "speed": rng.randf_range(10, 34),
			"size": rng.randf_range(1.0, 2.6), "sway": rng.randf_range(0, TAU), "color": CYAN if i % 2 == 0 else MAGENTA})


func display_name() -> String:
	return "NEON"


# ---------------- 背景・パネル ----------------

func draw_background(ci: CanvasItem, size: Vector2, time: float) -> void:
	var m := 60.0
	ci.draw_polygon(
		PackedVector2Array([Vector2(-m, -m), Vector2(size.x + m, -m), size + Vector2(m, m), Vector2(-m, size.y + m)]),
		PackedColorArray([colors.bg_top, colors.bg_top, colors.bg_bottom, colors.bg_bottom]))
	for s in _stars:
		var a: float = 0.25 + 0.25 * sin(time * 1.3 + s.twinkle)
		ci.draw_circle(s.pos, s.size, Color(0.8, 0.85, 1.0, a))
	# 地平線のぼんやりした光
	var horizon := size.y * HORIZON
	var glow := Color(MAGENTA, 0.16)
	var clear := Color(MAGENTA, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(-m, horizon - 90), Vector2(size.x + m, horizon - 90), Vector2(size.x + m, horizon), Vector2(-m, horizon)]),
		PackedColorArray([clear, clear, glow, glow]))
	ci.draw_polygon(PackedVector2Array([Vector2(-m, horizon), Vector2(size.x + m, horizon), Vector2(size.x + m, horizon + 60), Vector2(-m, horizon + 60)]),
		PackedColorArray([glow, glow, clear, clear]))
	# 奥へ続く光の床（横の線が手前へ流れてくる）
	var vp := Vector2(size.x / 2.0, horizon)
	var bottom := size.y + m
	for i in range(-14, 15):
		ci.draw_line(vp + Vector2(i * 8.0, 0), Vector2(vp.x + i * 130.0, bottom), Color(MAGENTA, 0.1), 1.5)
	var rows := 14
	for k in rows:
		var z := fmod(k + time * 0.5, rows) / rows
		var y := horizon + (bottom - horizon) * pow(z, 2.2)
		ci.draw_line(Vector2(-m, y), Vector2(size.x + m, y), Color(MAGENTA, 0.03 + 0.17 * z), 1.0 + z * 1.5)
	ci.draw_line(Vector2(-m, horizon), Vector2(size.x + m, horizon), Color(1.0, 0.5, 0.85, 0.35), 2.0)
	# ゆっくり昇る光の粒
	for p in _motes:
		var y: float = fmod(p.y - time * p.speed + 800.0, 800.0) - 40.0
		var x: float = p.x + sin(time * 0.8 + p.sway) * 14.0
		ci.draw_circle(Vector2(x, y), p.size * 3.5, Color(p.color, 0.05))
		ci.draw_circle(Vector2(x, y), p.size, Color(p.color, 0.55))


## パネル: 左上と右下の角を斜めに落とした計器風の枠。残りの 2 つの角には明るいかぎ括弧
func draw_panel(ci: CanvasItem, rect: Rect2, fill_role := "panel", alpha := 1.0) -> void:
	var cut := clampf(minf(rect.size.x, rect.size.y) * 0.25, 6.0, 16.0)
	var shape := _chamfer(rect, cut)
	ci.draw_colored_polygon(shape, _fade(colors[fill_role], alpha))
	_neon_outline(ci, shape, Color(CYAN, 0.45 * alpha), 1.5, 0.6 * alpha, CYAN)
	var arm := minf(18.0, minf(rect.size.x, rect.size.y) * 0.3)
	var bright := _fade(CYAN.lightened(0.4), alpha)
	ci.draw_polyline(PackedVector2Array([Vector2(rect.end.x - arm, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + arm)]), bright, 3.0)
	ci.draw_polyline(PackedVector2Array([Vector2(rect.position.x, rect.end.y - arm), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + arm, rect.end.y)]), bright, 3.0)


## 盤面: 上は開いていて、左右の光の柱（下ほど明るい）と光る床で囲む。マス目は交点の光の点
func draw_board(ci: CanvasItem, rect: Rect2, cell: float, top_extra := 0.0) -> void:
	var top := rect.position.y - top_extra
	var left := rect.position.x - border
	var right := rect.end.x + border
	var floor_y := rect.end.y + border
	ci.draw_rect(Rect2(left, top, right - left, floor_y - top), colors.board)
	# 床から上へ薄く光る
	var low := Color(CYAN, 0.08)
	var none := Color(CYAN, 0.0)
	var mid := rect.position.y + rect.size.y * 0.55
	ci.draw_polygon(PackedVector2Array([Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([none, none, low, low]))
	var cols := int(rect.size.x / cell)
	var rows := int(rect.size.y / cell)
	for x in range(1, cols):
		ci.draw_line(rect.position + Vector2(x * cell, -top_extra), rect.position + Vector2(x * cell, rect.size.y), Color(CYAN, 0.035), 1.0)
	for y in range(1, rows):
		for x in range(1, cols):
			ci.draw_rect(Rect2(rect.position + Vector2(x * cell, y * cell) - Vector2(1, 1), Vector2(2, 2)), Color(CYAN, 0.28))
	# 左右の柱（上はうすく、下は明るく）と、床
	for x in [left, right]:
		_rail(ci, Vector2(x, top), Vector2(x, floor_y), 10.0, Color(CYAN, 0.0), Color(CYAN, 0.16))
		_rail(ci, Vector2(x, top), Vector2(x, floor_y), 2.5, Color(CYAN, 0.25), Color(CYAN.lightened(0.3), 1.0))
	ci.draw_line(Vector2(left - 6, floor_y), Vector2(right + 6, floor_y), Color(MAGENTA, 0.2), 12.0)
	ci.draw_line(Vector2(left - 6, floor_y), Vector2(right + 6, floor_y), Color(MAGENTA.lightened(0.3), 1.0), 3.0)
	# 床の両端の折れ曲がった飾り
	var arm := cell * 0.8
	ci.draw_polyline(PackedVector2Array([Vector2(left - 6, floor_y - arm), Vector2(left - 6, floor_y + 6), Vector2(left + arm, floor_y + 6)]), Color(MAGENTA, 0.9), 2.0)
	ci.draw_polyline(PackedVector2Array([Vector2(right + 6, floor_y - arm), Vector2(right + 6, floor_y + 6), Vector2(right - arm, floor_y + 6)]), Color(MAGENTA, 0.9), 2.0)


## 選んでいる項目: 右に傾いた平行四辺形がマゼンタに光り、光の筋が流れる。
## 素早く移り、通ったあとにマゼンタとシアンの残像が左右にずれて残る
func draw_cursor(ci: CanvasItem, cursor: MenuCursor, time: float) -> void:
	var rect := cursor.rect
	for age in [0.03, 0.06, 0.09, 0.12]:
		var past := cursor.trail_at(age)
		if absf(past.position.y - rect.position.y) < 3.0 and absf(past.position.x - rect.position.x) < 3.0:
			continue
		var a: float = 0.55 * (1.0 - age / 0.14)
		_outline(ci, _slanted(Rect2(past.position + Vector2(5, 0), past.size)), Color(MAGENTA, a), 2.0)
		_outline(ci, _slanted(Rect2(past.position - Vector2(5, 0), past.size)), Color(CYAN, a), 2.0)
	var slant := minf(14.0, rect.size.y * 0.35)
	var p := rect.position
	var e := rect.end
	var shape := _slanted(rect)
	var pulse := 0.75 + 0.25 * sin(time * 5.0)
	ci.draw_colored_polygon(shape, Color(MAGENTA, 0.82))
	_neon_outline(ci, shape, Color(1.0, 0.78, 0.95), 2.0, 1.6 * pulse, MAGENTA)
	# 左から右へ流れる光の筋（辺と同じ傾きなので形からはみ出さない）。止まってから流れ直す
	var span := rect.size.x - slant - 12.0
	if span > 0.0 and cursor.rest > 0.0:
		var x := p.x + 6.0 + fmod(cursor.rest * 320.0, span + 260.0)
		if x <= p.x + 6.0 + span:
			ci.draw_line(Vector2(x + slant, p.y + 1), Vector2(x, e.y - 1), Color(1, 1, 1, 0.22), 8.0)


## 右に傾いた平行四辺形
static func _slanted(rect: Rect2) -> PackedVector2Array:
	var slant := minf(14.0, rect.size.y * 0.35)
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([Vector2(p.x + slant, p.y), Vector2(e.x, p.y), Vector2(e.x - slant, e.y), Vector2(p.x, e.y)])


static func _outline(ci: CanvasItem, shape: PackedVector2Array, color: Color, width: float) -> void:
	var closed := shape.duplicate()
	closed.append(shape[0])
	ci.draw_polyline(closed, color, width)


# ---------------- ブロック ----------------

func draw_cell(ci: CanvasItem, rect: Rect2, type: int, style := CellStyle.NORMAL, flash := 0.0) -> void:
	var color: Color = piece_colors[type]
	var r := rect.grow(-1)
	var edge := maxf(r.size.x * 0.12, 2.0)
	match style:
		CellStyle.GHOST:
			ci.draw_rect(r, Color(color, 0.08))
			ci.draw_rect(r.grow(-edge / 2.0), Color(color, 0.25), false, edge)
			ci.draw_rect(r.grow(-edge / 2.0), Color(color.lightened(0.3), 0.7), false, 1.0)
			return
		CellStyle.GHOST_MATCH:
			ci.draw_rect(r, Color(color.lerp(Color.WHITE, 0.5), 0.35 + 0.25 * flash))
			ci.draw_rect(r.grow(-1), Color(1, 1, 1, 0.85 + 0.15 * flash), false, 2.0)
			return
		CellStyle.DIM:
			color = Color("4c5066")
	color = color.lerp(Color.WHITE, flash)
	# 暗い面に、明るいふち（ネオン管）と内側のにじみ
	ci.draw_rect(r, color.darkened(0.62).lerp(Color.WHITE, flash * 0.6))
	ci.draw_rect(r.grow(-edge), Color(color, 0.3 + 0.5 * flash))
	ci.draw_rect(r.grow(-edge / 2.0), color.lightened(0.15), false, edge)
	ci.draw_rect(r.grow(-edge * 1.5), Color(color.lightened(0.5), 0.35), false, 1.0)


func draw_logo(ci: CanvasItem, center: Vector2, time: float) -> void:
	# ネオンサイン。ときどき 1 文字がちらつく
	var text := "TETRIS"
	var size := 96
	var total := text_width(text, size, true) + (text.length() - 1) * 4.0
	var x := center.x - total / 2.0
	var y := center.y + 30
	var flicker_letter := int(time / 3.7) % text.length()
	var flicker := fmod(time, 3.7) < 0.18 and sin(time * 90.0) > 0.0
	for i in text.length():
		var ch := text[i]
		var a := 0.3 if flicker and i == flicker_letter else 1.0
		var pos := Vector2(x, y)
		ci.draw_string_outline(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 26, Color(MAGENTA, 0.08 * a))
		ci.draw_string_outline(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(MAGENTA, 0.25 * a))
		ci.draw_string_outline(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(MAGENTA.lightened(0.2), a))
		ci.draw_string(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Color("fff0fb"), a))
		x += text_width(ch, size, true) + 4.0
	# ミノの色の光る帯
	var bar_w := total / 7.0
	var order := [PieceData.Z, PieceData.L, PieceData.O, PieceData.S, PieceData.I, PieceData.J, PieceData.T]
	var left := center.x - total / 2.0
	for i in order.size():
		var c: Color = piece_colors[order[i]]
		var a := 0.7 + 0.3 * sin(time * 3.0 - i * 0.6)
		var bar := Rect2(left + i * bar_w, y + 20, bar_w - 4, 5)
		ci.draw_rect(bar.grow(3), Color(c, 0.18 * a))
		ci.draw_rect(bar, Color(c.lightened(0.2), a))


# ---------------- 演出 ----------------

func draw_clearing_cell(ci: CanvasItem, rect: Rect2, type: int, progress: float) -> void:
	# 行全体が白い光の帯になって、上下にふくらんでから細くなって消える
	var w := 1.0 - progress
	if w <= 0.0:
		return
	var color: Color = piece_colors[type]
	var c := rect.get_center()
	var flare := clampf(1.0 - progress * 2.5, 0.0, 1.0)
	var gh := rect.size.y * (1.0 + 2.0 * flare) * w
	ci.draw_rect(Rect2(rect.position.x - 1, c.y - gh / 2.0, rect.size.x + 2, gh), Color(color.lerp(Color.WHITE, 0.4), 0.3 * w))
	var ch := rect.size.y * w * 0.7
	ci.draw_rect(Rect2(rect.position.x - 1, c.y - ch / 2.0, rect.size.x + 2, ch), Color(color.lerp(Color.WHITE, 0.85), w))


func draw_particle(ci: CanvasItem, pos: Vector2, size: float, color: Color, rotation: float, alpha: float) -> void:
	# 光の火花: にじんだ光と、回る十字のきらめき（数が多いので描く回数は少なく）
	var bright := color.lerp(Color.WHITE, 0.45)
	ci.draw_rect(Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), Color(color, alpha * 0.2))
	var d := Vector2.from_angle(rotation) * size * 0.8
	ci.draw_line(pos - d, pos + d, Color(bright, alpha), 2.0)
	ci.draw_line(pos - d.orthogonal(), pos + d.orthogonal(), Color(bright, alpha), 2.0)


func draw_trail(ci: CanvasItem, rect: Rect2, color: Color, alpha: float) -> void:
	# 光の柱: 外側のにじみと、白く細い芯
	var top := Color(color, 0.0)
	var bottom := Color(color.lerp(Color.WHITE, 0.3), 0.6 * alpha)
	ci.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var core := Rect2(rect.get_center().x - rect.size.x * 0.12, rect.position.y, rect.size.x * 0.24, rect.size.y)
	var core_top := Color(1, 1, 1, 0.0)
	var core_bottom := Color(1, 1, 1, 0.8 * alpha)
	ci.draw_polygon(
		PackedVector2Array([core.position, Vector2(core.end.x, core.position.y), core.end, Vector2(core.position.x, core.end.y)]),
		PackedColorArray([core_top, core_top, core_bottom, core_bottom]))


func draw_flash(ci: CanvasItem, rect: Rect2, alpha: float) -> void:
	# 水色の光が盤面いっぱいに広がる
	ci.draw_rect(rect, Color(0.55, 0.9, 1.0, alpha * 0.7))
	ci.draw_rect(rect.grow(6), Color(CYAN, alpha), false, 6.0)


func draw_popup(ci: CanvasItem, center: Vector2, lines: Array, t: float, duration: float, size_scale := 1.0) -> void:
	# 大きく叩きつけるように出て、色ずれしながら落ち着く。左右に光の線が伸びる
	var appear := clampf(t / (duration * 0.12), 0.0, 1.0)
	var settle := 1.0 - pow(1.0 - appear, 3)
	var scale := (1.7 - 0.7 * settle) * size_scale
	var alpha := clampf((duration - t) / (duration * 0.25), 0.0, 1.0) * clampf(appear * 2.0, 0.0, 1.0)
	var split := (2.0 + 9.0 * (1.0 - settle)) * size_scale
	var jitter := Vector2(sin(t * 97.0), cos(t * 83.0)) * 5.0 * (1.0 - settle) * size_scale
	var y := center.y - (lines.size() - 1) * 28.0 * size_scale
	for li in lines.size():
		var size := int((50 if li == lines.size() - 1 else 30) * scale)
		var line: String = lines[li]
		var pos := Vector2(center.x - 400, y) + jitter
		ci.draw_string_outline(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, 22, Color(CYAN, 0.12 * alpha))
		ci.draw_string_outline(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, 6, Color(NIGHT, 0.9 * alpha))
		ci.draw_string(font_heavy, pos + Vector2(-split, 0), line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, Color(MAGENTA, 0.7 * alpha))
		ci.draw_string(font_heavy, pos + Vector2(split, 0), line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, Color(CYAN, 0.7 * alpha))
		ci.draw_string(font_heavy, pos, line, HORIZONTAL_ALIGNMENT_CENTER, 800, size, Color(1, 1, 1, alpha))
		y += 54 * size_scale
	# 文字の下に、中央から左右へ伸びる光の線
	var half := 170.0 * settle * size_scale
	var line_y := y - 40 * size_scale
	ci.draw_line(Vector2(center.x - half, line_y), Vector2(center.x + half, line_y), Color(CYAN, 0.25 * alpha), 8.0)
	ci.draw_line(Vector2(center.x - half, line_y), Vector2(center.x + half, line_y), Color(1, 1, 1, 0.9 * alpha), 2.0)


## REN / B2B: 傾いた札に、小さな見出しと大きな数字。増えた瞬間に光が強くなる
func draw_counter(ci: CanvasItem, pos: Vector2, label: String, value: String, bounce: float) -> void:
	var scale := 1.0 + 0.35 * bounce
	var label_size := int(14 * scale)
	var size := int(24 * scale)
	var label_w := text_width(label, label_size, true)
	var w := label_w + text_width(value, size, true) + 46
	var h := 40.0 * scale
	var slant := 10.0 * scale
	var p := Vector2(pos.x, pos.y - h / 2.0)
	var shape := PackedVector2Array([p + Vector2(slant, 0), p + Vector2(w, 0), p + Vector2(w - slant, h), p + Vector2(0, h)])
	ci.draw_colored_polygon(shape, colors.panel)
	_neon_outline(ci, shape, MAGENTA, 2.0, 0.8 + 1.5 * bounce)
	var base_y := p.y + h * 0.5 + size * 0.36
	draw_text(ci, Vector2(p.x + 18, base_y), label, label_size, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	draw_text(ci, Vector2(p.x + 26 + label_w, base_y), value, size, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


## おじゃまの予告: 1 行ずつ分かれた光の目盛り。多いと赤く脈打つ
func draw_garbage_meter(ci: CanvasItem, rect: Rect2, lines: int, cell: float, time: float) -> void:
	if lines <= 0:
		return
	var color := Color("ffcc33") if lines < 4 else (Color("ff7a1f") if lines < 8 else Color("ff2d55"))
	var pulse := 0.0 if lines < 8 else 0.35 * (0.5 + 0.5 * sin(time * 14.0))
	var h := minf(lines * cell, rect.size.y)
	ci.draw_rect(Rect2(rect.position.x, rect.end.y - h, rect.size.x, h).grow(4), Color(color, 0.12 + pulse * 0.4))
	var y := rect.end.y
	while y - cell >= rect.end.y - h - 0.5:
		ci.draw_rect(Rect2(rect.position.x, y - cell + 1, rect.size.x, cell - 2), color.lerp(Color.WHITE, pulse))
		y -= cell


func draw_attack_orb(ci: CanvasItem, pos: Vector2, lines: int, _t: float) -> void:
	# にじんだ光の玉
	var r := 6.0 + lines * 2.2
	ci.draw_circle(pos, r * 3.0, Color(MAGENTA, 0.1))
	ci.draw_circle(pos, r * 1.9, Color(MAGENTA, 0.25))
	ci.draw_circle(pos, r, Color(1.0, 0.7, 0.95))
	ci.draw_circle(pos, r * 0.5, Color.WHITE)


func draw_guide_outline(ci: CanvasItem, segments: PackedVector2Array, type: int, pulse: float) -> void:
	var color := Color(piece_colors[type].lightened(0.3), 0.7 + 0.3 * pulse)
	for i in range(0, segments.size(), 2):
		ci.draw_dashed_line(segments[i], segments[i + 1], color, 2.0, 5.0)


func draw_guide_box(ci: CanvasItem, rect: Rect2, pulse: float) -> void:
	var r := rect.grow(5)
	_neon_outline(ci, _chamfer(r, clampf(minf(r.size.x, r.size.y) * 0.25, 6.0, 16.0)), Color(MAGENTA, 0.5 + 0.5 * pulse), 3.0, 0.5 + pulse)


# ---------------- 内部 ----------------

## 左上と右下の角を cut だけ斜めに落とした四角
static func _chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([Vector2(p.x + cut, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + cut)])


## 光るふち: 太くうすい線を重ねてにじませてから、細い線を引く。glow は 1 前後、glow_color を省くと線と同じ色
func _neon_outline(ci: CanvasItem, shape: PackedVector2Array, color: Color, width: float, glow: float, glow_color := Color.TRANSPARENT) -> void:
	var closed := shape.duplicate()
	closed.append(shape[0])
	var g := color if glow_color.a == 0.0 else glow_color
	ci.draw_polyline(closed, Color(g, clampf(0.07 * glow, 0.0, 1.0)), width + 12.0)
	ci.draw_polyline(closed, Color(g, clampf(0.14 * glow, 0.0, 1.0)), width + 5.0)
	ci.draw_polyline(closed, color, width)


## 上下で色が変わる縦の光の線（太さ width）
static func _rail(ci: CanvasItem, from: Vector2, to: Vector2, width: float, top_color: Color, bottom_color: Color) -> void:
	var half := Vector2(width / 2.0, 0)
	ci.draw_polygon(PackedVector2Array([from - half, from + half, to + half, to - half]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
