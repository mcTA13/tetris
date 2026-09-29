extends Node
## Cold Clear 2 を使う強さで対戦画面を実際の速さで動かし、CPU が置けているか確かめる
## 実行: godot --path . tests/versus_cc_check.tscn

func _ready() -> void:
	App.versus_level = 5
	var scene: Node = load("res://scenes/versus.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(10.0).timeout
	var cpu: GameState = scene.cpu
	print("uses_cold_clear=%s pieces=%d sent=%d state=%d" % [scene.cpu_player.uses_cold_clear(), cpu.pieces_placed, cpu.lines_sent, scene.state])
	get_tree().quit()
