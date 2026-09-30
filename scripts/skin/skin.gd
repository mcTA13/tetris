class_name UiSkin
extends RefCounted
## 見た目（テイスト）の土台。画面側はレイアウトだけを決め、描き方はすべてスキンに任せる。
## 新しいテイストを作るときは、これを継承して色・フォント・描き方を上書きし、App.SKINS に登録する。

enum CellStyle { NORMAL, GHOST, PREVIEW, DIM, GUIDE }

## 色の役割。サブクラスで上書きする
var colors := {
	"bg_top": Color("0a0a14"), "bg_bottom": Color("0a0a14"),
	"panel": Color(0, 0, 0, 0.6), "panel_border": Color(1, 1, 1, 0.5), "shadow": Color(0, 0, 0, 0),
	"board": Color(0, 0, 0, 0.6), "grid": Color(1, 1, 1, 0.05),
	"text": Color.WHITE, "text_dim": Color(1, 1, 1, 0.55), "text_on_accent": Color.WHITE,
	"accent": Color(1, 1, 1, 0.12), "highlight": Color(1, 0.9, 0.4), "outline": Color.BLACK,
}
var piece_colors := {
	PieceData.I: Color("31c7ef"), PieceData.O: Color("f7d308"), PieceData.T: Color("ad4d9c"),
	PieceData.S: Color("42b642"), PieceData.Z: Color("ef2029"), PieceData.J: Color("5a65ad"),
	PieceData.L: Color("ef7921"), PieceData.GARBAGE: Color("6b6b6b"),
}
var font: Font = ThemeDB.fallback_font
var font_heavy: Font = ThemeDB.fallback_font
var radius := 0
var border := 2

var _boxes := {}
const MAX_CACHED_BOXES := 512


func display_name() -> String:
	return "BASIC"


# ---------------- 背景・パネル ----------------

func draw_background(ci: CanvasItem, size: Vector2, _time: float) -> void:
	# 画面が揺れても端が見えないよう、少しはみ出して描く
	var m := 60.0
	ci.draw_polygon(
		PackedVector2Array([Vector2(-m, -m), Vector2(size.x + m, -m), size + Vector2(m, m), Vector2(-m, size.y + m)]),
		PackedColorArray([colors.bg_top, colors.bg_top, colors.bg_bottom, colors.bg_bottom]))


func draw_panel(ci: CanvasItem, rect: Rect2, fill_role := "panel") -> void:
	_box(colors[fill_role], colors.panel_border, border, radius, colors.shadow).draw(ci.get_canvas_item(), rect)


## メニューの1項目の背景
func draw_item(ci: CanvasItem, rect: Rect2, selected: bool, _time: float) -> void:
	if selected:
		_box(colors.accent, Color.TRANSPARENT, 0, radius, Color.TRANSPARENT).draw(ci.get_canvas_item(), rect)


func draw_board(ci: CanvasItem, rect: Rect2, cell: float) -> void:
	draw_panel(ci, rect.grow(border), "board")
	var grid_width := 3.0
	var cols := int(rect.size.x / cell)
	var rows := int(rect.size.y / cell)
	for x in range(1, cols):
		ci.draw_line(rect.position + Vector2(x * cell, 0), rect.position + Vector2(x * cell, rect.size.y), colors.grid, grid_width)
	for y in range(1, rows):
		ci.draw_line(rect.position + Vector2(0, y * cell), rect.position + Vector2(rect.size.x, y * cell), colors.grid, grid_width)


# ---------------- ブロック ----------------

## flash: 0〜1。固定直後などに白く光らせる量（GUIDE では点滅の強さ）
func draw_cell(ci: CanvasItem, rect: Rect2, type: int, style := CellStyle.NORMAL, flash := 0.0) -> void:
	var color: Color = piece_colors[type]
	match style:
		CellStyle.GUIDE:
			ci.draw_rect(rect.grow(-2), Color(1, 1, 1, 0.5 + 0.5 * flash), false, 3.0)
			return
		CellStyle.GHOST:
			ci.draw_rect(rect.grow(-1), Color(color, 0.2))
			ci.draw_rect(rect.grow(-1), Color(color, 0.7), false, 2.0)
			return
		CellStyle.DIM:
			color = Color(0.5, 0.5, 0.5)
	color = color.lerp(Color.WHITE, flash)
	ci.draw_rect(rect.grow(-1), color)


# ---------------- 文字 ----------------

## pos はベースライン左端。width を渡すとその幅の中で align に従って揃える。
## role は色の役割名（colors のキー）か Color
func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, role: Variant = "text",
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, heavy := false, outline := 0) -> void:
	var f := font_heavy if heavy else font
	var color: Color = role if role is Color else colors[role]
	if outline > 0:
		ci.draw_string_outline(f, pos, text, align, width, size, outline, colors.outline)
	ci.draw_string(f, pos, text, align, width, size, color)


func text_width(text: String, size: int, heavy := false) -> float:
	return (font_heavy if heavy else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func draw_logo(ci: CanvasItem, center: Vector2, _time: float) -> void:
	draw_text(ci, center + Vector2(-400, 24), "TETRIS", 72, "text", HORIZONTAL_ALIGNMENT_CENTER, 800, true)


# ---------------- 演出 ----------------

## 演出の強さ。サブクラスで上書きして好みに調整する
var fx := {
	"particles_per_cell": 3,     # 消えたブロック1つあたりの粒の数
	"particle_speed": 420.0,
	"particle_gravity": 900.0,
	"shake_tetris": 10.0,        # 画面の揺れ（ピクセル）
	"shake_spin": 8.0,
	"shake_perfect": 16.0,
	"hard_drop_bump": 6.0,       # ハードドロップで盤面が沈む量
	"flash_alpha": 0.35,         # 大技のときの画面フラッシュ
}


## 消えていく行のブロック。progress: 0（消え始め）→ 1（消え終わり）
func draw_clearing_cell(ci: CanvasItem, rect: Rect2, type: int, progress: float) -> void:
	var s := 1.0 - progress
	var r := Rect2(rect.get_center() - rect.size * s / 2.0, rect.size * s)
	ci.draw_rect(r, Color(piece_colors[type].lerp(Color.WHITE, 0.8), s))


func draw_particle(ci: CanvasItem, pos: Vector2, size: float, color: Color, _rotation: float, alpha: float) -> void:
	ci.draw_rect(Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), Color(color, alpha))


## ハードドロップの残像。alpha は時間とともに 1 → 0
func draw_trail(ci: CanvasItem, rect: Rect2, color: Color, alpha: float) -> void:
	ci.draw_rect(rect, Color(color, 0.35 * alpha))


## 大技のときのフラッシュ。rect の範囲を光らせる
func draw_flash(ci: CanvasItem, rect: Rect2, alpha: float) -> void:
	ci.draw_rect(rect, Color(1, 1, 1, alpha))


## 大きな文字（TETRIS など）。t: 経過秒、duration: 表示時間、scale: 文字の大きさの倍率
func draw_popup(ci: CanvasItem, center: Vector2, lines: Array, t: float, duration: float, scale := 1.0) -> void:
	var alpha := clampf((duration - t) / 0.3, 0.0, 1.0)
	var y := center.y - (lines.size() - 1) * 24.0 * scale
	for line in lines:
		draw_text(ci, Vector2(center.x - 300, y), line, int(40 * scale), Color(colors.highlight, alpha), HORIZONTAL_ALIGNMENT_CENTER, 600, true, 8)
		y += 48 * scale


## おじゃまの予告ゲージ。rect は盤面の横の細長い枠（下が基準）
func draw_garbage_meter(ci: CanvasItem, rect: Rect2, lines: int, cell: float, _time: float) -> void:
	if lines <= 0:
		return
	var h := minf(lines * cell, rect.size.y)
	ci.draw_rect(Rect2(rect.position.x, rect.end.y - h, rect.size.x, h), Color(1, 0.2, 0.2))


## 攻撃が相手へ飛んでいく玉。t: 0（出発）→ 1（到着）
func draw_attack_orb(ci: CanvasItem, pos: Vector2, lines: int, _t: float) -> void:
	ci.draw_circle(pos, 6.0 + lines * 2.0, colors.highlight)


## 上下で選ぶメニュー（ポーズなど）。labels は表示する文字、index は選択中
func draw_menu_panel(ci: CanvasItem, center: Vector2, title: String, labels: Array, index: int, time: float) -> void:
	var item := Vector2(260, 52)
	var gap := item.y + 14
	var w := 340.0
	var h := 80 + labels.size() * gap + 10
	var panel := Rect2(center.x - w / 2, center.y - h / 2, w, h)
	draw_panel(ci, panel)
	draw_text(ci, Vector2(panel.position.x, panel.position.y + 54), title, 40, "highlight", HORIZONTAL_ALIGNMENT_CENTER, w, true)
	for i in labels.size():
		var selected := i == index
		var rect := Rect2(Vector2(center.x - item.x / 2, panel.position.y + 80 + i * gap), item)
		if not selected:
			draw_panel(ci, rect)
		draw_item(ci, rect, selected, time)
		draw_text(ci, Vector2(rect.position.x, rect.position.y + 36), labels[i], 26,
			"text_on_accent" if selected else "text", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## アシストでホールドをすすめるときに枠を光らせる。pulse: 0〜1
func draw_guide_box(ci: CanvasItem, rect: Rect2, pulse: float) -> void:
	ci.draw_rect(rect.grow(4), Color(1, 1, 1, 0.5 + 0.5 * pulse), false, 4.0)


## REN / B2B などのカウンター。bounce: 増えた直後 1 → 0
func draw_counter(ci: CanvasItem, pos: Vector2, label: String, value: String, bounce: float) -> void:
	var size := int(28 * (1.0 + 0.4 * bounce))
	draw_text(ci, pos, label, 16, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	draw_text(ci, pos + Vector2(0, 32), value, size, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


## 効果音。{名前: サンプル列}。名前は Sfx.play() で使うもの
func build_sounds() -> Dictionary:
	return {
		"move": Synth.tone(880, 0.03, "square", 0.12, 60),
		"rotate": Synth.tone(660, 0.05, "square", 0.15, 40),
		"hold": Synth.tone(440, 0.1, "square", 0.15, 20, 880),
		"lock": Synth.tone(200, 0.05, "square", 0.2, 40),
		"hard_drop": Synth.tone(160, 0.12, "square", 0.3, 25, 60),
		"clear1": Synth.arpeggio([72], 0.05, 0.15, "square", 0.15),
		"clear2": Synth.arpeggio([72, 76], 0.05, 0.15, "square", 0.15),
		"clear3": Synth.arpeggio([72, 76, 79], 0.05, 0.15, "square", 0.15),
		"tetris": Synth.arpeggio([72, 76, 79, 84], 0.05, 0.3, "square", 0.15),
		"spin": Synth.arpeggio([79, 84, 88], 0.04, 0.2, "square", 0.15),
		"b2b": Synth.arpeggio([91, 96], 0.04, 0.15, "square", 0.1),
		"combo": Synth.tone(Synth.midi(76), 0.12, "square", 0.15, 15),
		"perfect": Synth.arpeggio([72, 76, 79, 84, 88, 91, 96], 0.06, 0.4, "square", 0.12),
		"level_up": Synth.arpeggio([67, 72, 76, 79], 0.06, 0.2, "square", 0.12),
		"ready": Synth.tone(660, 0.12, "square", 0.15, 10),
		"go": Synth.tone(990, 0.3, "square", 0.15, 6),
		"finish": Synth.arpeggio([72, 76, 79, 84], 0.08, 0.5, "square", 0.12),
		"game_over": Synth.arpeggio([72, 67, 64, 60], 0.15, 0.4, "square", 0.12, 5),
		"menu_move": Synth.tone(880, 0.04, "square", 0.1, 40),
		"menu_select": Synth.arpeggio([79, 84], 0.05, 0.12, "square", 0.12),
		"menu_back": Synth.arpeggio([84, 76], 0.05, 0.12, "square", 0.12),
		"attack": Synth.tone(1200, 0.1, "square", 0.12, 20, 2400),
		"garbage_rise": Synth.tone(220, 0.08, "square", 0.2, 30),
		"win": Synth.arpeggio([72, 76, 79, 84], 0.08, 0.5, "square", 0.12),
		"lose": Synth.arpeggio([72, 67, 64, 60], 0.15, 0.4, "square", 0.12, 5),
	}


# ---------------- 内部 ----------------

func _box(fill: Color, border_color: Color, border_width: int, corner: int, shadow: Color) -> StyleBoxFlat:
	var key := [fill, border_color, border_width, corner, shadow]
	if _boxes.has(key):
		return _boxes[key]
	# 光りながら色が変わる描画もあるので、増えすぎたら作り直す
	if _boxes.size() > MAX_CACHED_BOXES:
		_boxes.clear()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner)
	box.corner_detail = 6
	box.anti_aliasing = true
	if shadow.a > 0.0:
		box.shadow_color = shadow
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 6)
	_boxes[key] = box
	return box
