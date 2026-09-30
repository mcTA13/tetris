extends SceneTree
## CPU 同士を画面なしで対戦させて、強さと思考時間を測る。
## 実行: godot --headless --path . -s tests/cpu_sim.gd -- <強さA> <強さB> <試合数>
## 強さB を 0 にすると、A が 1 人で積む（攻撃を受けない）

const MAX_TICKS := 60 * 60 * 5  # 5分で打ち切り
const MARGIN_TICKS := 60 * 60

var show_board := false
var _last_shown := -1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_a := int(args[0]) if args.size() > 0 else 5
	var level_b := int(args[1]) if args.size() > 1 else 1
	var games := int(args[2]) if args.size() > 2 else 3
	show_board = args.size() > 3 and args[3] == "show"
	var wins := [0, 0, 0]
	for i in games:
		var r := _play(level_a, level_b, 1000 + i)
		wins[r.winner] += 1
		print("game %d: winner=%s ticks=%d  A: pieces %d sent %d  B: pieces %d sent %d  think avg %.1fms max %.1fms" % [
			i + 1, ["A", "B", "draw"][r.winner], r.ticks, r.a.pieces_placed, r.a.lines_sent,
			r.b.pieces_placed, r.b.lines_sent, r.think_avg, r.think_max])
		print("   A: ", r.stats[0])
		print("   B: ", r.stats[1])
	print("Lv.%d vs Lv.%d: %d - %d (draw %d)" % [level_a, level_b, wins[0], wins[1], wins[2]])
	quit()


func _play(level_a: int, level_b: int, seed_value: int) -> Dictionary:
	var a := GameState.new(seed_value)
	var b := GameState.new(seed_value + (0 if level_b > 0 else 777))
	var stats := [{}, {}]
	a.event.connect(func(kind, data): _on_event(kind, data, b, stats[0], a))
	b.event.connect(func(kind, data): _on_event(kind, data, a, stats[1], b))
	var solo := level_b == 0
	var pa := CpuPlayer.new(a, level_a)
	var pb := CpuPlayer.new(b, maxi(level_b, 1))
	pa.use_thread = false
	pb.use_thread = false
	a.start()
	b.start()
	var ticks := 0
	var think_total := 0.0
	var think_max := 0.0
	var thinks := 0
	while ticks < MAX_TICKS:
		ticks += 1
		var lv := mini(1 + ticks / MARGIN_TICKS, 15)
		a.fixed_level = lv
		b.fixed_level = lv
		for p in ([pa] if solo else [pa, pb]):
			var t0 := Time.get_ticks_usec()
			p.tick()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if ms > 0.5:  # 考えた tick だけ数える
				think_total += ms
				think_max = maxf(think_max, ms)
				thinks += 1
		if show_board and a.pieces_placed % 10 == 0 and a.pieces_placed > 0 and a.pieces_placed <= 120 and a.phase == GameState.Phase.PLAYING and a.pieces_placed != _last_shown:
			_last_shown = a.pieces_placed
			_print_board(a)
		# Cold Clear 2 は実時間で考えるので、使うときは実際の速さで進める
		if pa.uses_cold_clear() or pb.uses_cold_clear():
			OS.delay_msec(16)
		a.tick()
		if not solo:
			b.tick()
		var a_out := a.phase == GameState.Phase.GAME_OVER
		var b_out := not solo and b.phase == GameState.Phase.GAME_OVER
		if a_out or b_out:
			var winner := 2 if a_out and b_out else (1 if a_out else 0)
			pa.shutdown()
			pb.shutdown()
			stats[0]["misplaced"] = pa.misplaced
			stats[1]["misplaced"] = pb.misplaced
			return {"winner": winner, "ticks": ticks, "a": a, "b": b, "think_avg": think_total / maxi(thinks, 1), "think_max": think_max, "stats": stats}
	pa.shutdown()
	pb.shutdown()
	stats[0]["misplaced"] = pa.misplaced
	stats[1]["misplaced"] = pb.misplaced
	return {"winner": 2, "ticks": ticks, "a": a, "b": b, "think_avg": think_total / maxi(thinks, 1), "think_max": think_max, "stats": stats}


## 攻撃を相手に届け、消し方を数える
func _on_event(kind: String, data: Dictionary, target: GameState, st: Dictionary, own: GameState) -> void:
	if kind == "attack":
		if target.phase != GameState.Phase.ARE or target.pieces_placed > 0:
			target.receive(data.lines)
	elif kind == "lock":
		# 置くたびに盤面の穴（上がふさがった空き）を数える
		var holes := 0
		for x in Board.WIDTH:
			var covered := false
			for y in Board.HEIGHT:
				var filled: bool = own.board.grid[y][x] != PieceData.NONE
				if filled:
					covered = true
				elif covered:
					holes += 1
		st["holes_sum"] = st.get("holes_sum", 0) + holes
		st["holes_max"] = maxi(st.get("holes_max", 0), holes)
		st["locks"] = st.get("locks", 0) + 1
	elif kind == "clear":
		var key := "clear%d" % data.lines
		if data.spin == GameState.Spin.FULL and data.piece == PieceData.T:
			key = "tspin%d" % data.lines
		elif data.spin != GameState.Spin.NONE:
			key = "mini%d" % data.lines
		st[key] = st.get(key, 0) + 1
		st["max_combo"] = maxi(st.get("max_combo", 0), data.combo)
		if data.perfect:
			st["pc"] = st.get("pc", 0) + 1


func _print_board(g: GameState) -> void:
	var lines := ["--- piece %d ---" % g.pieces_placed]
	for y in range(Board.HIDDEN_ROWS, Board.HEIGHT):
		var line := ""
		for x in Board.WIDTH:
			line += "#" if g.board.grid[y][x] != PieceData.NONE else "."
		lines.append(line)
	print("
".join(lines))
