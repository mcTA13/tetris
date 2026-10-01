extends Node
## デモ（CPU Lv.4 どうし）が動き続けるか確かめる
## 実行: godot --path . tests/demo_check.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	App.demo = true
	App.demo_levels = [2, 5]  # 保存はしない
	var setup: Node = load("res://scenes/versus_setup.tscn").instantiate()
	add_child(setup)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out_dir + "/demo_setup.png")
	setup.queue_free()
	await get_tree().process_frame
	var scene: Node = load("res://scenes/versus.tscn").instantiate()
	add_child(scene)
	for i in 2:
		await get_tree().create_timer(5.0).timeout
		print("t=%ds round=%d state=%d wins=%s left(Lv.%d)=%d right(Lv.%d)=%d cc=%s/%s" % [(i + 1) * 5, scene.round_no, scene.state, str(scene.wins),
			scene._left_cpu.level, scene.player.pieces_placed, scene.cpu_player.level, scene.cpu.pieces_placed,
			scene._left_cpu.uses_cold_clear(), scene.cpu_player.uses_cold_clear()])
	get_viewport().get_texture().get_image().save_png(out_dir + "/demo.png")
	# 決着させて、自動で次のラウンドに進むか
	scene.player._game_over("check")
	await get_tree().create_timer(4.0).timeout
	print("after round end: round=%d state=%d wins=%s" % [scene.round_no, scene.state, str(scene.wins)])
	get_tree().quit()
