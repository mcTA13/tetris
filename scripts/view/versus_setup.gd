extends Node2D
## CPU 対戦の準備画面（強さと試合形式）。
## 隠し: Lv.5 のときに LB+RB（キーボードは Q+E）を押しながら決定すると TAS が出る。

const ROWS := ["level", "first_to", "start", "back"]
const ITEM_SIZE := Vector2(560, 60)
const TOP := 200
const GAP := 76

var _index := 0
var _time := 0.0
var _tas_flash := 0.0


func _process(delta: float) -> void:
	_time += delta
	_tas_flash = maxf(_tas_flash - delta, 0.0)
	queue_redraw()
	match InputSetup.menu_direction(delta):
		"down":
			_index = (_index + 1) % ROWS.size()
			Sfx.play("menu_move")
		"up":
			_index = (_index - 1 + ROWS.size()) % ROWS.size()
			Sfx.play("menu_move")
		"left":
			_change(-1)
		"right":
			_change(1)
	if Input.is_action_just_pressed("accept"):
		if App.versus_level == 5 and _secret_held():
			App.versus_level = CpuPlayer.TAS_LEVEL
			_tas_flash = 1.0
			Sfx.play("perfect")
			return
		match ROWS[_index]:
			"start":
				Sfx.play("menu_select")
				App.save()
				get_tree().change_scene_to_file("res://scenes/versus.tscn")
			"back":
				_back()
			_:
				_change(1)
	elif Input.is_action_just_pressed("back"):
		_back()


func _change(step: int) -> void:
	match ROWS[_index]:
		"level":
			if App.versus_level == CpuPlayer.TAS_LEVEL:
				App.versus_level = 5  # TAS から動かしたら通常の強さに戻る
			else:
				App.versus_level = clampi(App.versus_level + step, 1, 5)
		"first_to":
			App.versus_first_to = clampi(App.versus_first_to + step, 1, 3)
		_:
			return
	Sfx.play("menu_move")


func _back() -> void:
	Sfx.play("menu_back")
	if App.versus_level == CpuPlayer.TAS_LEVEL:
		App.versus_level = 5
	App.save()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _secret_held() -> bool:
	if Input.is_physical_key_pressed(KEY_Q) and Input.is_physical_key_pressed(KEY_E):
		return true
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER) and Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
			return true
	return false


func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	skin.draw_text(self, Vector2(0, 110), Loc.t("versus_setup"), 56, "title", HORIZONTAL_ALIGNMENT_CENTER, 1280, true, 14)

	for i in ROWS.size():
		var selected := i == _index
		var rect := Rect2(Vector2(640 - ITEM_SIZE.x / 2, TOP + i * GAP), ITEM_SIZE)
		if not selected:
			skin.draw_panel(self, rect)
		skin.draw_item(self, rect, selected, _time)
		var role := "text_on_accent" if selected else "text"
		var base := Vector2(rect.position.x, rect.position.y + 41)
		match ROWS[i]:
			"level", "first_to":
				var label := Loc.t("cpu_level") if ROWS[i] == "level" else Loc.t("first_to")
				var value := Loc.t("level_%d" % App.versus_level) if ROWS[i] == "level" else Loc.t("first_to_value") % App.versus_first_to
				if selected:
					value = "◀  %s  ▶" % value
				skin.draw_text(self, base + Vector2(32, 0), label, 24, role, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
				skin.draw_text(self, base, value, 24, role, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 32, true)
			"start":
				skin.draw_text(self, base, Loc.t("start"), 28, role, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
			"back":
				skin.draw_text(self, base, Loc.t("set_back"), 24, role, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)

	# 選んでいる強さの戦績
	var record: Array = App.versus_record(App.versus_level)
	var text := "%s  %s" % [Loc.t("level_%d" % App.versus_level), Loc.t("record") % [record[0], record[1]]]
	var rw: float = skin.text_width(text, 22, true) + 60
	var rr := Rect2(640 - rw / 2, TOP + ROWS.size() * GAP + 12, rw, 46)
	skin.draw_panel(self, rr)
	skin.draw_text(self, Vector2(rr.position.x, rr.position.y + 32), text, 22, "highlight", HORIZONTAL_ALIGNMENT_CENTER, rw, true)

	if _tas_flash > 0.0:
		skin.draw_popup(self, Vector2(640, 380), ["TAS"], 1.4 - _tas_flash * 1.4, 1.4, 2.0)

	var hint := Loc.t("hint_versus_setup") % [InputSetup.action_hint("accept"), InputSetup.action_hint("back")]
	skin.draw_text(self, Vector2(0, 690), hint, 17, "text", HORIZONTAL_ALIGNMENT_CENTER, 1280)
