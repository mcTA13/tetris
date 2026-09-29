extends Node
## アプリのアイコン画像を作る（POP スキンのブロックで T ミノを描く）。
## 実行: godot --path . tools/make_icon.tscn
## 出力: assets/icon/icon.png（256px）と icon_128/64/48/32/16.png。.ico は tools/pack_ico.py でまとめる

const SIZE := 256
const SMALL_SIZES := [128, 64, 48, 32, 16]


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(IconArt.new())
	for _i in 3:
		await RenderingServer.frame_post_draw

	var image := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icon"))
	image.save_png("res://assets/icon/icon.png")
	for s in SMALL_SIZES:
		var small := image.duplicate() as Image
		small.resize(s, s, Image.INTERPOLATE_LANCZOS)
		small.save_png("res://assets/icon/icon_%d.png" % s)
	print("icon saved")
	get_tree().quit()


class IconArt:
	extends Node2D

	const NAVY := Color("2b2350")
	const CELL := 56.0

	func _draw() -> void:
		var skin := PopSkin.new()
		# 角丸の台（ピンク地に白い水玉、紺の太いふち）
		var base := Rect2(10, 10, 236, 236)
		skin._box(Color("ffb8dc"), NAVY, 12, 56, Color.TRANSPARENT).draw(get_canvas_item(), base)
		for p in [Vector2(62, 58), Vector2(196, 64), Vector2(58, 204), Vector2(200, 200), Vector2(128, 40)]:
			draw_circle(p, 9.0, Color(1, 1, 1, 0.55))
		# T ミノ（紺のふち付き）
		var cells := PieceData.cells(PieceData.T, 0)
		var origin := Vector2(128 - CELL * 1.5, 138 - CELL)
		for c in cells:
			draw_rect(Rect2(origin + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(6), NAVY)
		for c in cells:
			skin.draw_cell(self, Rect2(origin + Vector2(c) * CELL, Vector2(CELL, CELL)), PieceData.T)
