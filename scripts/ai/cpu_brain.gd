class_name CpuBrain
extends RefCounted
## CPU の思考。Cold Clear（MinusKelvin 作のテトリス AI）の評価方法を参考にしている。
##  - 盤面は 1 行を 10 ビットの整数で持つ（速さのため）
##  - 置ける場所は「移動・回転・その場落下」を幅優先で探す（Tスピンやすべり込みも見つかる）
##  - 評価 = 置いたときのご褒美（TETRIS・Tスピン・B2B・REN・全消し・送るライン）＋ 盤面の良さ
##  - NEXT とホールドを使ってビームサーチで数手先まで読む
## ここの関数はすべて渡されたデータだけを使うので、別スレッドから呼んでよい。

const W := Board.WIDTH
const H := Board.HEIGHT
const FULL := (1 << W) - 1
const DEATH_HEIGHT := Board.VISIBLE_ROWS  # これ以上積むと負け扱い

enum Act { LEFT, RIGHT, CW, CCW, DROP }

# ---- 盤面の良さ（Cold Clear の標準の重みを参考） ----
const V_HEIGHT := -39.0
const V_TOP_HALF := -150.0
const V_TOP_QUARTER := -511.0
const V_BUMPINESS := -24.0
const V_BUMPINESS_SQ := -7.0
const V_ROW_TRANSITIONS := -5.0
const V_CAVITY := -173.0
const V_CAVITY_SQ := -3.0
const V_OVERHANG := -34.0
const V_OVERHANG_SQ := -1.0
const V_COVERED := -17.0
const V_COVERED_SQ := -1.0
const V_TSLOT := [8.0, 148.0, 192.0, 407.0]    # Tスピンの穴（消せるライン数ごと）
const V_WELL_DEPTH := 57.0
const V_MAX_WELL_DEPTH := 8                  # 井戸の深さはここまで数える
const V_WELL_COLUMN := [20.0, 23.0, 20.0, 50.0, 59.0, 21.0, 59.0, 10.0, -10.0, 24.0]
const V_JEOPARDY := -11.0                    # 予告が溜まっているのに高く積んでいる

# ---- 置いたときのご褒美 ----
const R_CLEAR := [0.0, -143.0, -100.0, -58.0, 390.0]
const R_TSPIN := [0.0, 121.0, 410.0, 602.0]
const R_MINI := [0.0, -158.0, -93.0]
const R_B2B := 104.0
const R_PERFECT := 999.0
const R_COMBO_GARBAGE := 150.0
const R_WASTED_T := -152.0                   # T を Tスピン以外で使った
const R_ATTACK := 10.0                       # 送るライン 1 本ごと（Cold Clear の重みで攻撃重視になっているので控えめに上乗せ）


# ================= 盤面（ビット） =================

static func rows_from(board: Board) -> PackedInt32Array:
	var rows := PackedInt32Array()
	rows.resize(H)
	for y in H:
		var bits := 0
		var row: PackedByteArray = board.grid[y]
		for x in W:
			if row[x] != PieceData.NONE:
				bits |= 1 << x
		rows[y] = bits
	return rows


static func fits(rows: PackedInt32Array, type: int, rot: int, x: int, y: int) -> bool:
	for c in PieceData.cells(type, rot):
		var cx: int = x + c.x
		var cy: int = y + c.y
		if cx < 0 or cx >= W or cy < 0 or cy >= H:
			return false
		if rows[cy] & (1 << cx):
			return false
	return true


static func blocked(rows: PackedInt32Array, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return true
	return (rows[y] & (1 << x)) != 0


static func drop_y(rows: PackedInt32Array, type: int, rot: int, x: int, y: int) -> int:
	while fits(rows, type, rot, x, y + 1):
		y += 1
	return y


## GameState._detect_spin と同じ規則（テストで一致を確かめている）
static func detect_spin(rows: PackedInt32Array, type: int, rot: int, x: int, y: int, last_rotation: bool, kick_index: int) -> int:
	if not last_rotation or type == PieceData.O:
		return GameState.Spin.NONE
	if type == PieceData.T:
		var filled := [blocked(rows, x, y), blocked(rows, x + 2, y), blocked(rows, x + 2, y + 2), blocked(rows, x, y + 2)]
		if filled.count(true) < 3:
			return GameState.Spin.NONE
		if (filled[rot] and filled[(rot + 1) % 4]) or kick_index == 4:
			return GameState.Spin.FULL
		return GameState.Spin.MINI
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if fits(rows, type, rot, x + d.x, y + d.y):
			return GameState.Spin.NONE
	return GameState.Spin.MINI


## 置いて、揃った行を消す。戻り値 [新しい行, 消えた行数]
static func place(rows: PackedInt32Array, type: int, rot: int, x: int, y: int) -> Array:
	var out := rows.duplicate()
	for c in PieceData.cells(type, rot):
		out[y + c.y] |= 1 << (x + c.x)
	var kept := PackedInt32Array()
	var cleared := 0
	for r in out:
		if r == FULL:
			cleared += 1
		else:
			kept.append(r)
	if cleared > 0:
		var fresh := PackedInt32Array()
		fresh.resize(cleared)
		fresh.append_array(kept)
		out = fresh
	return [out, cleared]


# ================= 探索 =================

static func _key(x: int, y: int, rot: int, flag: int) -> int:
	return (((x + 3) * H + y) * 4 + rot) * 4 + flag


## 置ける場所を幅優先で探す。start = Vector3i(x, y, rot)。
## 戻り値 [{"x","y","rot","spin","flag","path": Array[Act]}]（spin 付きで重複なし）
## hard_drop_only なら回転と横移動だけ（落下途中の操作なし）
static func find_placements(rows: PackedInt32Array, type: int, start: Vector3i, hard_drop_only := false) -> Array:
	var parent := {}
	var queue := [[start.x, start.y, start.z, 0]]
	parent[_key(start.x, start.y, start.z, 0)] = null
	var found := {}
	var result := []
	var head := 0
	while head < queue.size():
		var s: Array = queue[head]
		head += 1
		var x: int = s[0]
		var y: int = s[1]
		var rot: int = s[2]
		var flag: int = s[3]
		var here := _key(x, y, rot, flag)

		# 接地していれば置き場所の候補
		var ground := drop_y(rows, type, rot, x, y)
		if ground == y:
			var spin := detect_spin(rows, type, rot, x, y, (flag & 1) != 0, 4 if (flag & 2) != 0 else 0)
			var fkey := _key(x, y, rot, spin)
			if not found.has(fkey):
				found[fkey] = true
				result.append({"x": x, "y": y, "rot": rot, "spin": spin, "path": _path(parent, here)})

		if hard_drop_only:
			# 出現位置の高さで回転・移動したあと、まっすぐ落とすだけ
			if ground != y:
				_visit(parent, queue, here, Act.DROP, x, ground, rot, 0)
			if y == start.y:
				for a in [Act.LEFT, Act.RIGHT, Act.CW, Act.CCW]:
					_try_action(rows, type, parent, queue, here, a, x, y, rot, true)
			continue

		if ground != y:
			_visit(parent, queue, here, Act.DROP, x, ground, rot, 0)
		for a in [Act.LEFT, Act.RIGHT, Act.CW, Act.CCW]:
			_try_action(rows, type, parent, queue, here, a, x, y, rot, false)
	return result


static func _try_action(rows: PackedInt32Array, type: int, parent: Dictionary, queue: Array, here: int, a: int,
		x: int, y: int, rot: int, keep_height: bool) -> void:
	if a == Act.LEFT or a == Act.RIGHT:
		var nx := x + (-1 if a == Act.LEFT else 1)
		if fits(rows, type, rot, nx, y):
			_visit(parent, queue, here, a, nx, y, rot, 0)
		return
	var to_rot := (rot + (1 if a == Act.CW else 3)) % 4
	var kicks: Array = PieceData.kicks(type, rot, to_rot)
	for i in kicks.size():
		var k: Vector2i = kicks[i]
		if fits(rows, type, to_rot, x + k.x, y + k.y):
			if keep_height and k.y != 0:
				return
			_visit(parent, queue, here, a, x + k.x, y + k.y, to_rot, 1 | (2 if i == 4 else 0))
			return


static func _visit(parent: Dictionary, queue: Array, from_key: int, a: int, x: int, y: int, rot: int, flag: int) -> void:
	var k := _key(x, y, rot, flag)
	if parent.has(k):
		return
	parent[k] = [from_key, a]
	queue.append([x, y, rot, flag])


static func _path(parent: Dictionary, key: int) -> Array:
	var path := []
	var k = key
	while parent[k] != null:
		path.push_front(parent[k][1])
		k = parent[k][0]
	return path


# ================= 評価 =================

## 置いたときのご褒美と、置いた後の状態。戻り値 {"reward", "attack", "b2b", "combo", "rows", "cleared"}
static func apply_move(rows: PackedInt32Array, type: int, p: Dictionary, b2b: int, combo: int) -> Dictionary:
	var placed := place(rows, type, p.rot, p.x, p.y)
	var new_rows: PackedInt32Array = placed[0]
	var cleared: int = placed[1]
	var spin: int = p.spin
	var reward := 0.0
	var attack := 0
	var is_tspin: bool = type == PieceData.T and spin != GameState.Spin.NONE

	if cleared > 0:
		if spin == GameState.Spin.FULL:
			reward += R_TSPIN[cleared]
			attack = GameState.TSPIN_ATTACK[cleared]
		elif spin == GameState.Spin.MINI:
			reward += R_MINI[mini(cleared, 2)] if type == PieceData.T else R_CLEAR[cleared]
			attack = maxi(GameState.MINI_ATTACK[mini(cleared, 2)], GameState.LINE_ATTACK[cleared])
		else:
			reward += R_CLEAR[cleared]
			attack = GameState.LINE_ATTACK[cleared]
		var difficult := cleared == 4 or spin != GameState.Spin.NONE
		if difficult:
			b2b += 1
			if b2b >= 1:
				reward += R_B2B
				attack += 1
		else:
			b2b = -1
		combo += 1
		if combo >= 1:
			var combo_attack: int = GameState.COMBO_ATTACK[mini(combo, GameState.COMBO_ATTACK.size() - 1)]
			attack += combo_attack
			reward += R_COMBO_GARBAGE * combo_attack
		if new_rows[H - 1] == 0:
			reward += R_PERFECT
			attack = GameState.PERFECT_CLEAR_ATTACK
	else:
		combo = -1
	if type == PieceData.T and not (is_tspin and cleared > 0):
		reward += R_WASTED_T
	reward += R_ATTACK * attack
	return {"reward": reward, "attack": attack, "b2b": b2b, "combo": combo, "rows": new_rows, "cleared": cleared}


## 盤面の良さ（大きいほどよい）。incoming は予告のライン数
static func evaluate(rows: PackedInt32Array, incoming := 0, b2b := -1) -> float:
	var heights := PackedInt32Array()
	heights.resize(W)
	for x in W:
		var bit := 1 << x
		for y in H:
			if rows[y] & bit:
				heights[x] = H - y
				break
	var max_h := 0
	var well := 0
	for x in W:
		max_h = maxi(max_h, heights[x])
		if heights[x] < heights[well]:
			well = x
	if max_h >= DEATH_HEIGHT:
		return -100000.0

	var v := 0.0
	v += V_HEIGHT * max_h
	v += V_TOP_HALF * maxi(max_h - 10, 0) + V_TOP_QUARTER * maxi(max_h - 15, 0)
	if incoming > 0:
		v += V_JEOPARDY * incoming * max_h

	# でこぼこ（井戸の列は飛ばして隣どうしを比べる）
	var bump := 0
	var bump_sq := 0
	var prev := -1
	for x in W:
		if x == well:
			continue
		if prev >= 0:
			var d := absi(heights[x] - heights[prev])
			bump += d
			bump_sq += d * d
		prev = x
	v += V_BUMPINESS * bump + V_BUMPINESS_SQ * bump_sq

	# 行ごとの「埋まり ↔ 空き」の切り替わり
	var transitions := 0
	for y in range(H - max_h, H):
		var r: int = rows[y] | (1 << W)  # 右の壁
		var shifted: int = (r << 1) | 1  # 左の壁
		transitions += _popcount((r ^ shifted) & ((1 << (W + 1)) - 1))
	v += V_ROW_TRANSITIONS * transitions

	# 穴: 横から入れるものは「張り出し」、入れないものは「空洞」
	var cavities := 0
	var overhangs := 0
	var covered := 0
	var covered_sq := 0
	for x in W:
		var top := H - heights[x]
		var above := 0
		for y in range(top, H):
			if rows[y] & (1 << x):
				above += 1
				continue
			# 横が空いていて、上に乗っているのが浅ければ、すべり込ませて埋められる張り出し。
			# 井戸は TETRIS 用に空けておく列なので、そこからは埋められない扱い
			var side_open := (x > 0 and x - 1 != well and heights[x - 1] < H - y) \
				or (x < W - 1 and x + 1 != well and heights[x + 1] < H - y)
			if side_open and above <= 2:
				overhangs += 1
			else:
				cavities += 1
			var c := mini(above, 6)
			covered += c
			covered_sq += c * c
	v += V_CAVITY * cavities + V_CAVITY_SQ * cavities * cavities
	v += V_OVERHANG * overhangs + V_OVERHANG_SQ * overhangs * overhangs
	v += V_COVERED * covered + V_COVERED_SQ * covered_sq

	# 井戸: 一番低い列の上で、ほかが全部埋まっている行の数（TETRIS の準備）
	var depth := 0
	var well_mask := FULL & ~(1 << well)
	for y in range(H - 1 - heights[well], -1, -1):
		if rows[y] == well_mask:
			depth += 1
		else:
			break
	v += V_WELL_DEPTH * mini(depth, V_MAX_WELL_DEPTH) + V_WELL_COLUMN[well]

	# Tスピンの穴
	v += V_TSLOT[_best_tslot(rows, heights)]
	return v


## T を回し入れて消せる最大ライン数（穴がなければ 0）
static func _best_tslot(rows: PackedInt32Array, heights: PackedInt32Array) -> int:
	var best := 0
	for rot in [2, 1, 3]:
		for x in range(-1, W - 1):
			var hi := 0
			var lo := H
			for dx in 3:
				var cx := x + dx
				if cx >= 0 and cx < W:
					hi = maxi(hi, heights[cx])
					lo = mini(lo, heights[cx])
			for y in range(maxi(H - hi - 3, 0), mini(H - lo + 1, H - 1)):
				if not fits(rows, PieceData.T, rot, x, y) or fits(rows, PieceData.T, rot, x, y + 1):
					continue
				if detect_spin(rows, PieceData.T, rot, x, y, true, 0) != GameState.Spin.FULL:
					continue
				# 真ん中の列が上まで空いていないと T は入れられない（埋もれた穴は数えない）
				if not _column_open_above(rows, x + 1, y if rot == 2 else y - 1):
					continue
				var placed := place(rows, PieceData.T, rot, x, y)
				best = maxi(best, placed[1])
	return mini(best, 3)


## x 列の row 行から上がすべて空いているか
static func _column_open_above(rows: PackedInt32Array, x: int, row: int) -> bool:
	var bit := 1 << x
	for y in range(row, -1, -1):
		if rows[y] & bit:
			return false
	return true


static func _popcount(n: int) -> int:
	var c := 0
	while n:
		n &= n - 1
		c += 1
	return c


# ================= 先読み（ビームサーチ） =================

## state: {"rows", "piece", "pos": Vector3i, "hold", "hold_used", "queue": Array, "b2b", "combo", "incoming"}
## config: {"depth", "beam", "spins": bool, "use_hold": bool}
## 戻り値 {"hold": bool, "x", "y", "rot", "spin", "candidates": [...上位の手]}。置けなければ空
static func think(state: Dictionary, config: Dictionary) -> Dictionary:
	var spawn := Vector3i(GameState.SPAWN_POS.x, GameState.SPAWN_POS.y, 0)
	var root := {
		"rows": state.rows, "cur": state.piece, "hold": state.hold, "qi": 0,
		"b2b": state.b2b, "combo": state.combo, "reward": 0.0, "first": null,
		"can_hold": not state.hold_used and config.use_hold,
		"start": state.pos,
	}
	var beam := [root]
	var queue: Array = state.queue
	var first_moves := []
	for depth in config.depth:
		var children := []
		for node in beam:
			for option in _options(node, queue):
				var type: int = option.type
				var start: Vector3i = node.start if depth == 0 and not option.hold else _spawn_for(type, node.rows)
				if start.x < -10:
					continue
				for p in find_placements(node.rows, type, start, not config.spins):
					var m := apply_move(node.rows, type, p, node.b2b, node.combo)
					var child := {
						"rows": m.rows, "cur": option.next_cur, "hold": option.next_hold, "qi": option.next_qi,
						"b2b": m.b2b, "combo": m.combo, "reward": node.reward + m.reward * pow(0.95, depth),
						"can_hold": config.use_hold, "start": spawn,
						"first": node.first if node.first != null else {"hold": option.hold, "x": p.x, "y": p.y, "rot": p.rot, "spin": p.spin},
					}
					child["score"] = child.reward + evaluate(m.rows, state.incoming if depth == 0 else 0, m.b2b)
					children.append(child)
		if children.is_empty():
			break
		children.sort_custom(func(a, b): return a.score > b.score)
		if depth == 0:
			first_moves = children
		beam = children.slice(0, config.beam)
		# 次のミノが分からなくなったら終わり
		if beam[0].cur == PieceData.NONE:
			break
	if beam.is_empty() or beam[0].first == null:
		return {}
	var best: Dictionary = beam[0].first.duplicate()
	# 1手目の候補（ミスの演出に使う）
	var candidates := []
	for c in first_moves.slice(0, 6):
		candidates.append(c.first)
	best["candidates"] = candidates
	return best


## そのノードで置けるミノの選び方（そのまま / ホールド）
static func _options(node: Dictionary, queue: Array) -> Array:
	var qi: int = node.qi
	var next_from_queue: int = queue[qi] if qi < queue.size() else PieceData.NONE
	var out := [{"type": node.cur, "hold": false, "next_cur": next_from_queue, "next_hold": node.hold, "next_qi": qi + 1}]
	if node.can_hold:
		if node.hold != PieceData.NONE:
			if node.hold != node.cur:
				out.append({"type": node.hold, "hold": true, "next_cur": next_from_queue, "next_hold": node.cur, "next_qi": qi + 1})
		elif next_from_queue != PieceData.NONE and next_from_queue != node.cur:
			var after: int = queue[qi + 1] if qi + 1 < queue.size() else PieceData.NONE
			out.append({"type": next_from_queue, "hold": true, "next_cur": after, "next_hold": node.cur, "next_qi": qi + 2})
	return out.filter(func(o): return o.type != PieceData.NONE)


## ミノが出る位置（ゲームと同じく、出たらすぐ1段下げる）。出られなければ x=-99
static func _spawn_for(type: int, rows: PackedInt32Array) -> Vector3i:
	var x := GameState.SPAWN_POS.x + (1 if type == PieceData.O else 0)
	var y := GameState.SPAWN_POS.y
	if not fits(rows, type, 0, x, y):
		return Vector3i(-99, 0, 0)
	if fits(rows, type, 0, x, y + 1):
		y += 1
	return Vector3i(x, y, 0)


## 今の状態から目標（x, y, rot, spin）までの操作列。見つからなければ null
static func path_to(rows: PackedInt32Array, type: int, start: Vector3i, target: Dictionary) -> Variant:
	for p in find_placements(rows, type, start):
		# スピンの種類は T だけ比べる（Cold Clear 2 は T 以外のスピンを区別しない）
		if p.x == target.x and p.y == target.y and p.rot == target.rot and (type != PieceData.T or p.spin == target.spin):
			return p.path
	return null
