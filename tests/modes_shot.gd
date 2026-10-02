extends Node
## 新しいメニューとモード（ウルトラ・掘り・Tスピン練習）の確認用スクリーンショット
## 実行: godot --path . tests/modes_shot.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var had_save := FileAccess.file_exists(App.SAVE_PATH)
	var saved_text := FileAccess.get_file_as_string(App.SAVE_PATH) if had_save else ""
	App.settings.assist = "off"  # 保存はしない

	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(6.0).timeout  # デモ盤面に少し積ませる
	_save(out_dir + "/menu_top.png")
	# カーソルの動き: 大分類の間を移る → 中に入る → 中だけを移る → 戻る
	title._cat = 0
	title._item = -1
	title._move(1)
	var after_move: Array = [title._cat, title._item]
	title._select()
	var after_enter: Array = [title._cat, title._item]
	title._move(1)
	var after_inner: Array = [title._cat, title._item]
	title._back()
	print("nav: move=%s enter=%s inner=%s back=%s" % [after_move, after_enter, after_inner, [title._cat, title._item]])
	title._cat = 0
	title._item = 2
	await _frames(4)
	_save(out_dir + "/menu_solo.png")
	title._cat = 2
	title._item = -1
	await _frames(4)
	_save(out_dir + "/menu_versus.png")
	print("title demo pieces=%d cold_clear=%s" % [title._demo_game.pieces_placed, title._demo_cpu.uses_cold_clear()])
	title.queue_free()

	for m in [App.Mode.ULTRA, App.Mode.DIG, App.Mode.PRACTICE]:
		App.mode = m
		var scene: Node = load("res://scenes/game.tscn").instantiate()
		add_child(scene)
		await _frames(2)
		scene._countdown = 1
		for _i in 400 if m == App.Mode.DIG else 30:
			scene._physics_process(1.0 / 60.0)
		if m == App.Mode.PRACTICE:
			# わざと失敗させて、正解のガイドが出るか
			scene.game.hard_drop()
			for _i in 40:
				scene._physics_process(1.0 / 60.0)
			print("practice after miss: attempts=%d hint=%s guide=%s" % [scene._attempts, scene._show_hint, str(scene._field._guide)])
		if m == App.Mode.ULTRA:
			# 2 分たったら TIME UP で終わるか
			scene.game.ticks = scene.ULTRA_TICKS - 1
			scene._physics_process(1.0 / 60.0)
			print("ultra after 2min: finished=%s phase=%d" % [scene.game.is_finished(), scene.game.phase])
		await _frames(4)
		_save(out_dir + "/mode_%d.png" % m)
		scene.queue_free()
		await _frames(1)

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
