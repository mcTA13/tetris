extends Node
## 対戦画面の確認用: 準備画面、対戦中、一時停止、ラウンド決着、試合結果のスクリーンショット
## 実行: godot --path . tests/versus_shot.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	# 2 つ目の引数でテーマを指定できる（保存はしない）
	if args.size() > 1:
		App.settings.skin = args[1]
		App.apply_look()
	var had_save := FileAccess.file_exists(App.SAVE_PATH)
	var saved_text := FileAccess.get_file_as_string(App.SAVE_PATH) if had_save else ""

	var setup: Node = load("res://scenes/versus_setup.tscn").instantiate()
	add_child(setup)
	await _frames(5)
	_save(out_dir + "/vs_setup.png")
	setup.queue_free()
	await _frames(1)

	# 自分側も CPU に操作させて進める
	App.versus_level = 5
	App.versus_first_to = 2
	var scene: Node = load("res://scenes/versus.tscn").instantiate()
	add_child(scene)
	await _frames(2)
	scene._timer = 1
	scene._physics_process(1.0 / 60.0)
	var bot := CpuPlayer.new(scene.player, 3)
	for i in 60 * 20:
		bot.tick()
		scene._physics_process(1.0 / 60.0)
		if scene.state != scene.State.PLAYING:
			break
		if i % 30 == 0:
			await get_tree().process_frame
	await _frames(3)
	_save(out_dir + "/vs_play.png")

	scene.paused = true
	await _frames(3)
	_save(out_dir + "/vs_pause.png")
	scene.paused = false

	scene.player._game_over("test")
	scene._physics_process(1.0 / 60.0)
	await _frames(3)
	_save(out_dir + "/vs_round.png")

	scene.wins = [2, 1]
	scene._next_round()
	await _frames(3)
	_save(out_dir + "/vs_result.png")

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
