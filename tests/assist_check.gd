extends Node
## 40ラインのアシストが動くか確かめる（ガイドが出るか、その場所に行けるか）
## 実行: godot --path . tests/assist_check.tscn -- <出力フォルダ>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	App.mode = App.Mode.SPRINT_40L
	App.settings.assist = true  # 保存はしない
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	var guide: Dictionary = scene._field._guide
	var g: GameState = scene.game
	print("assist=%s guide=%s piece=%d" % [scene._assist != null, str(guide), g.piece])
	if not guide.is_empty():
		var start := Vector3i(g.pos.x, g.pos.y, g.rot)
		var type: int = guide.type
		if guide.hold:
			print("guide suggests hold")
		else:
			var target := {"x": guide.pos.x, "y": guide.pos.y, "rot": guide.rot, "spin": 0}
			print("reachable=%s" % (CpuBrain.path_to(CpuBrain.rows_from(g.board), type, start, target) != null))
	get_viewport().get_texture().get_image().save_png(out_dir + "/assist.png")
	get_tree().quit()
