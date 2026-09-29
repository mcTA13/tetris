extends Node
## 演出と音の確認用: 音の生成時間とピーク、TETRIS 直後とハードドロップ直後のスクリーンショット
## 実行: godot --path . tests/fx_check.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var had_save := FileAccess.file_exists(App.SAVE_PATH)
	var saved_text := FileAccess.get_file_as_string(App.SAVE_PATH) if had_save else ""

	var t0 := Time.get_ticks_msec()
	var sounds: Dictionary = App.skin.build_sounds()
	print("sound build: %d ms" % (Time.get_ticks_msec() - t0))
	for k in sounds:
		var peak := 0.0
		for v in sounds[k]:
			peak = maxf(peak, absf(v))
		print("  %-12s %.2fs peak %.2f" % [k, sounds[k].size() / 44100.0, peak])

	App.mode = App.Mode.MARATHON
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	await _frames(2)
	scene._countdown = 1
	await _frames(3)
	var g: GameState = scene.game
	for i in 4:
		for x in 9:
			g.board.grid[Board.HEIGHT - 1 - i][x] = PieceData.T if x % 2 == 0 else PieceData.S
	g.piece = PieceData.I
	g.rot = 1
	g.pos = Vector2i(7, 20)
	g.hard_drop()
	await _frames(8)
	_save(out_dir + "/fx_tetris.png")
	await _frames(40)
	_save(out_dir + "/fx_tetris_later.png")

	if had_save:
		FileAccess.open(App.SAVE_PATH, FileAccess.WRITE).store_string(saved_text)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(App.SAVE_PATH))
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
