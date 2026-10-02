extends Node2D
## 設定画面。main（操作感など）/ pad・key（割り当て変更）の3ページ。

const SOFT_DROP_OPTIONS := [5, 10, 20, 40, App.SOFT_DROP_INSTANT]
const LABEL_STYLES := ["auto", "xbox", "ps"]
const ADJUSTABLE := ["language", "skin", "se_volume", "bgm_volume", "das", "arr", "soft_drop", "line_clear_delay", "are",
	"das_cut", "vibration", "confirm_b", "label_style", "assist"]
const WAIT_SECONDS := 5.0
const PANEL := Rect2(220, 100, 840, 580)
const ROW_H := 31

var _page := "main"
var _index := 0
var _waiting := 0.0             # 割り当て待ちの残り秒数
var _ignore_accept := false     # 割り当て直後、決定ボタンを離すまで無視する
var _time := 0.0


func _rows() -> Array:
	if _page == "main":
		return ADJUSTABLE + ["pad", "key", "reset", "back"]
	return InputSetup.REMAPPABLE + ["reset", "back"]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _waiting > 0.0:
		_waiting -= delta
		return
	if _ignore_accept:
		_ignore_accept = Input.is_action_pressed("accept") or Input.is_action_pressed("back")
		return

	var rows := _rows()
	var dir := InputSetup.menu_direction(delta)
	match dir:
		"down":
			_index = (_index + 1) % rows.size()
			Sfx.play("menu_move")
		"up":
			_index = (_index - 1 + rows.size()) % rows.size()
			Sfx.play("menu_move")
		"left", "right":
			if _page == "main" and rows[_index] in ADJUSTABLE:
				_change(rows[_index], -1 if dir == "left" else 1)
				Sfx.play("menu_move")
	if Input.is_action_just_pressed("accept"):
		_select(rows[_index])
		Sfx.play("menu_select")
	elif Input.is_action_just_pressed("back"):
		Sfx.play("menu_back")
		_leave_page()


func _input(event: InputEvent) -> void:
	if _waiting <= 0.0 or not event.is_pressed() or event.is_echo():
		return
	var value := -1
	if _page == "pad" and event is InputEventJoypadButton:
		value = event.button_index
	elif _page == "key" and event is InputEventKey:
		value = event.physical_keycode
	if value < 0:
		return
	var action: String = _rows()[_index]
	App.bindings[_page] = InputSetup.rebind(_page, action, value)
	Sfx.play("menu_select")
	InputSetup.apply(App.bindings, App.settings.confirm_b)
	App.save()
	_waiting = 0.0
	_ignore_accept = true
	get_viewport().set_input_as_handled()


func _change(key: String, step: int) -> void:
	var s := App.settings
	match key:
		"language":
			var i := (Loc.LANGUAGES.find(s.language) + step + Loc.LANGUAGES.size()) % Loc.LANGUAGES.size()
			s.language = Loc.LANGUAGES[i]
			App.apply_look()
		"skin":
			var names := App.SKINS.keys()
			s.skin = names[(names.find(s.skin) + step + names.size()) % names.size()]
			App.apply_look()
			Sfx.prepare()
		"se_volume":
			s.se_volume = clampi(s.se_volume + step, 0, 10)
		"bgm_volume":
			s.bgm_volume = clampi(s.bgm_volume + step, 0, 10)
			Bgm.update_volume()
		"das":
			s.das = clampi(s.das + step, 1, 20)
		"arr":
			s.arr = clampi(s.arr + step, 0, 10)
		"soft_drop":
			var i := clampi(SOFT_DROP_OPTIONS.find(s.soft_drop) + step, 0, SOFT_DROP_OPTIONS.size() - 1)
			s.soft_drop = SOFT_DROP_OPTIONS[i]
		"line_clear_delay":
			s.line_clear_delay = clampi(s.line_clear_delay + step, 0, 40)
		"are":
			s.are = clampi(s.are + step, 0, 20)
		"das_cut", "vibration":
			s[key] = not s[key]
		"assist":
			var modes := App.ASSIST_MODES
			s.assist = modes[(modes.find(s.assist) + step + modes.size()) % modes.size()]
		"confirm_b":
			s.confirm_b = not s.confirm_b
			InputSetup.apply(App.bindings, s.confirm_b)
			_ignore_accept = true
		"label_style":
			var i := (LABEL_STYLES.find(s.label_style) + step + LABEL_STYLES.size()) % LABEL_STYLES.size()
			s.label_style = LABEL_STYLES[i]


func _select(key: String) -> void:
	match key:
		"pad", "key":
			_page = key
			_index = 0
		"reset":
			if _page == "main":
				App.settings = App.DEFAULT_SETTINGS.duplicate()
			else:
				App.bindings.erase(_page)
			InputSetup.apply(App.bindings, App.settings.confirm_b)
			App.apply_look()
			Bgm.update_volume()
			App.save()
		"back":
			_leave_page()
		"language", "skin", "das_cut", "vibration", "confirm_b", "label_style", "assist":
			_change(key, 1)
		_:
			if _page != "main":
				_waiting = WAIT_SECONDS


func _leave_page() -> void:
	if _page == "main":
		App.save()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	else:
		var from := _page
		_page = "main"
		_index = _rows().find(from)


# ---------------- 描画 ----------------

func _label(key: String) -> String:
	if _page != "main" and key in InputSetup.REMAPPABLE:
		return Loc.t("act_" + key)
	return Loc.t("set_" + key)


func _value(key: String) -> String:
	if _page != "main":
		if key not in InputSetup.REMAPPABLE:
			return ""
		var labels := []
		for v in InputSetup.bindings_of(_page, key):
			labels.append(InputSetup.button_label(v) if _page == "pad" else InputSetup.key_label(v))
		return ", ".join(labels) if labels.size() > 0 else "---"
	var s := App.settings
	match key:
		"language":
			return Loc.LANGUAGE_NAMES[s.language]
		"skin":
			return App.skin.display_name()
		"se_volume":
			return "%d / 10" % s.se_volume
		"bgm_volume":
			return "%d / 10" % s.bgm_volume
		"das":
			return "%d F  (%d ms)" % [s.das, roundi(s.das * 1000.0 / 60.0)]
		"arr":
			return "%d F  (%d ms)" % [s.arr, roundi(s.arr * 1000.0 / 60.0)]
		"soft_drop":
			return Loc.t("instant") if s.soft_drop == App.SOFT_DROP_INSTANT else "x%d" % s.soft_drop
		"line_clear_delay", "are":
			return "%d F" % s[key]
		"das_cut", "vibration":
			return Loc.t("on") if s[key] else Loc.t("off")
		"assist":
			return Loc.t("assist_" + s.assist)
		"confirm_b":
			return InputSetup.button_label(JOY_BUTTON_B if s.confirm_b else JOY_BUTTON_A)
		"label_style":
			return Loc.t("style_" + s.label_style)
		"pad", "key":
			return ">"
	return ""


func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	var title: String = {"main": Loc.t("settings"), "pad": Loc.t("set_pad"), "key": Loc.t("set_key")}[_page]
	skin.draw_text(self, Vector2(0, 76), title, 44, "title", HORIZONTAL_ALIGNMENT_CENTER, 1280, true, 12)
	skin.draw_panel(self, PANEL)

	var rows := _rows()
	var top := PANEL.position.y + (PANEL.size.y - rows.size() * ROW_H) / 2.0
	for i in rows.size():
		var rect := Rect2(PANEL.position.x + 16, top + i * ROW_H, PANEL.size.x - 32, ROW_H - 3)
		var selected := i == _index
		skin.draw_item(self, rect, selected, _time)
		var role := "text_on_accent" if selected else "text"
		var base := Vector2(rect.position.x + 24, rect.position.y + 24)
		skin.draw_text(self, base, _label(rows[i]), 19, role, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		var value := _value(rows[i])
		if selected and _waiting > 0.0:
			value = Loc.t("press_button" if _page == "pad" else "press_key") % ceili(_waiting)
		elif selected and rows[i] in ADJUSTABLE:
			value = "◀  %s  ▶" % value
		skin.draw_text(self, Vector2(rect.position.x, base.y), value, 19, role, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 24, true)

	var hint := Loc.t("hint_settings") % [InputSetup.action_hint("accept"), InputSetup.action_hint("back")]
	if _page != "main":
		hint = Loc.t("hint_remap" if _page == "pad" else "hint_remap_key") % InputSetup.action_hint("accept")
	skin.draw_text(self, Vector2(0, 700), hint, 17, "text", HORIZONTAL_ALIGNMENT_CENTER, 1280)
