extends Node2D
## CPU 対戦画面。左が自分、右が CPU。App.versus_level / App.versus_first_to で設定する。
## App.demo が true ならデモ: 左右とも CPU（強さは App.demo_levels）で、ラウンドを終わりなく繰り返す（ボタンでタイトルへ）。

const CELL := 24.0
const PLAYER_POS := Vector2(88, 150)
const CPU_POS := Vector2(710, 150)
const READY_TICKS := 60
const GO_TICKS := 30
const ROUND_END_TICKS := 90     # ラウンド決着から次へ進めるようになるまで
const MARGIN_TICKS := 60 * 60   # この間隔で落下速度が1段上がる
const MAX_LEVEL := 15
const ORB_TIME := 0.45
const PAUSE_ITEMS := ["resume", "retry", "to_title"]
const END_ITEMS := ["retry", "to_title"]
const DEMO_NEXT_TICKS := 150    # デモ: ラウンド決着から次のラウンドまで

enum State { READY, PLAYING, ROUND_END, MATCH_END }

var player: GameState
var cpu: GameState
var input: InputHandler
var cpu_player: CpuPlayer
var state := State.READY
var paused := false
var wins := [0, 0]              # [自分, CPU]
var round_no := 1

var _timer := 0
var _go_timer := 0
var _round_ticks := 0
var _round_winner := -1         # 0: 自分, 1: CPU, 2: 引き分け
var _menu_index := 0
var _time := 0.0
var _orbs := []                 # 攻撃の玉 {from, to, t, lines}
var _overlay_fx := Effects.new()
var _player_view := FieldView.new()
var _cpu_view := FieldView.new()
var _overlay := Node2D.new()
var _record_saved := false
var _totals := [[0, 0, 0], [0, 0, 0]]  # 試合全体の [置いた数, 送ったライン, tick]（自分, CPU）
var demo := false
var _left_cpu: CpuPlayer        # デモで左側を操作する CPU


func _ready() -> void:
	demo = App.demo
	for v in [_player_view, _cpu_view]:
		v.cell = CELL
		v.hold_rect = Rect2(0, 0, 100, 92)
		v.board_pos = Vector2(126, 0)
		v.next_rect = Rect2(378, 0, 104, 330)
		v.counter_pos = Vector2(378, 372)
		v.message_rect = Rect2(-10, 150, 120, 0)
		v.show_meter = true
		add_child(v)
	_player_view.set_base_position(PLAYER_POS)
	_cpu_view.set_base_position(CPU_POS)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_new_match()


func _new_match() -> void:
	wins = [0, 0]
	round_no = 1
	_record_saved = false
	_totals = [[0, 0, 0], [0, 0, 0]]
	_new_round()


func _new_round() -> void:
	# 同じ順番のミノで戦う
	var seed_value := randi() % 1000000 + 1
	player = GameState.new(seed_value)
	cpu = GameState.new(seed_value)
	for g in [player, cpu]:
		g.fixed_level = 1
	player.event.connect(_on_event.bind(0))
	cpu.event.connect(_on_event.bind(1))
	_player_view.setup(player, not demo)
	_cpu_view.setup(cpu, false)
	input = InputHandler.new(player)
	App.configure(player, input)
	cpu.line_clear_frames = player.line_clear_frames
	if cpu_player != null:
		cpu_player.shutdown()
	cpu_player = CpuPlayer.new(cpu, App.demo_levels[1] if demo else App.versus_level)
	if _left_cpu != null:
		_left_cpu.shutdown()
		_left_cpu = null
	if demo:
		player.line_clear_frames = cpu.line_clear_frames
		_left_cpu = CpuPlayer.new(player, App.demo_levels[0])
	input.prime(InputSetup.poll()[0])
	InputSetup.clear_pressed()
	_orbs.clear()
	_overlay_fx.clear()
	paused = false
	state = State.READY
	_timer = READY_TICKS
	_go_timer = 0
	_round_ticks = 0
	_round_winner = -1
	Bgm.stop()  # GO! の後から流し直す
	Sfx.play("ready", 1.0, 0.5 if demo else 1.0)


func _physics_process(delta: float) -> void:
	var polled: Array = InputSetup.poll()
	var held: Dictionary = polled[0]
	var pressed: Dictionary = polled[1]

	if demo:
		_demo_process(pressed)
		return
	if state == State.MATCH_END:
		_update_menu(delta, pressed, END_ITEMS)
		return
	if paused:
		if pressed.get("pause", false) or pressed.get("back", false):
			paused = false
			Sfx.play("menu_back")
		else:
			_update_menu(delta, pressed, PAUSE_ITEMS)
		return
	if pressed.get("retry", false):
		_new_match()
		return
	if pressed.get("pause", false) and state != State.ROUND_END:
		paused = true
		_menu_index = 0
		InputSetup.menu_direction(0.0)
		Sfx.play("menu_select")
		return

	match state:
		State.READY:
			input.update(held, pressed)  # READY 中も DAS を溜められる
			_timer -= 1
			if _timer <= 0:
				player.start()
				cpu.start()
				state = State.PLAYING
				_go_timer = GO_TICKS
				Sfx.play("go")
				Bgm.play()
		State.PLAYING:
			input.update(held, pressed)
			cpu_player.tick()
			player.tick()
			cpu.tick()
			_go_timer = maxi(_go_timer - 1, 0)
			_round_ticks += 1
			# マージンタイム: 時間とともに落下を速くする
			var lv := mini(1 + _round_ticks / MARGIN_TICKS, MAX_LEVEL)
			player.fixed_level = lv
			cpu.fixed_level = lv
			_check_round_end()
		State.ROUND_END:
			_timer -= 1
			if _timer <= 0 and (pressed.get("accept", false) or _timer < -120):
				_next_round()


## デモ: 左右とも CPU。ラウンドを終わりなく繰り返し、どれかのボタンでタイトルへ
func _demo_process(pressed: Dictionary) -> void:
	for k in pressed:
		if pressed[k]:
			App.demo = false
			get_tree().change_scene_to_file("res://scenes/title.tscn")
			return
	match state:
		State.READY:
			_timer -= 1
			if _timer <= 0:
				player.start()
				cpu.start()
				state = State.PLAYING
				_go_timer = GO_TICKS
				Sfx.play("go", 1.0, 0.5)
				Bgm.play()
		State.PLAYING:
			_left_cpu.tick()
			cpu_player.tick()
			player.tick()
			cpu.tick()
			_go_timer = maxi(_go_timer - 1, 0)
			_round_ticks += 1
			var lv := mini(1 + _round_ticks / MARGIN_TICKS, MAX_LEVEL)
			player.fixed_level = lv
			cpu.fixed_level = lv
			_check_round_end()
		State.ROUND_END:
			_timer -= 1
			if _timer <= ROUND_END_TICKS - DEMO_NEXT_TICKS:
				round_no += 1
				_new_round()


func _exit_tree() -> void:
	if cpu_player != null:
		cpu_player.shutdown()
	if _left_cpu != null:
		_left_cpu.shutdown()


func _check_round_end() -> void:
	var p_out := player.phase == GameState.Phase.GAME_OVER
	var c_out := cpu.phase == GameState.Phase.GAME_OVER
	if not p_out and not c_out:
		return
	state = State.ROUND_END
	_timer = ROUND_END_TICKS
	for i in 2:
		var g: GameState = [player, cpu][i]
		_totals[i][0] += g.pieces_placed
		_totals[i][1] += g.lines_sent
		_totals[i][2] += _round_ticks
	if p_out and c_out:
		_round_winner = 2
	else:
		_round_winner = 1 if p_out else 0
		wins[_round_winner] += 1
	if demo:
		Sfx.play("win", 1.0, 0.5)
	else:
		Sfx.play("win" if _round_winner == 0 else "lose")


func _next_round() -> void:
	if wins[0] >= App.versus_first_to or wins[1] >= App.versus_first_to:
		state = State.MATCH_END
		_menu_index = 0
		InputSetup.menu_direction(0.0)
		if not _record_saved:
			_record_saved = true
			App.submit_versus(App.versus_level, wins[0] > wins[1])
		return
	round_no += 1
	_new_round()


func _update_menu(delta: float, pressed: Dictionary, items: Array) -> void:
	match InputSetup.menu_direction(delta):
		"down":
			_menu_index = (_menu_index + 1) % items.size()
			Sfx.play("menu_move")
		"up":
			_menu_index = (_menu_index - 1 + items.size()) % items.size()
			Sfx.play("menu_move")
	if not pressed.get("accept", false):
		return
	Sfx.play("menu_select")
	match items[_menu_index]:
		"resume":
			paused = false
		"retry":
			_new_match()
		"to_title":
			get_tree().change_scene_to_file("res://scenes/title.tscn")


## 攻撃を相手に届ける（玉は見た目だけで、予告にはすぐ積む）
func _on_event(kind: String, data: Dictionary, side: int) -> void:
	if kind != "attack":
		return
	var from_view := _player_view if side == 0 else _cpu_view
	var to_view := _cpu_view if side == 0 else _player_view
	var target := cpu if side == 0 else player
	if data.cancelled > 0:
		_overlay_fx.burst(from_view.meter_global_point(), App.skin.colors.highlight, 10, 260.0)
	if data.lines > 0:
		target.receive(data.lines)
		_orbs.append({"from": from_view.board_global_center(), "to": to_view.meter_global_point(), "t": 0.0, "lines": data.lines})
		Sfx.play("attack", 1.0, 1.0 if side == 0 and not demo else 0.5)


func _process(delta: float) -> void:
	_time += delta
	Bgm.set_paused(paused)
	for orb in _orbs:
		orb.t += delta / ORB_TIME
		if orb.t >= 1.0:
			_overlay_fx.burst(orb.to, App.skin.colors.highlight, 12, 300.0)
	_orbs = _orbs.filter(func(o): return o.t < 1.0)
	_overlay_fx.update(delta, App.skin.fx.particle_gravity)
	queue_redraw()
	_overlay.queue_redraw()


# ---------------- 描画 ----------------

func _draw() -> void:
	var skin: UiSkin = App.skin
	skin.draw_background(self, Vector2(1280, 720), _time)
	# 名前と勝ち数
	_draw_name(PLAYER_POS, _cpu_name(0) if demo else Loc.t("you"), wins[0])
	_draw_name(CPU_POS, _cpu_name(1), wins[1])
	skin.draw_text(self, Vector2(0, 90), "VS", 44, "title", HORIZONTAL_ALIGNMENT_CENTER, 1280, true, 12)
	var sub := "DEMO" if demo else Loc.t("first_to_value") % App.versus_first_to
	skin.draw_text(self, Vector2(0, 124), sub, 16, "text", HORIZONTAL_ALIGNMENT_CENTER, 1280, true)
	# 攻撃の状況
	_draw_stats(PLAYER_POS, player)
	_draw_stats(CPU_POS, cpu)
	var hint := Loc.t("hint_demo") if demo else Loc.t("hint_game") % [InputSetup.action_hint("retry"), InputSetup.action_hint("pause")]
	skin.draw_text(self, Vector2(24, 704), hint, 15, "text")


## side: 0 が左、1 が右（デモ以外では右の CPU だけ）
func _cpu_name(side := 1) -> String:
	var level: int = App.demo_levels[side] if demo else App.versus_level
	return "CPU  TAS" if level == CpuPlayer.TAS_LEVEL else "CPU  Lv.%d" % level


func _draw_name(pos: Vector2, label: String, win_count: int) -> void:
	var skin: UiSkin = App.skin
	skin.draw_text(self, pos + Vector2(126, -48), label, 26, "title", HORIZONTAL_ALIGNMENT_LEFT, -1, true, 8)
	if demo:
		# デモは終わりがないので、通算の勝ち数を数字で出す
		skin.draw_text(self, pos + Vector2(126, -48), "%d WIN" % win_count, 26, "title", HORIZONTAL_ALIGNMENT_RIGHT, 240, true, 8)
		return
	# 勝ち数の丸
	for i in App.versus_first_to:
		var c := pos + Vector2(126 + 240 - 14 - i * 30, -56)
		self.draw_circle(c, 11.0, skin.colors.outline)
		self.draw_circle(c, 8.0, skin.colors.highlight if i < win_count else skin.colors.panel)


func _draw_stats(pos: Vector2, g: GameState) -> void:
	var minutes := maxf(_round_ticks / 3600.0, 1.0 / 60.0)
	var pps := g.pieces_placed / maxf(_round_ticks / 60.0, 1.0 / 60.0)
	var text := "APM %.1f   PPS %.2f   %s %d" % [g.lines_sent / minutes, pps, Loc.t("sent"), g.lines_sent]
	App.skin.draw_text(self, pos + Vector2(126, 480 + 34), text, 16, "text", HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _draw_overlay() -> void:
	var skin: UiSkin = App.skin
	for orb in _orbs:
		# 少し山なりに飛ばす
		var p: Vector2 = orb.from.lerp(orb.to, orb.t) + Vector2(0, -120 * sin(orb.t * PI))
		skin.draw_attack_orb(_overlay, p, orb.lines, orb.t)
	_overlay_fx.draw_particles(_overlay, skin)

	var p_center := _player_view.board_global_center()
	var c_center := _cpu_view.board_global_center()
	match state:
		State.READY:
			for c in [p_center, c_center]:
				_small_banner(c, Loc.t("ready"))
		State.PLAYING:
			if _go_timer > 0 and player.pieces_placed == 0:
				for c in [p_center, c_center]:
					_small_banner(c, Loc.t("go"))
		State.ROUND_END:
			if _round_winner == 2:
				_small_banner(p_center, Loc.t("draw"))
				_small_banner(c_center, Loc.t("draw"))
			else:
				_small_banner(p_center, Loc.t("win") if _round_winner == 0 else Loc.t("lose"))
				_small_banner(c_center, Loc.t("win") if _round_winner == 1 else Loc.t("lose"))
		State.MATCH_END:
			_draw_match_result()
	if paused:
		var labels := PAUSE_ITEMS.map(func(k): return Loc.t(k))
		skin.draw_menu_panel(_overlay, Vector2(640, 380), Loc.t("pause"), labels, _menu_index, _time)


func _small_banner(center: Vector2, text: String) -> void:
	var skin: UiSkin = App.skin
	var w := 220.0
	var rect := Rect2(center.x - w / 2, center.y - 34, w, 68)
	skin.draw_panel(_overlay, rect)
	skin.draw_text(_overlay, Vector2(rect.position.x, rect.position.y + 48), text, 36, "highlight", HORIZONTAL_ALIGNMENT_CENTER, w, true)


func _draw_match_result() -> void:
	var skin: UiSkin = App.skin
	var won: bool = wins[0] > wins[1]
	var rect := Rect2(390, 130, 500, 470)
	skin.draw_panel(_overlay, rect)
	skin.draw_text(_overlay, Vector2(rect.position.x, rect.position.y + 64), Loc.t("match_win") if won else Loc.t("match_lose"),
		48, "highlight", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
	skin.draw_text(_overlay, Vector2(rect.position.x, rect.position.y + 112), "%d - %d" % [wins[0], wins[1]],
		32, "text", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
	var record: Array = App.versus_record(App.versus_level)
	skin.draw_text(_overlay, Vector2(rect.position.x, rect.position.y + 150), "%s  %s" % [_cpu_name(), Loc.t("record") % [record[0], record[1]]],
		18, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
	# 試合全体の APM / PPS / 送ったライン（自分 と CPU）
	var cols := [rect.position.x + 150, rect.position.x + 300, rect.position.x + 430]
	skin.draw_text(_overlay, Vector2(cols[1] - 70, rect.position.y + 196), Loc.t("you"), 18, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, 140, true)
	skin.draw_text(_overlay, Vector2(cols[2] - 70, rect.position.y + 196), "CPU", 18, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, 140, true)
	var labels := ["APM", "PPS", Loc.t("sent")]
	for row in 3:
		var y := rect.position.y + 228 + row * 30
		skin.draw_text(_overlay, Vector2(cols[0] - 110, y), labels[row], 18, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		for side in 2:
			var t: Array = _totals[side]
			var minutes := maxf(t[2] / 3600.0, 1.0 / 60.0)
			var value: String = ["%.1f" % (t[1] / minutes), "%.2f" % (t[0] / (minutes * 60.0)), str(t[1])][row]
			skin.draw_text(_overlay, Vector2(cols[side + 1] - 70, y), value, 20, "text", HORIZONTAL_ALIGNMENT_CENTER, 140, true)
	for i in END_ITEMS.size():
		var selected := i == _menu_index
		var item := Rect2(rect.get_center().x - 130, rect.position.y + 330 + i * 66, 260, 52)
		if not selected:
			skin.draw_panel(_overlay, item)
		skin.draw_item(_overlay, item, selected, _time)
		skin.draw_text(_overlay, Vector2(item.position.x, item.position.y + 36), Loc.t(END_ITEMS[i]), 26,
			"text_on_accent" if selected else "text", HORIZONTAL_ALIGNMENT_CENTER, item.size.x, true)
