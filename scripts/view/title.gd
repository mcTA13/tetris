extends Node2D
## タイトル。左に大分類のメニュー（決定した大分類の中身が開く）、
## 右に選んでいるものの説明・記録と、CPU（Lv.4）が積み続ける小さなデモ盤面。
## 新しい版があれば、メニューの最後に「アップデート」が出る。

const CATEGORIES := [
	{"key": "cat_solo", "items": ["40l", "marathon", "ultra", "dig"]},
	{"key": "cat_practice", "items": ["practice"]},
	{"key": "cat_versus", "items": ["versus", "demo"]},
	{"key": "menu_settings", "items": []},  # 中身なし: 決定でそのまま設定画面へ
]
const UPDATE_CATEGORY := {"key": "menu_update", "items": []}
const ITEM_LABELS := {
	"40l": "mode_40l", "marathon": "mode_marathon", "ultra": "mode_ultra", "dig": "mode_dig",
	"practice": "mode_practice", "versus": "mode_versus", "demo": "mode_demo",
}
const ITEM_MODES := {
	"40l": App.Mode.SPRINT_40L, "marathon": App.Mode.MARATHON, "ultra": App.Mode.ULTRA,
	"dig": App.Mode.DIG, "practice": App.Mode.PRACTICE,
}
const MENU_X := 90.0
const MENU_W := 400.0
const MENU_TOP := 196.0
const CAT_H := 58.0
const ITEM_H := 46.0
const PANEL := Rect2(560, 150, 660, 480)
const DEMO_CELL := 16.0
const DEMO_POS := Vector2(1020, 280)
const DEMO_LEVEL := 4
const NOTE_SIZE := 17
const NOTE_LINE_H := NOTE_SIZE * 1.6

var _categories: Array = CATEGORIES.duplicate()
var _cat := 0                   # カーソルのある大分類
var _item := -1                 # 大分類の中の項目（-1 は大分類そのもの）
var _update_open := false       # アップデートを決定して、リリースノートを全部見ている
var _note_scroll := 0           # リリースノートの何行目から見せるか
var _note_rows := []            # 折り返したリリースノート [文字列, 色の役割]（最初に描くときに作る）
var _time := 0.0
var _demo_view := FieldView.new()
var _demo_game: GameState
var _demo_cpu: CpuPlayer


func _ready() -> void:
	Bgm.stop()
	_refresh_update()
	Updater.changed.connect(_refresh_update)
	# ゲームから戻ってきたら、遊んでいたモードにカーソルを合わせる
	for i in _categories.size():
		if _categories[i].key == App.menu_category:
			_cat = i
			var items: Array = _categories[i].items
			for j in items.size():
				if (items[j] == "demo" and App.demo) or (ITEM_MODES.get(items[j], -1) == App.mode and not App.demo):
					_item = j
	App.demo = false

	_demo_view.cell = DEMO_CELL
	_demo_view.show_side = false
	_demo_view.muted = true
	add_child(_demo_view)
	_demo_view.set_base_position(DEMO_POS)
	_restart_demo()


## 新しい版が見つかったら、メニューの最後に「アップデート」を足す
func _refresh_update() -> void:
	if Updater.available and not _categories.has(UPDATE_CATEGORY):
		_categories.append(UPDATE_CATEGORY)


func _exit_tree() -> void:
	if _demo_cpu != null:
		_demo_cpu.shutdown()


func _restart_demo() -> void:
	if _demo_cpu != null:
		_demo_cpu.shutdown()
	_demo_game = GameState.new()
	_demo_game.fixed_level = 1
	_demo_view.setup(_demo_game, false)
	_demo_cpu = CpuPlayer.new(_demo_game, DEMO_LEVEL)
	_demo_game.start()


func _physics_process(_delta: float) -> void:
	_demo_cpu.tick()
	_demo_game.tick()
	if _demo_game.is_finished():
		_restart_demo()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_demo_view.visible = _categories[_cat].key != "menu_update"  # アップデートはパネルを広く使う
	if Updater.downloading:
		return  # ダウンロードが終わるとゲームを終えてインストーラーを動かすので、ほかの画面には行かせない
	if _update_open:
		_process_update(delta)
		return
	match InputSetup.menu_direction(delta):
		"down":
			_move(1)
		"up":
			_move(-1)
		"right":
			if _item < 0:
				_select()
		"left":
			if _item >= 0:
				_back()
	if Input.is_action_just_pressed("accept"):
		_select()
	elif Input.is_action_just_pressed("back") and _item >= 0:
		_back()


## リリースノートを見ている間: 上下でスクロール、決定でアップデート、戻るでやめる
func _process_update(delta: float) -> void:
	match InputSetup.menu_direction(delta):
		"down":
			_note_scroll = mini(_note_scroll + 1, maxi(_note_rows.size() - _notes_visible(true), 0))
		"up":
			_note_scroll = maxi(_note_scroll - 1, 0)
		"left":
			_close_update()
	if Input.is_action_just_pressed("accept"):
		Sfx.play("menu_select")
		Updater.start()
	elif Input.is_action_just_pressed("back"):
		_close_update()


func _close_update() -> void:
	Sfx.play("menu_back")
	_update_open = false


## 上下の移動。大分類を選んでいるときは大分類の間だけ、項目を選んでいるときはその大分類の中だけ
func _move(step: int) -> void:
	if _item < 0:
		_cat = (_cat + step + _categories.size()) % _categories.size()
		App.menu_category = _categories[_cat].key
	else:
		var count: int = _categories[_cat].items.size()
		_item = (_item + step + count) % count
	Sfx.play("menu_move")


func _select() -> void:
	var items: Array = _categories[_cat].items
	Sfx.play("menu_select")
	if _item < 0:
		if _categories[_cat].key == "menu_update":
			_update_open = true
			_note_scroll = 0
		elif items.is_empty():
			get_tree().change_scene_to_file("res://scenes/settings.tscn")
		else:
			_item = 0
			App.menu_category = _categories[_cat].key
		return
	var item: String = items[_item]
	App.menu_category = _categories[_cat].key
	match item:
		"versus", "demo":
			App.demo = item == "demo"
			get_tree().change_scene_to_file("res://scenes/versus_setup.tscn")
		_:
			App.mode = ITEM_MODES[item]
			get_tree().change_scene_to_file("res://scenes/game.tscn")


func _back() -> void:
	Sfx.play("menu_back")
	_item = -1


# ---------------- 描画 ----------------

func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	skin.draw_logo(self, Vector2(MENU_X + MENU_W / 2, 100), _time)
	_draw_menu(skin)
	_draw_preview(skin)

	var hint := Loc.t("hint_title") % InputSetup.action_hint("accept")
	if _update_open:
		hint = Loc.t("hint_update") % [InputSetup.action_hint("accept"), InputSetup.action_hint("back")]
	elif _item >= 0:
		hint += "　%s: %s" % [InputSetup.action_hint("back"), Loc.t("set_back")]
	skin.draw_text(self, Vector2(0, 676), hint, 18, "text", HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var pads := []
	for device in Input.get_connected_joypads():
		pads.append("#%d %s" % [device, Input.get_joy_name(device)])
	var pad_text := "%s: %s" % [Loc.t("controller"), ", ".join(pads) if pads.size() > 0 else Loc.t("not_found")]
	skin.draw_text(self, Vector2(0, 704), pad_text, 14, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, 1280)
	skin.draw_text(self, Vector2(1260 - 200, 704), "v" + Updater.current_version(), 14, "text_dim", HORIZONTAL_ALIGNMENT_RIGHT, 200)


## 左のメニュー。大分類は決定するまで閉じたまま、開いている大分類だけ中身を見せる
func _draw_menu(skin: UiSkin) -> void:
	var y := MENU_TOP
	for i in _categories.size():
		var c: Dictionary = _categories[i]
		var rect := Rect2(MENU_X, y, MENU_W, CAT_H - 8)
		var selected := i == _cat and _item < 0
		var open := i == _cat and _item >= 0
		if not selected:
			skin.draw_panel(self, rect)
		skin.draw_item(self, rect, selected, _time)
		var mark := ""
		if i == _cat and not c.items.is_empty():
			mark = "▼ " if open else "▶ "
		skin.draw_text(self, Vector2(rect.position.x + 24, rect.position.y + 36), mark + Loc.t(c.key), 26,
			"text_on_accent" if selected else "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		y += CAT_H
		if not open:
			continue
		for j in c.items.size():
			var item_rect := Rect2(MENU_X + 36, y, MENU_W - 36, ITEM_H - 6)
			var item_selected: bool = j == _item
			skin.draw_item(self, item_rect, item_selected, _time)
			# 大分類を選んでいる間は、中身はまだ選べないので薄く見せる
			var role := "text_on_accent" if item_selected else ("text_dim" if _item < 0 else "text")
			skin.draw_text(self, Vector2(item_rect.position.x + 22, item_rect.position.y + 29), Loc.t(ITEM_LABELS[c.items[j]]), 22,
				role, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
			y += ITEM_H
		y += 6


## 右のパネル: 名前・説明・記録と、デモ盤面の見出し
func _draw_preview(skin: UiSkin) -> void:
	skin.draw_panel(self, PANEL)
	var c: Dictionary = _categories[_cat]
	var item: String = c.items[_item] if _item >= 0 else ""
	var title := Loc.t(ITEM_LABELS[item]) if item != "" else Loc.t(c.key)
	var desc := Loc.t("desc_" + item) if item != "" else Loc.t("desc_" + c.key)
	var left := PANEL.position.x + 36
	var text_w := DEMO_POS.x - left - 30
	if c.key == "menu_update":
		_draw_update(skin, left, PANEL.size.x - 72)
		return
	skin.draw_text(self, Vector2(left, PANEL.position.y + 70), title, 40, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	draw_line(Vector2(left, PANEL.position.y + 92), Vector2(left + text_w, PANEL.position.y + 92), skin.colors.text_dim, 2.0)
	_draw_wrapped(skin, desc, Vector2(left, PANEL.position.y + 136), text_w, 20)
	# 大分類を選んでいる間は、その中身を一覧で見せる
	if item == "":
		for j in c.items.size():
			skin.draw_text(self, Vector2(left + 8, PANEL.position.y + 240 + j * 44), "・" + Loc.t(ITEM_LABELS[c.items[j]]), 24,
				"text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var record := _record_text(item)
	if record != "":
		skin.draw_text(self, Vector2(left, PANEL.end.y - 40), record, 24, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	# デモ盤面の見出し
	# 出現したミノは盤面の上に 2 段はみ出すので、そのさらに上に置く
	skin.draw_text(self, Vector2(DEMO_POS.x, DEMO_POS.y - FieldView.SHOW_HIDDEN_ROWS * DEMO_CELL - 10), "DEMO  CPU Lv.%d" % DEMO_LEVEL, 15, "text_dim",
		HORIZONTAL_ALIGNMENT_CENTER, Board.WIDTH * DEMO_CELL, true)


## アップデートのパネル。カーソルを合わせただけなら説明とリリースノートの冒頭、決定したらリリースノートを全部（スクロール）
func _draw_update(skin: UiSkin, left: float, width: float) -> void:
	if _note_rows.is_empty():
		for entry in Updater.note_lines(Updater.notes):
			for piece in _wrap(skin, entry[0], width, NOTE_SIZE):
				_note_rows.append([piece, "highlight" if entry[1] else "text"])
	var title := Loc.t("update_notes_title") % Updater.latest_version if _update_open else Loc.t("menu_update")
	skin.draw_text(self, Vector2(left, PANEL.position.y + 70), title, 40, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	draw_line(Vector2(left, PANEL.position.y + 92), Vector2(left + width, PANEL.position.y + 92), skin.colors.text_dim, 2.0)
	var y := PANEL.position.y + 130
	if not _update_open:
		y = _draw_wrapped(skin, Loc.t("desc_menu_update") % Updater.latest_version, Vector2(left, y), width, 20) + 12
	var count := _notes_visible(_update_open)
	var first := _note_scroll if _update_open else 0
	for i in range(first, mini(first + count, _note_rows.size())):
		skin.draw_text(self, Vector2(left, y), _note_rows[i][0], NOTE_SIZE, _note_rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		y += NOTE_LINE_H
	# 続きがあることを示す
	if first + count < _note_rows.size():
		skin.draw_text(self, Vector2(left, y), "▼", NOTE_SIZE, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var bottom := "v%s → v%s" % [Updater.current_version(), Updater.latest_version]
	if _update_open or Updater.downloading or Updater.failed:
		bottom = _update_status()
	skin.draw_text(self, Vector2(left, PANEL.end.y - 30), bottom, 22, "highlight", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


## リリースノートを何行見せられるか（決定前は説明の下に冒頭だけ）
func _notes_visible(open: bool) -> int:
	return 11 if open else 7


func _update_status() -> String:
	if Updater.downloading:
		return Loc.t("update_downloading") % roundi(Updater.progress() * 100)
	if Updater.failed:
		return Loc.t("update_failed")
	return Loc.t("update_confirm" if Updater.is_installed() else "update_confirm_page")


## 幅に収まるように折り返す
func _wrap(skin: UiSkin, text: String, width: float, size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for ch in text:
		if skin.text_width(line + ch, size, true) > width:
			lines.append(line)
			line = ""
		line += ch
	if line != "":
		lines.append(line)
	return lines


## 幅に収まるように折り返して描く。次の行の y を返す
func _draw_wrapped(skin: UiSkin, text: String, pos: Vector2, width: float, size: int) -> float:
	var y := pos.y
	for line in _wrap(skin, text, width, size):
		skin.draw_text(self, Vector2(pos.x, y), line, size, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		y += size * 1.6
	return y


func _record_text(item: String) -> String:
	match item:
		"40l":
			var best := "--:--.---" if App.best_40l_ticks == 0 else App.format_time(App.best_40l_ticks)
			return "%s  %s" % [Loc.t("best"), best]
		"marathon":
			return "%s  %d" % [Loc.t("high_score"), App.marathon_best_score]
		"ultra":
			return "%s  %d" % [Loc.t("high_score"), App.ultra_best_score]
		"dig":
			return "%s  %d" % [Loc.t("best"), App.dig_best]
		"versus":
			var r: Array = App.versus_record(App.versus_level)
			return "%s  %s" % [Loc.t("level_%d" % App.versus_level), Loc.t("record") % [r[0], r[1]]]
		"demo":
			return Loc.t("demo_desc") % [App.demo_levels[0], App.demo_levels[1]]
	return ""
