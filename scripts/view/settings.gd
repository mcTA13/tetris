extends Node2D
## 設定画面。上のタブ（LB / RB、キーボードは Q / E。一番上の行からさらに上でタブの行に入り、左右でも切り替え）で
## まとまりを選び、その中の項目を変える。選んでいる項目の説明を下に出す。
## 「コントローラー」タブのボタン割り当ては、項目を決定すると割り当ての一覧に入る。

const SOFT_DROP_OPTIONS := [5, 10, 20, 40, App.SOFT_DROP_INSTANT]
const LABEL_STYLES := ["auto", "xbox", "ps"]
const TABS := [
	{"key": "tab_display", "rows": ["language", "skin"]},
	{"key": "tab_sound", "rows": ["se_volume", "bgm_volume"]},
	{"key": "tab_handling", "rows": ["das", "arr", "soft_drop", "das_cut"]},
	{"key": "tab_game", "rows": ["line_clear_delay", "are", "assist"]},
	{"key": "tab_pad", "rows": ["confirm_b", "label_style", "vibration", "pad"]},
	{"key": "tab_key", "rows": []},  # キーボードの割り当ての一覧（InputSetup.REMAPPABLE）
]
const ADJUSTABLE := ["language", "skin", "se_volume", "bgm_volume", "das", "arr", "soft_drop", "line_clear_delay", "are",
	"das_cut", "vibration", "confirm_b", "label_style", "assist"]
const WAIT_SECONDS := 5.0
const TAB_Y := 120.0
const PANEL := Rect2(220, 170, 840, 400)
const ROW_H := 34
const DESC_RECT := Rect2(220, 582, 840, 82)

var _tab := 0
var _index := 0                 # -1 はタブの行
var _remap := false             # コントローラーのボタン割り当ての一覧を開いている
var _waiting := 0.0             # 割り当て待ちの残り秒数
var _ignore_accept := false     # 割り当て直後、決定ボタンを離すまで無視する
var _shoulders := [false, false]  # 前のフレームの LB / RB（Q / E）
var _time := 0.0


func _rows() -> Array:
	if _remap or TABS[_tab].key == "tab_key":
		return InputSetup.REMAPPABLE + ["reset"]
	return TABS[_tab].rows + ["reset"]


## 割り当てを変える一覧なら "pad" / "key"、そうでなければ空
func _bind_page() -> String:
	if _remap:
		return "pad"
	return "key" if TABS[_tab].key == "tab_key" else ""


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _waiting > 0.0:
		_waiting -= delta
		return
	if _ignore_accept:
		_ignore_accept = Input.is_action_pressed("accept") or Input.is_action_pressed("back")
		return

	var shoulder := _shoulder_pressed()
	if shoulder != 0 and not _remap:
		_switch_tab(shoulder)
	var rows := _rows()
	var dir := InputSetup.menu_direction(delta)
	match dir:
		"down":
			_index = (_index + 1) % rows.size() if _index >= 0 else 0
			Sfx.play("menu_move")
		"up":
			# 一番上からさらに上でタブの行へ（割り当ての一覧ではタブを変えない）
			_index = _index - 1 if _index > 0 else (-1 if _index == 0 and not _remap else rows.size() - 1)
			Sfx.play("menu_move")
		"left", "right":
			var step := -1 if dir == "left" else 1
			if _index < 0:
				_switch_tab(step)
			elif rows[_index] in ADJUSTABLE:
				_change(rows[_index], step)
				Sfx.play("menu_move")
	if Input.is_action_just_pressed("accept") and _index >= 0:
		_select(rows[_index])
		Sfx.play("menu_select")
	elif Input.is_action_just_pressed("back"):
		Sfx.play("menu_back")
		_leave()


## LB / RB（キーボードは Q / E）を押した瞬間なら -1 / 1
func _shoulder_pressed() -> int:
	var now := [Input.is_physical_key_pressed(KEY_Q), Input.is_physical_key_pressed(KEY_E)]
	for device in Input.get_connected_joypads():
		now[0] = now[0] or Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
		now[1] = now[1] or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
	var result := 0
	if now[0] and not _shoulders[0]:
		result = -1
	elif now[1] and not _shoulders[1]:
		result = 1
	_shoulders = now
	return result


func _switch_tab(step: int) -> void:
	_tab = (_tab + step + TABS.size()) % TABS.size()
	_index = mini(_index, _rows().size() - 1)
	Sfx.play("menu_move")


func _input(event: InputEvent) -> void:
	if _waiting <= 0.0 or not event.is_pressed() or event.is_echo():
		return
	var page := _bind_page()
	var value := -1
	if page == "pad" and event is InputEventJoypadButton:
		value = event.button_index
	elif page == "key" and event is InputEventKey:
		value = event.physical_keycode
	if value < 0:
		return
	var action: String = _rows()[_index]
	App.bindings[page] = InputSetup.rebind(page, action, value)
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
		"pad":
			_remap = true
			_index = 0
		"reset":
			_reset()
		"language", "skin", "das_cut", "vibration", "confirm_b", "label_style", "assist":
			_change(key, 1)
		_:
			if _bind_page() != "":
				_waiting = WAIT_SECONDS


## 今のタブ（割り当ての一覧ならその割り当て）だけを初期設定に戻す
func _reset() -> void:
	var page := _bind_page()
	if page != "":
		App.bindings.erase(page)
	else:
		for key in TABS[_tab].rows:
			if App.DEFAULT_SETTINGS.has(key):
				App.settings[key] = App.DEFAULT_SETTINGS[key]
	InputSetup.apply(App.bindings, App.settings.confirm_b)
	App.apply_look()
	Sfx.prepare()
	Bgm.update_volume()
	App.save()


func _leave() -> void:
	if _remap:
		_remap = false
		_index = TABS[_tab].rows.find("pad")
		return
	App.save()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# ---------------- 描画 ----------------

func _label(key: String) -> String:
	if _bind_page() != "" and key in InputSetup.REMAPPABLE:
		return Loc.t("act_" + key)
	return Loc.t("set_" + key)


func _value(key: String) -> String:
	var page := _bind_page()
	if page != "":
		if key not in InputSetup.REMAPPABLE:
			return ""
		var labels := []
		for v in InputSetup.bindings_of(page, key):
			labels.append(InputSetup.button_label(v) if page == "pad" else InputSetup.key_label(v))
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
		"pad":
			return ">"
	return ""


## 選んでいる項目の説明
func _description() -> String:
	if _index < 0:
		return Loc.t("desc_set_tabs")
	var key: String = _rows()[_index]
	var page := _bind_page()
	if key == "reset":
		return Loc.t("desc_set_reset_bindings" if page != "" else "desc_set_reset")
	if page != "":
		return Loc.t("hint_remap" if page == "pad" else "hint_remap_key") % InputSetup.action_hint("accept")
	return Loc.t("desc_set_" + key)


func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	skin.draw_text(self, Vector2(0, 76), Loc.t("settings"), 44, "title", HORIZONTAL_ALIGNMENT_CENTER, 1280, true, 12)
	_draw_tabs(skin)
	skin.draw_panel(self, PANEL)

	var rows := _rows()
	var top := PANEL.position.y + 16
	if _remap:
		skin.draw_text(self, Vector2(PANEL.position.x + 40, top + 22), Loc.t("set_pad"), 20, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		top += ROW_H
	for i in rows.size():
		var rect := Rect2(PANEL.position.x + 16, top + i * ROW_H, PANEL.size.x - 32, ROW_H - 4)
		var selected := i == _index
		skin.draw_item(self, rect, selected, _time)
		var role := "text_on_accent" if selected else "text"
		var base := Vector2(rect.position.x + 24, rect.position.y + 24)
		skin.draw_text(self, base, _label(rows[i]), 19, role, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		var value := _value(rows[i])
		if selected and _waiting > 0.0:
			value = Loc.t("press_button" if _bind_page() == "pad" else "press_key") % ceili(_waiting)
		elif selected and rows[i] in ADJUSTABLE:
			value = "◀  %s  ▶" % value
		skin.draw_text(self, Vector2(rect.position.x, base.y), value, 19, role, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 24, true)

	# 説明
	skin.draw_panel(self, DESC_RECT)
	_draw_wrapped(skin, _description(), Vector2(DESC_RECT.position.x + 24, DESC_RECT.position.y + 32), DESC_RECT.size.x - 48, 18)

	var hint := Loc.t("hint_settings") % [InputSetup.action_hint("accept"), InputSetup.action_hint("back")]
	skin.draw_text(self, Vector2(0, 700), hint, 17, "text", HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_tabs(skin: UiSkin) -> void:
	var w := PANEL.size.x / TABS.size()
	for i in TABS.size():
		var rect := Rect2(PANEL.position.x + i * w + 3, TAB_Y, w - 6, 40)
		var current := i == _tab
		skin.draw_panel(self, rect)
		if current and _index < 0:
			skin.draw_item(self, rect, true, _time)
		var role := "text_on_accent" if current and _index < 0 else ("highlight" if current else "text_dim")
		skin.draw_text(self, Vector2(rect.position.x, rect.position.y + 28), Loc.t(TABS[i].key), 17, role, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
	# タブを切り替えるボタン
	skin.draw_text(self, Vector2(PANEL.position.x - 70, TAB_Y + 28), _shoulder_label(0), 16, "text_dim", HORIZONTAL_ALIGNMENT_RIGHT, 60, true)
	skin.draw_text(self, Vector2(PANEL.end.x + 10, TAB_Y + 28), _shoulder_label(1), 16, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _shoulder_label(side: int) -> String:
	var pad := InputSetup.button_label(JOY_BUTTON_LEFT_SHOULDER if side == 0 else JOY_BUTTON_RIGHT_SHOULDER)
	return "%s / %s" % [pad, "Q" if side == 0 else "E"]


## 幅に収まるように折り返して描く
func _draw_wrapped(skin: UiSkin, text: String, pos: Vector2, width: float, size: int) -> void:
	var line := ""
	var y := pos.y
	for ch in text:
		if skin.text_width(line + ch, size, true) > width:
			skin.draw_text(self, Vector2(pos.x, y), line, size, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
			line = ""
			y += size * 1.6
		line += ch
	if line != "":
		skin.draw_text(self, Vector2(pos.x, y), line, size, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
