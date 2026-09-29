extends SceneTree
## コアロジックのテスト。実行: godot --headless --path . -s tests/run_tests.gd

var _failures := 0
var _count := 0


func _init() -> void:
	test_bag_is_7_bag()
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
	check(info.spin == GameState.Spin.MINI and info.piece == PieceData.S, "Sスピン: 動けなければスピン(Mini扱い)")
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
