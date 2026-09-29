extends Node2D
## タイトル・モード選択

const SETTINGS := -1
const ITEMS := [App.Mode.SPRINT_40L, App.Mode.MARATHON, SETTINGS]
const ITEM_SIZE := Vector2(380, 64)
const ITEM_TOP := 300
const ITEM_GAP := 80

var _index := 0
var _time := 0.0


func _ready() -> void:
	_index = maxi(ITEMS.find(App.mode), 0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var dir := InputSetup.menu_direction(delta)
	if dir == "down":
		_index = (_index + 1) % ITEMS.size()
		Sfx.play("menu_move")
	elif dir == "up":
		_index = (_index - 1 + ITEMS.size()) % ITEMS.size()
		Sfx.play("menu_move")
	elif Input.is_action_just_pressed("accept"):
		Sfx.play("menu_select")
		if ITEMS[_index] == SETTINGS:
			get_tree().change_scene_to_file("res://scenes/settings.tscn")
			return
		App.mode = ITEMS[_index]
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _draw() -> void:
	var skin: UiSkin = App.skin
	var w := 1280.0
	skin.draw_background(self, Vector2(1280, 720), _time)
	skin.draw_logo(self, Vector2(640, 150), _time)

	for i in ITEMS.size():
		var selected := i == _index
		var rect := Rect2(Vector2(640 - ITEM_SIZE.x / 2, ITEM_TOP + i * ITEM_GAP), ITEM_SIZE)
		if not selected:
			skin.draw_panel(self, rect)
		skin.draw_item(self, rect, selected, _time)
		var key: String = "menu_settings" if ITEMS[i] == SETTINGS else App.MODE_KEYS[ITEMS[i]]
		skin.draw_text(self, Vector2(rect.position.x, rect.position.y + 44), Loc.t(key), 32,
			"text_on_accent" if selected else "text", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)

	var record := ""
	if ITEMS[_index] == App.Mode.SPRINT_40L:
		var best := "--:--.---" if App.best_40l_ticks == 0 else App.format_time(App.best_40l_ticks)
		record = "%s  %s" % [Loc.t("best"), best]
	elif ITEMS[_index] == App.Mode.MARATHON:
		record = "%s  %d" % [Loc.t("high_score"), App.marathon_best_score]
	if record != "":
		var rw: float = skin.text_width(record, 24, true) + 60
		var rect := Rect2(640 - rw / 2, 548, rw, 48)
		skin.draw_panel(self, rect)
		skin.draw_text(self, Vector2(rect.position.x, rect.position.y + 34), record, 24, "highlight", HORIZONTAL_ALIGNMENT_CENTER, rw, true)

	skin.draw_text(self, Vector2(0, 660), Loc.t("hint_title") % InputSetup.action_hint("accept"), 18, "text", HORIZONTAL_ALIGNMENT_CENTER, w)
	var pads := []
	for device in Input.get_connected_joypads():
		pads.append("#%d %s" % [device, Input.get_joy_name(device)])
	var pad_text := "%s: %s" % [Loc.t("controller"), ", ".join(pads) if pads.size() > 0 else Loc.t("not_found")]
	skin.draw_text(self, Vector2(0, 700), pad_text, 14, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, w)
