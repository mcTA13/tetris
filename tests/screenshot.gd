extends Node
## 画面確認用: タイトル・プレイ中・リザルトのスクリーンショットを保存する
## 実行: godot --path . tests/screenshot.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	# 2 つ目の引数でテーマを指定できる（保存はしない）
	if args.size() > 1:
		App.settings.skin = args[1]
		App.apply_look()
	# 撮影で記録が書き換わらないよう、元の保存データを退避しておく
	var had_save := FileAccess.file_exists(App.SAVE_PATH)
	var saved_text := FileAccess.get_file_as_string(App.SAVE_PATH) if had_save else ""

	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(5)
	_save(out_dir + "/shot_title.png")
	var lang: String = App.settings.language
	App.settings.language = "en" if lang == "ja" else "ja"
	App.apply_look()
	await _frames(3)
	_save(out_dir + "/shot_title_other_lang.png")
	App.settings.language = lang
	App.apply_look()
	title.queue_free()

	var settings: Node = load("res://scenes/settings.tscn").instantiate()
	add_child(settings)
	await _frames(5)
	_save(out_dir + "/shot_settings.png")
	App.settings.label_style = "ps"
	settings._tab = 4
	settings._remap = true
	settings._index = 4
	settings._waiting = 3.5
	await _frames(5)
	_save(out_dir + "/shot_pad.png")
	settings.queue_free()
	App.settings.label_style = "auto"
	await _frames(1)

	App.mode = App.Mode.MARATHON
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	await _frames(2)
	scene._countdown = 1
	await _frames(3)
	var g: GameState = scene.game
	for i in 6:
		g.move(-3 + i)
		g.hard_drop()
		for _t in 25:
			g.tick()
	g.hold()
	scene._field._message = "B2B x1
T-SPIN DOUBLE
REN 2"
	scene._field._message_timer = 1.5
	await _frames(5)
	_save(out_dir + "/shot_game.png")
	scene.paused = true
	scene._pause_index = 1
	await _frames(3)
	_save(out_dir + "/shot_pause.png")
	scene.paused = false
	scene.queue_free()

	App.mode = App.Mode.SPRINT_40L
	scene = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	await _frames(2)
	scene._countdown = 1
	await _frames(3)
	g = scene.game
	g.line_goal = 1
	for x in 9:
		g.board.grid[Board.HEIGHT - 1][x] = PieceData.GARBAGE
	g.piece = PieceData.I
	g.rot = 1
	g.pos = Vector2i(7, 20)
	g.hard_drop()
	await _frames(5)
	_save(out_dir + "/shot_result.png")
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
