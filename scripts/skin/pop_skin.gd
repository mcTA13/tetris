class_name PopSkin
extends UiSkin
## ポップ: パステルのグラデーション＋水玉、白い角丸パネルに太いふち、キャンディ風のブロック。

const NAVY := Color("2b2350")
const DOT_SPACING := 64.0
const DOT_SPEED := 18.0


func _init() -> void:
	colors = {
		"bg_top": Color("ffb8dc"), "bg_bottom": Color("9fd8ff"),
		"panel": Color("fffaf2"), "panel_border": NAVY, "shadow": Color(NAVY, 0.3),
		"board": Color("30285a"), "grid": Color(1, 1, 1, 0.06),
		"text": NAVY, "text_dim": Color(NAVY, 0.55), "text_on_accent": Color.WHITE,
		"accent": Color("ff4f9a"), "highlight": Color("ff4f9a"), "outline": NAVY,
		"title": Color.WHITE,
	}
	piece_colors = {
		PieceData.I: Color("3fd2f2"), PieceData.O: Color("ffd83d"), PieceData.T: Color("b66dff"),
		PieceData.S: Color("6be06b"), PieceData.Z: Color("ff5c7a"), PieceData.J: Color("4f7bff"),
		PieceData.L: Color("ff9f3d"), PieceData.GARBAGE: Color("a9a3c4"),
	}
	font = load("res://assets/fonts/MPLUSRounded1c-ExtraBold.ttf")
	font_heavy = load("res://assets/fonts/MPLUSRounded1c-Black.ttf")
	radius = 18
	border = 4
	fx.particles_per_cell = 3
	fx.particle_speed = 480.0
	fx.shake_tetris = 12.0
	fx.shake_perfect = 18.0


func display_name() -> String:
	return "POP"


func draw_background(ci: CanvasItem, size: Vector2, time: float) -> void:
	super.draw_background(ci, size, time)
	# 斜めに流れる水玉
	var offset := fmod(time * DOT_SPEED, DOT_SPACING)
	var row := 0
	var y := -DOT_SPACING + offset
	while y < size.y + DOT_SPACING:
		var x := -DOT_SPACING + offset + (DOT_SPACING / 2.0 if row % 2 == 1 else 0.0)
		while x < size.x + DOT_SPACING:
			ci.draw_circle(Vector2(x, y), 9.0, Color(1, 1, 1, 0.28))
			x += DOT_SPACING
		y += DOT_SPACING
		row += 1


func draw_item(ci: CanvasItem, rect: Rect2, selected: bool, time: float) -> void:
	if not selected:
		return
	# 選択中はピンクのピルが少し弾む
	var bounce := 1.0 + 0.03 * sin(time * 8.0)
	var r := Rect2(rect.get_center() - rect.size * bounce / 2.0, rect.size * bounce)
	_box(colors.accent, NAVY, 3, int(r.size.y / 2.0), Color(NAVY, 0.3)).draw(ci.get_canvas_item(), r)


func draw_cell(ci: CanvasItem, rect: Rect2, type: int, style := CellStyle.NORMAL, flash := 0.0) -> void:
	var color: Color = piece_colors[type]
	var r := rect.grow(-1)
	var corner := 0  # ミノは真四角
	match style:
		CellStyle.GHOST:
			_box(Color(color, 0.18), Color(color, 0.85), 2, corner, Color.TRANSPARENT).draw(ci.get_canvas_item(), r)
			return
		CellStyle.GHOST_MATCH:
			# アシストのガイドにゴーストが重なった: ミノの色を明るくして白く光らせる
			_box(Color(color.lerp(Color.WHITE, 0.45), 0.45 + 0.25 * flash), Color(1, 1, 1, 0.85 + 0.15 * flash), 3, corner, Color.TRANSPARENT).draw(ci.get_canvas_item(), r)
			return
		CellStyle.DIM:
			color = Color("c9c4dc")
	color = color.lerp(Color.WHITE, flash)
	var rid := ci.get_canvas_item()
	_box(color, color.darkened(0.35), 2, corner, Color.TRANSPARENT).draw(rid, r)
	# 上半分のツヤと、左上の光
	var gloss := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.38))
	_box(Color(1, 1, 1, 0.35), Color.TRANSPARENT, 0, 0, Color.TRANSPARENT).draw(rid, gloss)
	ci.draw_circle(r.position + Vector2(r.size.x * 0.28, r.size.y * 0.28), r.size.x * 0.08, Color(1, 1, 1, 0.8))


func draw_logo(ci: CanvasItem, center: Vector2, time: float) -> void:
	var text := "TETRIS"
	var size := 96
	var letter_colors := [PieceData.Z, PieceData.L, PieceData.O, PieceData.S, PieceData.I, PieceData.T]
	var total := text_width(text, size, true) + (text.length() - 1) * 6.0
	var x := center.x - total / 2.0
	for i in text.length():
		var ch := text[i]
		var bob := sin(time * 3.0 + i * 0.6) * 8.0
		var pos := Vector2(x, center.y + 32 + bob)
		ci.draw_string_outline(font_heavy, pos + Vector2(0, 6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(NAVY, 0.35))
		ci.draw_string_outline(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, NAVY)
		ci.draw_string(font_heavy, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, piece_colors[letter_colors[i]])
		x += text_width(ch, size, true) + 6.0


# ---------------- 演出 ----------------

func draw_clearing_cell(ci: CanvasItem, rect: Rect2, type: int, progress: float) -> void:
	# 白く光ってから、ぷくっと膨らんで縮みながら消える
	var s := 1.0 + 0.25 * sin(minf(progress * 2.0, 1.0) * PI) - progress
	if s <= 0.0:
		return
	var r := Rect2(rect.get_center() - rect.size * s / 2.0, rect.size * s)
	var color: Color = piece_colors[type].lerp(Color.WHITE, clampf(1.0 - progress * 1.5, 0.0, 1.0))
	_box(color, NAVY, 2, 0, Color.TRANSPARENT).draw(ci.get_canvas_item(), r)


func draw_particle(ci: CanvasItem, pos: Vector2, size: float, color: Color, rotation: float, alpha: float) -> void:
	# 回転する小さな四角い紙吹雪
	ci.draw_set_transform(pos, rotation)
	var r := Rect2(-Vector2(size, size) / 2.0, Vector2(size, size))
	ci.draw_rect(r, Color(color, alpha))
	ci.draw_rect(r, Color(NAVY, alpha * 0.8), false, 2.0)
	ci.draw_set_transform(Vector2.ZERO)


func draw_trail(ci: CanvasItem, rect: Rect2, color: Color, alpha: float) -> void:
	# 下に行くほど濃くなる光の帯
	var top := Color(color, 0.0)
	var bottom := Color(color.lerp(Color.WHITE, 0.4), 0.55 * alpha)
	ci.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func draw_popup(ci: CanvasItem, center: Vector2, lines: Array, t: float, duration: float, size_scale := 1.0) -> void:
	# 弾むように大きく出て、最後は上にふわっと消える
	# 出てくる・消えていく時間は表示時間に合わせる
	var appear := clampf(t / (duration * 0.2), 0.0, 1.0)
	var scale := _back_out(appear) * size_scale
	var leave := clampf((t - duration * 0.75) / (duration * 0.25), 0.0, 1.0)
	var alpha := 1.0 - leave
	var rise := -30.0 * leave
	var y := center.y - (lines.size() - 1) * 30.0 + rise
	for li in lines.size():
		var line: String = lines[li]
		var size := int((52 if li == lines.size() - 1 else 34) * scale)
		if size <= 0:
			continue
		var wobble := sin(t * 10.0 + li) * 3.0 * (1.0 - appear * 0.7) * size_scale
		var width := text_width(line, size, true)
		var x := center.x - width / 2.0
		for i in line.length():
			var ch := line[i]
			var color: Color = RAINBOW[(i + li) % RAINBOW.size()]
			var p := Vector2(x, y + wobble + sin(t * 8.0 + i * 0.7) * 2.0)
			ci.draw_string_outline(font_heavy, p + Vector2(0, 5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(NAVY, 0.35 * alpha))
			ci.draw_string_outline(font_heavy, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(NAVY, alpha))
			ci.draw_string(font_heavy, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
			x += text_width(ch, size, true)
		y += 60 * size_scale


func draw_flash(ci: CanvasItem, rect: Rect2, alpha: float) -> void:
	# 盤面の角丸に合わせて光らせる
	_box(Color(1, 1, 1, alpha), Color.TRANSPARENT, 0, radius, Color.TRANSPARENT).draw(ci.get_canvas_item(), rect)


func draw_guide_outline(ci: CanvasItem, segments: PackedVector2Array, type: int, pulse: float) -> void:
	# ミノの色の点線で外周だけをなぞる（中は塗らない。実線のゴーストと見分けられるように）
	var color := Color(piece_colors[type].lightened(0.25), 0.7 + 0.3 * pulse)
	for i in range(0, segments.size(), 2):
		ci.draw_dashed_line(segments[i], segments[i + 1], color, 3.0, 6.0)


func draw_guide_box(ci: CanvasItem, rect: Rect2, pulse: float) -> void:
	# ホールドの枠をピンクに光らせる
	var box := _box(Color.TRANSPARENT, Color(colors.accent, 0.5 + 0.5 * pulse), 5, radius + 4, Color.TRANSPARENT)
	box.draw(ci.get_canvas_item(), rect.grow(5))


func draw_garbage_meter(ci: CanvasItem, rect: Rect2, lines: int, cell: float, time: float) -> void:
	if lines <= 0:
		return
	# 量が増えるほど 黄→橙→赤 になり、多いと脈打つ
	var color := Color("ffd83d") if lines < 4 else (Color("ff9f3d") if lines < 8 else Color("ff4f5e"))
	var pulse := 0.0 if lines < 8 else 0.25 * (0.5 + 0.5 * sin(time * 14.0))
	var h := minf(lines * cell, rect.size.y)
	var r := Rect2(rect.position.x, rect.end.y - h, rect.size.x, h)
	_box(color.lerp(Color.WHITE, pulse), NAVY, 2, 4, Color.TRANSPARENT).draw(ci.get_canvas_item(), r)
	# 1行ごとの区切り
	var y := r.end.y - cell
	while y > r.position.y + 1:
		ci.draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color(NAVY, 0.35), 1.0)
		y -= cell


func draw_attack_orb(ci: CanvasItem, pos: Vector2, lines: int, t: float) -> void:
	# 虹色に光る玉と、ふちの紺
	var r := 7.0 + lines * 2.5
	var color: Color = RAINBOW[int(t * 20.0) % RAINBOW.size()]
	ci.draw_circle(pos, r + 3.0, NAVY)
	ci.draw_circle(pos, r, color)
	ci.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.8))


func draw_counter(ci: CanvasItem, pos: Vector2, label: String, value: String, bounce: float) -> void:
	# ピンクのピルの中に数字。増えた瞬間に跳ねる
	var scale := 1.0 + 0.35 * bounce
	var text := "%s %s" % [label, value]
	var size := int(24 * scale)
	var w := text_width(text, size, true) + 36
	var h := 44.0 * scale
	var r := Rect2(pos.x, pos.y - h / 2.0, w, h)
	_box(colors.accent, NAVY, 3, int(h / 2.0), Color(NAVY, 0.3)).draw(ci.get_canvas_item(), r)
	draw_text(ci, Vector2(r.position.x, r.position.y + h * 0.5 + size * 0.36), text, size, "text_on_accent", HORIZONTAL_ALIGNMENT_CENTER, w, true)


const RAINBOW := [Color("ff5c7a"), Color("ff9f3d"), Color("ffd83d"), Color("6be06b"), Color("3fd2f2"), Color("4f7bff"), Color("b66dff")]


static func _back_out(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)


# ---------------- 音 ----------------

## ポップ: 丸い三角波とサイン波で、ぷよっとした音とキラキラしたアルペジオ
func build_sounds() -> Dictionary:
	var rotate := Synth.mix([
		[0.0, _click(9000, 0.35, 0.014, 220)],
		[0.0, Synth.tone(3200, 0.01, "triangle", 0.14, 300)],
		[0.012, _click(6000, 0.18, 0.016, 200)]])
	return {
		# 操作音はすべて短いクリックでそろえる（音程を滑らせない）
		# カチャ: ごく短く小さいクリック（DAS で連続して鳴るので控えめに）
		"move": Synth.mix([
			[0.0, _click(12000, 0.18, 0.008, 380)],
			[0.008, _click(9000, 0.05, 0.008, 380)]]),
		# カチッ: 移動より短く明るい
		"rotate": rotate,
		# カカッ: Tスピンの形に入った回転。回転音を大きくして、8ms 遅れで4半音下げたものを重ねる
		"tspin_rotate": _gain(Synth.mix([
			[0.0, rotate],
			[0.008, Synth.pitched(rotate, -4)]]), 1.5),
		# シャカッ: こすれる「シャ」からクリック
		"hold": Synth.mix([
			[0.0, _click(5000, 0.14, 0.05, 45)],
			[0.035, _click(8000, 0.35, 0.016, 200)],
			[0.035, Synth.tone(2200, 0.012, "triangle", 0.14, 300)]]),
		# コトッ: 置いたときの乾いた音
		"lock": Synth.mix([
			[0.0, _click(3000, 0.3, 0.02, 160)],
			[0.0, Synth.tone(900, 0.025, "triangle", 0.18, 150)]]),
		# カシャッ: 高めで短い、軽いクリック
		"hard_drop": Synth.mix([
			[0.0, _click(11000, 0.35, 0.014, 240)],
			[0.0, Synth.tone(1400, 0.02, "triangle", 0.14, 160)],
			[0.01, _click(7000, 0.15, 0.03, 120)]]),
		"clear1": _pluck([76]),
		"clear2": _pluck([76, 81]),
		"clear3": _pluck([76, 81, 84]),
		"tetris": Synth.mix([
			[0.0, _pluck([72, 76, 79, 84, 88], 0.045)],
			[0.2, _chord([84, 88, 91, 96], 0.6)],
			[0.2, _sparkle(10, 0.5)]]),
		"spin": Synth.mix([
			[0.0, Synth.tone(300, 0.2, "sine", 0.25, 8, 1400)],
			[0.0, Synth.tone(4000, 0.18, "noise", 0.05, 12)],
			[0.1, _pluck([79, 84, 88, 91], 0.04)]]),
		"b2b": _sparkle(6, 0.3),
		"combo": Synth.mix([
			[0.0, Synth.tone(Synth.midi(79), 0.16, "triangle", 0.25, 16)],
			[0.0, Synth.tone(Synth.midi(91), 0.1, "sine", 0.12, 25)]]),
		"perfect": Synth.mix([
			[0.0, _pluck([72, 76, 79, 84, 88, 91, 96], 0.06)],
			[0.45, _chord([72, 79, 84, 88, 91], 1.2)],
			[0.45, _sparkle(18, 1.0)]]),
		"level_up": _pluck([67, 72, 76, 79, 84], 0.06),
		"ready": Synth.tone(Synth.midi(76), 0.15, "sine", 0.3, 12),
		"go": Synth.mix([
			[0.0, Synth.tone(Synth.midi(88), 0.35, "sine", 0.3, 6)],
			[0.0, Synth.tone(Synth.midi(95), 0.35, "triangle", 0.1, 6)]]),
		"finish": Synth.mix([
			[0.0, _pluck([72, 76, 79, 84], 0.08)],
			[0.32, _chord([72, 76, 79, 84], 1.0)],
			[0.32, _sparkle(12, 0.8)]]),
		"game_over": Synth.mix([
			[0.0, Synth.tone(Synth.midi(72), 0.3, "triangle", 0.3, 6, Synth.midi(71))],
			[0.25, Synth.tone(Synth.midi(67), 0.3, "triangle", 0.3, 6, Synth.midi(66))],
			[0.5, Synth.tone(Synth.midi(64), 0.3, "triangle", 0.3, 6, Synth.midi(63))],
			[0.75, Synth.tone(Synth.midi(60), 0.7, "triangle", 0.3, 4, Synth.midi(55))]]),
		"menu_move": Synth.mix([
			[0.0, _click(8000, 0.3, 0.015, 220)],
			[0.0, Synth.tone(2800, 0.01, "triangle", 0.12, 300)]]),
		"menu_select": Synth.mix([
			[0.0, _click(8000, 0.35, 0.016, 200)],
			[0.01, Synth.tone(Synth.midi(91), 0.15, "sine", 0.14, 20)],
			[0.04, Synth.tone(Synth.midi(96), 0.18, "sine", 0.12, 18)]]),
		"menu_back": Synth.mix([
			[0.0, _click(4000, 0.3, 0.02, 160)],
			[0.018, _click(2500, 0.18, 0.025, 140)]]),
		# シュッ: 攻撃を送った
		"attack": Synth.mix([
			[0.0, Synth.tone(6000, 0.12, "noise", 0.12, 18)],
			[0.0, _click(10000, 0.25, 0.012, 260)]]),
		# ゴトッ: おじゃまがせり上がった
		"garbage_rise": Synth.mix([
			[0.0, _click(2000, 0.35, 0.03, 90)],
			[0.0, Synth.tone(500, 0.04, "triangle", 0.2, 80)]]),
		"win": Synth.mix([
			[0.0, _pluck([72, 76, 79, 84], 0.08)],
			[0.32, _chord([72, 76, 79, 84], 1.0)],
			[0.32, _sparkle(12, 0.8)]]),
		"lose": Synth.mix([
			[0.0, Synth.tone(Synth.midi(72), 0.3, "triangle", 0.3, 6)],
			[0.25, Synth.tone(Synth.midi(67), 0.3, "triangle", 0.3, 6)],
			[0.5, Synth.tone(Synth.midi(64), 0.6, "triangle", 0.3, 5)]]),
	}


## 短いノイズのクリック。freq が高いほど硬く明るい
func _gain(samples: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i in samples.size():
		samples[i] *= gain
	return samples


func _click(freq: float, volume: float, duration: float, decay := 180.0) -> PackedFloat32Array:
	return Synth.tone(freq, duration, "noise", volume, decay)


## 弾くような音を gap 秒ずつずらして鳴らす
func _pluck(notes: Array, gap := 0.05) -> PackedFloat32Array:
	var parts := []
	for i in notes.size():
		var f := Synth.midi(notes[i])
		parts.append([i * gap, Synth.tone(f, 0.22, "triangle", 0.22, 14)])
		parts.append([i * gap, Synth.tone(f * 2.0, 0.12, "sine", 0.08, 22)])
	return Synth.mix(parts)


func _chord(notes: Array, duration: float) -> PackedFloat32Array:
	var parts := []
	for n in notes:
		parts.append([0.0, Synth.tone(Synth.midi(n), duration, "sine", 0.1, 3.5)])
	return Synth.mix(parts)


## キラキラ: 高い音をランダムにちりばめる
func _sparkle(count: int, duration: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	var parts := []
	for i in count:
		var note: int = [96, 100, 103, 108][rng.randi_range(0, 3)]
		parts.append([rng.randf_range(0.0, duration), Synth.tone(Synth.midi(note), 0.1, "sine", 0.07, 30)])
	return Synth.mix(parts)
