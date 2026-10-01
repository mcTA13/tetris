extends Node2D
## 1人用のゲーム画面（40ライン / マラソン）。盤面の描画と演出は FieldView、
## ここでは入力・進行・情報パネル・バナー・ポーズを受け持つ。
## 40ラインでアシストがオンなら、Cold Clear 2 のおすすめの置き場所をガイドとして出す。

const CELL := 30.0
const BOARD_POS := Vector2(490, 70)
const HOLD_RECT := Rect2(318, 70, 148, 124)
const NEXT_RECT := Rect2(814, 70, 148, 440)
const STATS_RECT := Rect2(298, 214, 168, 0)  # 高さは項目数で決まる
const STAT_H := 62
const COUNTER_POS := Vector2(814, 548)
const READY_TICKS := 45
const GO_TICKS := 30
const ASSIST_THINK_TICKS := 9   # アシスト: おすすめを聞くまで Cold Clear 2 に考えさせる時間
# 6-3 積み（左 6 列・右 3 列、左から 7 列目を井戸）用の Cold Clear 2 の設定
const SIX_THREE_CONFIG := "cold-clear-2-six-three.json"
const PAUSE_ITEMS := ["resume", "retry", "to_title"]  # Loc のキー

var game: GameState
var input: InputHandler
var paused := false
var _pause_index := 0
var _countdown := 0             # READY 表示の残り tick
var _go_timer := 0
var _new_record := false
var _last_level := 1
var _time := 0.0
var _field := FieldView.new()
var _overlay := Node2D.new()    # 盤面より手前に描くもの（バナー・ポーズ）
var _assist: ColdClearBot       # 40ラインのアシスト（使わないときは null）
var _assist_wait := -1          # おすすめを聞くまでの残り tick
var _assist_asked := false
var _assist_pending := false    # Cold Clear 2 の準備ができたら聞く


func _ready() -> void:
	_field.cell = CELL
	_field.board_pos = BOARD_POS
	_field.hold_rect = HOLD_RECT
	_field.next_rect = NEXT_RECT
	_field.counter_pos = COUNTER_POS
	add_child(_field)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	if App.mode == App.Mode.SPRINT_40L and App.settings.assist != "off" and ColdClearBot.available():
		_assist = ColdClearBot.new()
		if not _assist.launch(SIX_THREE_CONFIG if App.settings.assist == "six_three" else ""):
			_assist = null
	_new_game()


func _exit_tree() -> void:
	if _assist != null:
		_assist.quit()


func _new_game() -> void:
	game = GameState.new()
	if App.mode == App.Mode.SPRINT_40L:
		game.fixed_level = 1
		game.line_goal = 40
	# マラソンは終わりなし（ゲームオーバーまで）
	game.event.connect(_on_game_event)
	_field.setup(game, true)
	var stats_h := _stats().size() * STAT_H + 16
	_field.message_rect = Rect2(STATS_RECT.position.x - 20, STATS_RECT.position.y + stats_h + 44, STATS_RECT.size.x + 40, 0)
	input = InputHandler.new(game)
	App.configure(game, input)
	input.prime(InputSetup.poll()[0])
	InputSetup.clear_pressed()
	paused = false
	_new_record = false
	_countdown = READY_TICKS
	_go_timer = 0
	_last_level = game.level
	_assist_wait = -1
	_assist_asked = false
	_assist_pending = false
	_field.clear_guide()
	Sfx.play("ready")


func _physics_process(delta: float) -> void:
	var state: Array = InputSetup.poll()
	var held: Dictionary = state[0]
	var pressed: Dictionary = state[1]
	if pressed.get("retry", false):
		_new_game()
		return
	if game.is_finished():
		if pressed.get("accept", false):
			_new_game()
		elif pressed.get("back", false):
			_to_title()
		return
	if paused:
		_update_pause_menu(delta, pressed)
		return
	if pressed.get("pause", false):
		paused = true
		_pause_index = 0
		InputSetup.menu_direction(0.0)  # 押しっぱなしの十字キーで選択が動かないようにする
		Sfx.play("menu_select")
		return

	_update_assist()
	# READY 中も DAS を溜めたり、回転・ホールドを先行入力できる
	input.update(held, pressed)
	if _countdown > 0:
		_countdown -= 1
		if _countdown == 0:
			game.start()
			_go_timer = GO_TICKS
			Sfx.play("go")
		return
	_go_timer = maxi(_go_timer - 1, 0)
	game.tick()
	if game.level > _last_level:
		_last_level = game.level
		Sfx.play("level_up")
		_field.fx.queue_popup(["LEVEL UP!", "LEVEL %d" % game.level])


## ポーズ中: 上下で選んで決定。ポーズ / 戻るボタンでそのまま再開
func _update_pause_menu(delta: float, pressed: Dictionary) -> void:
	match InputSetup.menu_direction(delta):
		"down":
			_pause_index = (_pause_index + 1) % PAUSE_ITEMS.size()
			Sfx.play("menu_move")
		"up":
			_pause_index = (_pause_index - 1 + PAUSE_ITEMS.size()) % PAUSE_ITEMS.size()
			Sfx.play("menu_move")
	if pressed.get("pause", false) or pressed.get("back", false):
		paused = false
		Sfx.play("menu_back")
	elif pressed.get("accept", false):
		Sfx.play("menu_select")
		match PAUSE_ITEMS[_pause_index]:
			"resume":
				paused = false
			"retry":
				_new_game()
			"to_title":
				_to_title()


## アシスト: ミノが出たら（ホールドを含む）盤面を送り、少し考えさせてからおすすめを聞く
func _request_assist() -> void:
	_field.clear_guide()
	_assist_asked = false
	if not _assist.is_ready:
		_assist_pending = true
		return
	_assist_pending = false
	_assist.start(game)
	_assist_wait = ASSIST_THINK_TICKS


func _update_assist() -> void:
	if _assist == null:
		return
	var r := _assist.poll()
	if _assist_pending and _assist.is_ready and game.can_control():
		_request_assist()
	if _assist_wait > 0:
		_assist_wait -= 1
		if _assist_wait == 0:
			_assist.suggest()
			_assist_asked = true
	if not r.is_empty() and _assist_asked:
		_assist_asked = false
		if not r.has("none") and game.can_control():
			_field.set_guide(r.type, Vector2i(r.x, r.y), r.rot, r.type != game.piece)


func _to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_overlay.queue_redraw()


func _on_game_event(kind: String, _data: Dictionary) -> void:
	match kind:
		"spawn":
			if _assist != null:
				_request_assist()
		"lock":
			_field.clear_guide()
			_assist_wait = -1
			_assist_asked = false
		"finished":
			Sfx.play("finish")
			if App.mode == App.Mode.SPRINT_40L:
				# アシストを使ったタイムは自己ベストにしない
				_new_record = false if _assist != null else App.submit_40l(game.ticks)
			else:
				_new_record = App.submit_marathon(game.score)
		"game_over":
			Sfx.play("game_over")
			if App.mode == App.Mode.MARATHON:
				_new_record = App.submit_marathon(game.score)


# ---------------- 描画 ----------------

func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	_draw_stats()
	var hint := Loc.t("hint_game") % [InputSetup.action_hint("retry"), InputSetup.action_hint("pause")]
	skin.draw_text(self, Vector2(24, 700), hint, 15, "text")


## 盤面より手前: READY / GO、リザルト、ポーズ
func _draw_overlay() -> void:
	var skin: UiSkin = App.skin
	var center := BOARD_POS + Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * CELL / 2.0
	if game.is_finished():
		_draw_result(center)
	elif paused:
		var labels := PAUSE_ITEMS.map(func(k): return Loc.t(k))
		skin.draw_menu_panel(_overlay, center, Loc.t("pause"), labels, _pause_index, _time)
	elif _countdown > 0:
		draw_banner(_overlay, center, [Loc.t("ready")])
	elif _go_timer > 0 and game.pieces_placed == 0:  # 置き始めたら消す（大技の文字とかぶらないように）
		draw_banner(_overlay, center, [Loc.t("go")])


func _stats() -> Array:
	var seconds := game.ticks / 60.0
	var pps := game.pieces_placed / seconds if seconds > 0 else 0.0
	if App.mode == App.Mode.SPRINT_40L:
		var s := [[Loc.t("time"), App.format_time(game.ticks)], [Loc.t("lines"), "%d / 40" % mini(game.lines, 40)], [Loc.t("pps"), "%.2f" % pps]]
		if _assist != null:
			s.append([Loc.t("assist"), Loc.t("assist_" + App.settings.assist)])
		return s
	return [[Loc.t("score"), str(game.score)], [Loc.t("level"), str(game.level)],
		[Loc.t("lines"), str(game.lines)], [Loc.t("time"), App.format_time(game.ticks)]]


func _draw_stats() -> void:
	var skin: UiSkin = App.skin
	var stats := _stats()
	var rect := STATS_RECT
	rect.size.y = stats.size() * STAT_H + 16
	skin.draw_panel(self, rect)
	for i in stats.size():
		var top := rect.position.y + 10 + i * STAT_H
		skin.draw_text(self, Vector2(rect.position.x + 16, top + 20), stats[i][0], 15, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		skin.draw_text(self, Vector2(rect.position.x + 16, top + 50), stats[i][1], 26, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _draw_result(center: Vector2) -> void:
	var lines := []
	var seconds := game.ticks / 60.0
	if App.mode == App.Mode.SPRINT_40L:
		if game.phase == GameState.Phase.CLEARED:
			lines = [Loc.t("finish"), App.format_time(game.ticks), "PPS %.2f" % (game.pieces_placed / maxf(seconds, 1.0 / 60.0))]
			if _assist != null:
				lines.append(Loc.t("assist_no_record"))
			else:
				lines.append(Loc.t("new_record") if _new_record else "%s %s" % [Loc.t("best"), App.format_time(App.best_40l_ticks)])
		else:
			lines = [Loc.t("game_over"), "%s %d / 40" % [Loc.t("lines"), game.lines]]
	else:
		lines = [Loc.t("game_over"),
			"%s %d" % [Loc.t("score"), game.score],
			"%s %d  %s %d" % [Loc.t("level"), game.level, Loc.t("lines"), game.lines]]
		lines.append(Loc.t("new_record") if _new_record else "%s %d" % [Loc.t("high_score"), App.marathon_best_score])
	lines.append_array(["",
		"%s: %s / %s" % [Loc.t("retry"), pad_hint("accept"), pad_hint("retry")],
		"%s: %s" % [Loc.t("to_title"), pad_hint("back")]])
	draw_banner(_overlay, center, lines)


## コントローラーのボタン名だけ（バナー内は短く）
static func pad_hint(action: String) -> String:
	var buttons := InputSetup.bindings_of("pad", action)
	return InputSetup.button_label(buttons[0]) if buttons.size() > 0 else "---"


## 1行目を大きく、残りを並べたパネル
static func draw_banner(ci: CanvasItem, center: Vector2, lines: Array) -> void:
	var skin: UiSkin = App.skin
	var w := 360.0
	var line_h := 36.0
	var first_h := 58.0
	var h := first_h + (lines.size() - 1) * line_h + 24
	var rect := Rect2(center.x - w / 2, center.y - h / 2, w, h)
	skin.draw_panel(ci, rect)
	skin.draw_text(ci, Vector2(rect.position.x, rect.position.y + 50), lines[0], 40, "highlight", HORIZONTAL_ALIGNMENT_CENTER, w, true)
	for i in range(1, lines.size()):
		var role := "highlight" if lines[i] == Loc.t("new_record") else "text"
		skin.draw_text(ci, Vector2(rect.position.x, rect.position.y + first_h + 12 + i * line_h), lines[i], 22, role, HORIZONTAL_ALIGNMENT_CENTER, w, true)
