extends SceneTree
## コアロジックのテスト。実行: godot --headless --path . -s tests/run_tests.gd

var _failures := 0
var _count := 0


func _init() -> void:
	test_bag_is_7_bag()
	test_bag_remaining_after()
	test_update_version_compare()
	test_kick_tables_are_mirrored()
	test_spawn_position()
	test_tspin_double()
	test_tspin_mini_single()
	test_tspin_triple_kick_is_full()
	test_tspin_zero_lines_scores()
	test_all_spin_immobile()
	test_b2b_and_combo()
	test_perfect_clear_tetris()
	test_hold_once_per_piece()
	test_das_arr()
	test_das_arr_zero()
	test_lock_delay_and_resets()
	test_line_goal_finishes()
	test_garbage_rises_on_lock()
	test_garbage_max_per_lock()
	test_attack_cancels_incoming()
	test_attack_partially_cancelled()
	test_garbage_top_out()
	test_ai_spin_detection_matches_game()
	test_ai_finds_tspin_double()
	test_ai_performs_tspin_double()
	test_cold_clear_coordinates()
	test_b2b_tspin_then_tetris_with_input()
	test_b2b_tsd_locked_by_delay()
	test_b2b_tsd_while_soft_dropping()
	test_drills_are_solvable()
	test_pc_drill_is_solvable()
	test_openers_can_be_built()
	test_hold_can_be_disabled()
	test_finish_ends_game()
	test_cold_clear_suggests_tspin_double()
	print("\n%d checks, %d failed" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_count += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


## 盤面の下側を文字列で作る（'X' が埋まり、'.' が空き）。rows[-1] が一番下の行
func make_game(rows: Array, piece := PieceData.T, rot := 0, pos := Vector2i.ZERO) -> GameState:
	var g := GameState.new(1)
	g.start()
	var top := Board.HEIGHT - rows.size()
	for i in rows.size():
		var line: String = rows[i]
		for x in Board.WIDTH:
			g.board.grid[top + i][x] = PieceData.GARBAGE if line[x] == "X" else PieceData.NONE
	g.piece = piece
	g.rot = rot
	g.pos = pos
	return g


func capture(g: GameState) -> Array:
	var events := []
	g.event.connect(func(kind, data): events.append({"kind": kind, "data": data}))
	return events


func find_event(events: Array, kind: String) -> Dictionary:
	for e in events:
		if e.kind == kind:
			return e.data
	return {}


# ---------------------------------------------------------------

func test_bag_is_7_bag() -> void:
	var bag := Bag.new(12345)
	for _i in 100:
		var seen := {}
		for _j in 7:
			seen[bag.pop()] = true
		check(seen.size() == 7, "7個ごとに全種類そろう")
	var a := Bag.new(42)
	var b := Bag.new(42)
	check(a.peek(14) == b.peek(14), "同じシードなら同じ順番")


func test_update_version_compare() -> void:
	var U := preload("res://scripts/updater.gd")
	check(U.is_newer("v1.4", "1.3"), "v1.4 は 1.3 より新しい")
	check(U.is_newer("v1.10", "1.9"), "v1.10 は 1.9 より新しい（数字で比べる）")
	check(U.is_newer("v1.3.1", "1.3"), "v1.3.1 は 1.3 より新しい")
	check(not U.is_newer("v1.3", "1.3"), "同じ版は新しくない")
	check(not U.is_newer("v1.2", "1.3"), "古い版は新しくない")
	var lines: Array = U.note_lines("## 追加\r\n\r\n- **BGM**: `曲`を追加\r\n普通の行")
	check(lines == [["追加", true], ["・BGM: 曲を追加", false], ["普通の行", false]], "リリースノートの Markdown を画面用の行に直す")

func test_bag_remaining_after() -> void:
	var seq := Bag.new(7).peek(70)
	for taken in 20:
		var bag := Bag.new(7)
		for _i in taken:
			bag.pop()
		var start := taken + 5
		var expected := seq.slice(start, (start + 6) / 7 * 7)
		if expected.is_empty():
			expected.assign(PieceData.ALL)
		var got := bag.remaining_after(5)
		got.sort()
		expected.sort()
		check(got == expected, "NEXT 5 個のあとの 1 巡の残り（%d 個取り出した後）" % taken)


func test_kick_tables_are_mirrored() -> void:
	# SRS の性質: A>B の蹴りは B>A の符号反転
	for table in [PieceData.KICKS_JLSTZ, PieceData.KICKS_I]:
		for key in table:
			var parts: PackedStringArray = key.split(">")
			var back: Array = table["%s>%s" % [parts[1], parts[0]]]
			for i in 5:
				check(table[key][i] == -back[i], "蹴り表の対称性 %s #%d" % [key, i])


func test_spawn_position() -> void:
	var g := GameState.new(1)
	g.start()
	var xs := []
	for c in PieceData.cells(g.piece, g.rot):
		xs.append(g.pos.x + c.x)
	check(xs.min() >= 3 and xs.max() <= 6, "出現位置が中央")
	check(g.pos.y == GameState.SPAWN_POS.y + 1, "出現後すぐ1段下がる")


func test_tspin_double() -> void:
	var g := make_game([
		"XXX.......",
		"XX...XXXXX",
		"XXX.XXXXXX",
	], PieceData.T, 1, Vector2i(2, 37))
	var ev := capture(g)
	check(g.rotate(1), "TSD: 回転できる")
	check(g.rot == 2 and g.pos == Vector2i(2, 37), "TSD: 蹴りなしで入る")
	check(find_event(ev, "rotate").get("spin") == GameState.Spin.FULL, "TSD: 回した瞬間にTスピンと分かる")
	g.hard_drop()
	var clear := find_event(ev, "clear")
	check(clear.get("spin") == GameState.Spin.FULL, "TSD: Tスピン判定")
	check(clear.get("lines") == 2, "TSD: 2ライン")
	check(clear.get("points") == 1200, "TSD: 1200点")
	check(clear.get("attack") == 4, "TSD: 攻撃4")


func test_tspin_mini_single() -> void:
	var g := make_game([
		"..........",
		".XXXXXXXXX",
		".XXXXXXXXX",
	], PieceData.T, 0, Vector2i(0, 36))
	var ev := capture(g)
	check(g.rotate(1), "Mini: 回転できる")
	check(g.pos == Vector2i(-1, 36), "Mini: 壁蹴り2番目で入る")
	check(find_event(ev, "rotate").get("spin") == GameState.Spin.MINI, "Mini: 回した瞬間にMiniと分かる")
	g.hard_drop()
	var clear := find_event(ev, "clear")
	check(clear.get("spin") == GameState.Spin.MINI, "Mini: Mini判定")
	check(clear.get("lines") == 1, "Mini: 1ライン")
	check(clear.get("points") == 200, "Mini: 200点")


func test_tspin_triple_kick_is_full() -> void:
	# 5番目の蹴り（TST蹴り）で入ると、正面の隅が1つ空いていても Mini ではなく通常 Tスピン
	var g := make_game([
		"......X...",
		"..........",
		"XXXXXX.XXX",
		"XXXXX..XXX",
		"XXXXX..XXX",
	], PieceData.T, 0, Vector2i(4, 35))
	var ev := capture(g)
	check(g.rotate(-1), "TST蹴り: 左回転できる")
	check(g._last_kick_index == 4 and g.pos == Vector2i(5, 37), "TST蹴り: 5番目の蹴りで入る")
	g.hard_drop()
	var clear := find_event(ev, "clear")
	check(clear.get("spin") == GameState.Spin.FULL, "TST蹴り: 通常 Tスピン扱い")
	check(clear.get("lines") == 2, "TST蹴り: 2ライン")


func test_tspin_zero_lines_scores() -> void:
	var g := make_game([
		"XXX.......",
		"XX...XXXX.",
		"XXX.XXXXX.",
	], PieceData.T, 1, Vector2i(2, 37))
	var ev := capture(g)
	g.rotate(1)
	g.hard_drop()
	var clear := find_event(ev, "clear")
	check(clear.get("spin") == GameState.Spin.FULL and clear.get("lines") == 0, "Tスピン0ラインも判定される")
	check(clear.get("points") == 400, "Tスピン0ラインは400点")


func test_all_spin_immobile() -> void:
	var g := make_game([
		"XXXX..XXXX",
		"XXX..XXXXX",
		"XXXXXXXXXX",
	], PieceData.S, 0, Vector2i(3, 37))
	check(g.board.fits(PieceData.S, 0, g.pos), "Sスピン: はまる位置")
	g._last_was_rotation = true
	var info := g._detect_spin()
	check(info.spin == GameState.Spin.NONE, "T 以外は動けない位置で回してもスピンにならない")
	g._last_was_rotation = false
	check(g._detect_spin().spin == GameState.Spin.NONE, "最後の操作が回転でなければスピンではない")
	var g4 := make_game([], PieceData.T, 0, Vector2i(3, 30))
	var ev4 := capture(g4)
	g4.rotate(1)
	check(find_event(ev4, "rotate").get("spin") == GameState.Spin.NONE, "何もない場所で回してもスピンではない")
	var g2 := make_game([], PieceData.S, 0, Vector2i(3, 37))
	g2._last_was_rotation = true
	check(g2._detect_spin().spin == GameState.Spin.NONE, "動ける場所ではスピンではない")


func test_b2b_and_combo() -> void:
	var g := make_game([
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"X.XXXXXXXX",
	])
	var ev := capture(g)
	_drop_i_right(g)
	var c1 := find_event(ev, "clear")
	check(c1.get("points") == 800 and c1.get("b2b") == 0, "テトリス1回目は800点・B2Bなし")
	for _i in g.line_clear_frames + g.are_frames + 1:
		g.tick()
	check(g.phase == GameState.Phase.PLAYING, "消去待ちのあと次のミノが出る")
	ev.clear()
	_drop_i_right(g)
	var c2 := find_event(ev, "clear")
	check(c2.get("b2b") == 1, "テトリス2回目はB2B")
	check(c2.get("combo") == 1, "REN1")
	# B2B: 800*1.5=1200, REN1: +50
	check(c2.get("points") == 1250, "B2Bテトリス+REN1 = 1250点 (%s)" % c2.get("points"))


func _drop_i_right(g: GameState) -> void:
	g.piece = PieceData.I
	g.rot = 1
	g.pos = Vector2i(7, 20)
	g.hard_drop()


func test_perfect_clear_tetris() -> void:
	var g := make_game([
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
	])
	var ev := capture(g)
	_drop_i_right(g)
	var clear := find_event(ev, "clear")
	check(clear.get("perfect") == true, "全消し判定")
	check(clear.get("points") == 800 + 2000, "テトリス全消し 2800点")
	check(clear.get("attack") == 10, "全消し攻撃10")


func test_hold_once_per_piece() -> void:
	var g := GameState.new(7)
	g.start()
	var first := g.piece
	check(g.hold(), "ホールドできる")
	check(g.hold_piece == first, "ホールドに入る")
	check(not g.hold(), "続けてホールドはできない")
	g.hard_drop()
	check(g.hold(), "置いた後はまたホールドできる")


func _held(dir: String) -> Dictionary:
	return {dir: true}


func test_das_arr() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 30))
	var h := InputHandler.new(g)
	h.das = 10
	h.arr = 2
	var xs := []
	for _i in 16:
		h.update(_held("right"), {})
		xs.append(g.pos.x)
	check(xs[0] == 4, "押した瞬間に1マス")
	check(xs[9] == 4, "DAS中は動かない")
	check(xs[10] == 5, "DAS(10F)で動き出す (%s)" % str(xs))
	check(xs[12] == 6 and xs[14] == 7, "ARR(2F)ごとに動く")
	check(xs[15] == 7, "壁で止まる")
	# 左に切り替えたら即座に1マス
	h.update({"right": true, "left": true}, {})
	check(g.pos.x == 6, "後から押した方向を優先")


func test_das_arr_zero() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 30))
	var h := InputHandler.new(g)
	h.das = 7
	h.arr = 0
	for _i in 8:
		h.update(_held("left"), {})
	check(g.pos.x == 0, "ARR0なら壁まで一瞬")


func test_lock_delay_and_resets() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 38))
	check(g.is_grounded(), "床に接地")
	for _i in GameState.LOCK_DELAY - 1:
		g.tick()
	check(g.pieces_placed == 0, "0.5秒未満では固定されない")
	g.move(1)
	for _i in GameState.LOCK_DELAY - 1:
		g.tick()
	check(g.pieces_placed == 0, "移動で固定までの時間が延びる")
	# 15回動かしても延長は15回まで
	for i in 20:
		g.move(1 if i % 2 == 0 else -1)
		g.tick()
	for _i in GameState.LOCK_DELAY:
		g.tick()
	check(g.pieces_placed == 1, "延長は15回まで")


func test_line_goal_finishes() -> void:
	var g := make_game([
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
	])
	g.line_goal = 4
	var ev := capture(g)
	_drop_i_right(g)
	check(g.phase == GameState.Phase.CLEARED, "目標ラインでクリア")
	check(not find_event(ev, "finished").is_empty(), "finished イベント")


# ---------------- 対戦（おじゃま） ----------------

func _garbage_rows(g: GameState) -> int:
	var n := 0
	for row in g.board.grid:
		if row.count(PieceData.GARBAGE) > 0:
			n += 1
	return n


func test_garbage_rises_on_lock() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 30))
	var ev := capture(g)
	g.receive(3)
	check(g.incoming_total() == 3, "おじゃま: 予告に積まれる")
	check(_garbage_rows(g) == 0, "おじゃま: 置くまではせり上がらない")
	g.hard_drop()
	check(_garbage_rows(g) == 3, "おじゃま: ラインを消さずに置くとせり上がる")
	check(g.incoming_total() == 0, "おじゃま: 予告が空になる")
	var holes := {}
	for y in range(Board.HEIGHT - 3, Board.HEIGHT):
		holes[g.board.grid[y].find(PieceData.NONE)] = true
	check(holes.size() == 1, "おじゃま: 1回の攻撃の穴は同じ列")
	check(not find_event(ev, "garbage_rise").is_empty(), "おじゃま: garbage_rise イベント")


func test_garbage_max_per_lock() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 20))
	g.receive(6)
	g.receive(4)
	g.hard_drop()
	check(_garbage_rows(g) == GameState.MAX_GARBAGE_PER_LOCK, "おじゃま: 1回のせり上がりは8行まで")
	check(g.incoming_total() == 2, "おじゃま: 残りは持ち越し")


func test_attack_cancels_incoming() -> void:
	var g := make_game([
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"X.XXXXXXXX",  # 全消しにならないよう1段残す
	])
	var ev := capture(g)
	g.receive(3)
	_drop_i_right(g)
	var atk := find_event(ev, "attack")
	check(g.incoming_total() == 0, "相殺: テトリス(4)で予告3を打ち消す")
	check(atk.get("lines") == 1 and atk.get("cancelled") == 3, "相殺: 余り1を送る")
	check(g.lines_sent == 1, "相殺: 送ったライン数")
	check(_garbage_rows(g) == 5, "相殺: ラインを消したときはせり上がらない（消去待ちの間は元の5段のまま）")


func test_attack_partially_cancelled() -> void:
	var g := make_game([
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"X.XXXXXXXX",  # 全消しにならないよう1段残す
	])
	var ev := capture(g)
	g.receive(5)
	_drop_i_right(g)
	check(g.incoming_total() == 1, "相殺: 予告5からテトリス分を引いて1残る")
	check(find_event(ev, "attack").get("lines") == 0, "相殺: 送る分はなし")


func test_garbage_top_out() -> void:
	var g := make_game([], PieceData.T, 0, Vector2i(3, 20))
	for y in range(0, Board.HEIGHT):
		g.board.grid[y][0] = PieceData.GARBAGE
	g.board.grid[0][0] = PieceData.GARBAGE
	g.receive(2)
	g.pos = Vector2i(3, 20)
	g.hard_drop()
	check(g.phase == GameState.Phase.GAME_OVER, "おじゃま: 上にあふれたら負け")


# ---------------- CPU ----------------

## ランダムな盤面で、CPU のスピン判定がゲーム本体と一致するか
func test_ai_spin_detection_matches_game() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mismatches := 0
	var checked := 0
	for _i in 2000:
		var g := make_game([])
		for y in range(Board.HEIGHT - 8, Board.HEIGHT):
			for x in Board.WIDTH:
				if rng.randf() < 0.55:
					g.board.grid[y][x] = PieceData.GARBAGE
		var type: int = PieceData.ALL[rng.randi_range(0, 6)]
		var rot := rng.randi_range(0, 3)
		var pos := Vector2i(rng.randi_range(-1, 8), rng.randi_range(Board.HEIGHT - 10, Board.HEIGHT - 2))
		if not g.board.fits(type, rot, pos):
			continue
		checked += 1
		g.piece = type
		g.rot = rot
		g.pos = pos
		g._last_was_rotation = true
		g._last_kick_index = 4 if rng.randf() < 0.2 else 0
		var expected: int = g._detect_spin().spin
		var rows := CpuBrain.rows_from(g.board)
		var actual := CpuBrain.detect_spin(rows, type, rot, pos.x, pos.y, true, g._last_kick_index)
		if expected != actual:
			mismatches += 1
	check(checked > 150, "CPU: 判定を十分な数だけ比べた (%d)" % checked)
	check(mismatches == 0, "CPU: スピン判定がゲーム本体と一致 (不一致 %d)" % mismatches)


func _tsd_game() -> GameState:
	var g := make_game([
		"XXX.......",
		"XX...XXXXX",
		"XXX.XXXXXX",
	], PieceData.T, 0, Vector2i(3, 19))
	g.hold_used = true
	return g


func test_ai_finds_tspin_double() -> void:
	var g := _tsd_game()
	var rows := CpuBrain.rows_from(g.board)
	var found := false
	for p in CpuBrain.find_placements(rows, PieceData.T, Vector3i(3, 19, 0)):
		if p.x == 2 and p.y == 37 and p.rot == 2 and p.spin == GameState.Spin.FULL:
			found = true
	check(found, "CPU: 探索で TSD の置き方が見つかる")


func test_ai_performs_tspin_double() -> void:
	var g := _tsd_game()
	var ev := capture(g)
	var cpu := CpuPlayer.new(g, 3)  # 自前の思考（Cold Clear 2 を使わない強さ）
	cpu.use_thread = false
	for _i in 600:
		cpu.tick()
		g.tick()
		if g.pieces_placed > 0:
			break
	var clear := find_event(ev, "clear")
	# Lv.3 はきれいに積む評価なので TSD か TSS かは盤面しだい。Tスピンで消せば OK
	check(clear.get("spin") == GameState.Spin.FULL and clear.get("lines", 0) >= 1, "CPU: 実際に Tスピンで消す (%s)" % str(clear))


func test_cold_clear_coordinates() -> void:
	# TBP の中心座標 → このゲームのバウンディングボックス左上
	var t := ColdClearBot.to_target({"location": {"type": "I", "orientation": "north", "x": 3, "y": 0}, "spin": "none"})
	check(t.type == PieceData.I and t.rot == 0 and t.x == 2 and t.y == 38, "CC: I 北向きの座標 (%s)" % str(t))
	t = ColdClearBot.to_target({"location": {"type": "T", "orientation": "south", "x": 3, "y": 1}, "spin": "full"})
	check(t.rot == 2 and t.x == 2 and t.y == 37 and t.spin == GameState.Spin.FULL, "CC: T 南向き（TSD の位置）の座標 (%s)" % str(t))
	# 東向きの I の中心は「上から2番目」。下から4段を埋めるなら中心は y=2
	t = ColdClearBot.to_target({"location": {"type": "I", "orientation": "east", "x": 9, "y": 2}, "spin": "none"})
	var cells := []
	for c in PieceData.cells(PieceData.I, t.rot):
		cells.append(Vector2i(t.x, t.y) + c)
	check(Vector2i(9, 39) in cells and Vector2i(9, 36) in cells, "CC: I 東向きは縦に x=9 の下から4段 (%s)" % str(cells))
	t = ColdClearBot.to_target({"location": {"type": "O", "orientation": "north", "x": 0, "y": 0}, "spin": "none"})
	check(t.x == 0 and t.y == 38 and t.rot == 0, "CC: O の座標 (%s)" % str(t))


## 実際に Cold Clear 2 を起動して、提案された置き場所にこのゲームの操作で行けるか
func test_cold_clear_suggests_tspin_double() -> void:
	if not ColdClearBot.available():
		print("  (Cold Clear 2 が見つからないのでスキップ)")
		return
	var g := _tsd_game()
	g.hold_used = false
	var bot := ColdClearBot.new()
	check(bot.launch(), "CC: 起動できる")
	var waited := 0
	while not bot.is_ready and waited < 3000:
		OS.delay_msec(10)
		waited += 10
		bot.poll()
	check(bot.is_ready, "CC: ready が返る")
	bot.start(g)
	OS.delay_msec(300)
	bot.suggest()
	var move := {}
	waited = 0
	while move.is_empty() and waited < 3000:
		OS.delay_msec(10)
		waited += 10
		move = bot.poll()
	bot.quit()
	check(move.has("type"), "CC: 置き場所を提案する (%s)" % str(move))
	if move.has("type"):
		# T 以外なら（T をホールドして）そのミノが出る位置から探す
		if move.type != g.piece:
			g.hold()
		var rows := CpuBrain.rows_from(g.board)
		check(CpuBrain.path_to(rows, g.piece, Vector3i(g.pos.x, g.pos.y, g.rot), move) != null,
			"CC: 提案された置き場所まで自前の探索で行ける (%s)" % str(move))


# ---------------- B2B（実際の操作に近い流れ） ----------------

## TSD の形の下に TETRIS 用の 4 段（右端が井戸）を置いた盤面
func _tsd_then_tetris_game() -> GameState:
	return make_game([
		"XXX.......",
		"XX...XXXXX",
		"XXX.XXXXXX",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"XXXXXXXXX.",
		"X.XXXXXXXX",
	], PieceData.T, 0, Vector2i(3, 19))


## 1 tick ずつ入力を流す
func _press(h: InputHandler, g: GameState, action: String, hold_ticks := 1) -> void:
	for i in hold_ticks:
		h.update({action: true}, {action: i == 0})
		g.tick()
	h.update({}, {})
	g.tick()


func _settle(g: GameState) -> void:
	for _i in 60:
		if g.can_control() and g.pieces_placed > 0:
			return
		g.tick()


func test_b2b_tspin_then_tetris_with_input() -> void:
	var g := _tsd_then_tetris_game()
	g.hold_used = true
	var ev := capture(g)
	var h := InputHandler.new(g)
	# T を右に 1 回して（東向き）、左へ 1 マス、その場落下 → 右回転で TSD
	_press(h, g, "rotate_cw")
	_press(h, g, "left")
	g.sonic_drop()
	_press(h, g, "rotate_cw")
	_press(h, g, "hard_drop")
	var c1 := find_event(ev, "clear")
	check(c1.get("spin") == GameState.Spin.FULL and c1.get("lines") == 2, "B2B: 入力で TSD (%s)" % str(c1))
	_settle(g)
	ev.clear()
	_drop_i_right(g)
	var c2 := find_event(ev, "clear")
	check(c2.get("lines") == 4 and c2.get("b2b") == 1, "B2B: TSD のあとの TETRIS は B2B (%s)" % str(c2))
	check(g.b2b == 1, "B2B: 連続回数が 1")


func test_b2b_tsd_locked_by_delay() -> void:
	var g := _tsd_then_tetris_game()
	var ev := capture(g)
	g.piece = PieceData.T
	g.rot = 1
	g.pos = Vector2i(2, 32)  # TSD の穴（この盤面では上から 32 段目）の上で東向き
	check(g.rotate(1), "B2B(遅延): 回せる")
	for _i in GameState.LOCK_DELAY + 2:
		g.tick()
	var c1 := find_event(ev, "clear")
	check(c1.get("spin") == GameState.Spin.FULL, "B2B(遅延): ロックディレイで固定しても Tスピン (%s)" % str(c1))


func test_b2b_tsd_while_soft_dropping() -> void:
	var g := _tsd_then_tetris_game()
	g.hold_used = true
	var ev := capture(g)
	var h := InputHandler.new(g)
	_press(h, g, "rotate_cw")
	_press(h, g, "left")
	# ソフトドロップを押しっぱなしで下まで落とし、押したまま回す
	for _i in 120:
		h.update({"soft_drop": true}, {})
		g.tick()
		if g.is_grounded():
			break
	h.update({"soft_drop": true, "rotate_cw": true}, {"rotate_cw": true})
	g.tick()
	for _i in GameState.LOCK_DELAY + 2:
		h.update({"soft_drop": true}, {})
		g.tick()
	var c1 := find_event(ev, "clear")
	check(c1.get("spin") == GameState.Spin.FULL and c1.get("lines") == 2, "B2B(ソフトドロップ中): TSD になる (%s)" % str(c1))


# ---------------- 練習・モード ----------------

func test_drills_are_solvable() -> void:
	for d in SpinDrills.all():
		var g := GameState.new(1)
		SpinDrills.apply(d, g.board)
		g.start_with(d.piece)
		var start := Vector3i(g.pos.x, g.pos.y, g.rot)
		var sol := SpinDrills.solution(d, g.board, start)
		check(not sol.is_empty(), "練習: %s %s に正解がある" % [d.name, d.rows[0]])
		if sol.is_empty():
			continue
		var rows := CpuBrain.rows_from(g.board)
		var sol_cells := SpinDrills.cells_at(d.piece, sol.rot, Vector2i(sol.x, sol.y))
		# 正解だけがその段数を消せて、回さずに落とすだけでは入らない
		var others := 0
		for p in CpuBrain.find_placements(rows, d.piece, start):
			if CpuBrain.place(rows, d.piece, p.rot, p.x, p.y)[1] >= d.lines \
					and SpinDrills.cells_at(d.piece, p.rot, Vector2i(p.x, p.y)) != sol_cells:
				others += 1
		check(others == 0, "練習: %s %s の正解はひとつだけ" % [d.name, d.rows[0]])
		var by_drop := false
		for p in CpuBrain.find_placements(rows, d.piece, start, true):
			by_drop = by_drop or SpinDrills.cells_at(d.piece, p.rot, Vector2i(p.x, p.y)) == sol_cells
		check(not by_drop, "練習: %s %s は回さないと入らない" % [d.name, d.rows[0]])
		# 正解の手順を実際に入力すると、その段数を消せる
		var ev := capture(g)
		for a in sol.path:
			match a:
				CpuBrain.Act.LEFT: g.move(-1)
				CpuBrain.Act.RIGHT: g.move(1)
				CpuBrain.Act.CW: g.rotate(1)
				CpuBrain.Act.CCW: g.rotate(-1)
				CpuBrain.Act.DROP: g.sonic_drop()
		g.hard_drop()
		var c := find_event(ev, "clear")
		var ok: bool = c.get("lines") == d.lines
		if d.piece == PieceData.T:
			ok = ok and c.get("spin") == GameState.Spin.FULL
		check(ok, "練習: %s を実際に決められる (%s)" % [d.name, str(c)])


func test_openers_can_be_built() -> void:
	var rng := RandomNumberGenerator.new()
	for id in OpenerDrills.OPENERS:
		for trial in 2:
			rng.seed = 7 + trial
			var d := OpenerDrills.build(id, rng)
			check(not d.is_empty(), "開幕テンプレ %s: 組める順番がある" % id)
			if d.is_empty():
				continue
			# 実際に手順どおり入力して、Tスピンがその段数で決まる
			var g := GameState.new(1)
			g.start_with_queue(d.queue)
			var ev := capture(g)
			var ok := true
			for step in d.steps:
				ok = ok and g.piece == step.type
				var path = null
				for p in CpuBrain.find_placements(CpuBrain.rows_from(g.board), g.piece, Vector3i(g.pos.x, g.pos.y, g.rot)):
					if SpinDrills.cells_at(g.piece, p.rot, Vector2i(p.x, p.y)) == step.cells:
						path = p.path
				ok = ok and path != null
				if path == null:
					break
				ev.clear()
				for a in path:
					match a:
						CpuBrain.Act.LEFT: g.move(-1)
						CpuBrain.Act.RIGHT: g.move(1)
						CpuBrain.Act.CW: g.rotate(1)
						CpuBrain.Act.CCW: g.rotate(-1)
						CpuBrain.Act.DROP: g.sonic_drop()
				g.hard_drop()
				if step.tspin > 0:
					var c := find_event(ev, "clear")
					ok = ok and c.get("spin") == GameState.Spin.FULL and c.get("lines") == step.tspin
				for _t in 40:
					g.tick()
			check(ok, "開幕テンプレ %s: 手順どおりに置けて Tスピンが決まる" % id)
			if id == "op_pco":
				check(g.board.is_empty(), "開幕テンプレ %s: 全消しになる" % id)


func test_pc_drill_is_solvable() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 5:
		rng.seed = 100 + i
		var d := PcDrills.generate(rng, 5)
		var g := GameState.new(1)
		var src: Board = d.board
		for y in Board.HEIGHT:
			g.board.grid[y] = src.grid[y].duplicate()
		g.start_with_queue(d.queue)
		check(g.piece == d.queue[0] and g.next_queue()[0] == d.queue[1], "パフェ練習: 決めた順番でミノが出る")
		# 手順どおりに置くと全消しになる
		var perfect := false
		g.event.connect(func(kind, data): if kind == "clear" and data.perfect: perfect = true)
		var follows := true
		for step in d.steps:
			follows = follows and g.piece == step.type and CpuBrain.rows_from(g.board) == step.rows
			g.piece = step.type
			g.rot = step.rot
			g.pos = Vector2i(step.x, step.y)
			g.hard_drop()
			for _t in 40:
				g.tick()
		check(follows, "パフェ練習 %d: 手順の途中の盤面が記録と同じ" % i)
		check(g.board.is_empty(), "パフェ練習 %d: 手順どおりで全消し" % i)


func test_hold_can_be_disabled() -> void:
	var g := GameState.new(3)
	g.allow_hold = false
	g.start()
	check(not g.hold(), "ホールドを禁止できる")


func test_finish_ends_game() -> void:
	var g := GameState.new(3)
	g.start()
	var ev := capture(g)
	g.finish()
	check(g.phase == GameState.Phase.CLEARED and not find_event(ev, "finished").is_empty(), "時間切れで終わらせられる")
