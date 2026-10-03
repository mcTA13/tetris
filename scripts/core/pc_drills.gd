class_name PcDrills
## パフェ練習の課題を作る。下 4 段をちょうど埋めて全部消せる「ミノ 10 個の置き方」をランダムに探し、
## 最初の何個かを置いた状態から始める。残りのミノは置き方と同じ順番で NEXT に並べるので、必ず全消しできる。
## ミノの順番は置き方と一緒に決める（7 種 1 巡の決まりは守る）。置き方は真上から落とすだけ。

const ROWS := 4
const PIECES := 10
const MAX_NODES := 2000         # 1 回の探索で調べる局面の上限（超えたら別の順番でやり直す）
const FULL := (1 << Board.WIDTH) - 1


## remaining: 自分で置くミノの数。戻り値:
## {"board": Board（始めの盤面）, "queue": [ミノ...], "steps": [{"type", "x", "y", "rot", "rows"（置く前の盤面）}...]}
static func generate(rng: RandomNumberGenerator, remaining: int) -> Dictionary:
	while true:
		var steps := []
		var nodes := [0]
		var region := PackedInt32Array()
		region.resize(ROWS)
		if _search(region, 0, PieceData.ALL.duplicate(), steps, rng, nodes):
			var seq := steps.map(func(s: Dictionary) -> int: return s.type)
			return _build(seq, steps, PIECES - remaining)
	return {}


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## region: まだ消えていない段（上から順）。ここに収まる置き方だけを探す。bag: 今の 1 巡でまだ出ていないミノ
static func _search(region: PackedInt32Array, i: int, bag: Array, steps: Array,
		rng: RandomNumberGenerator, nodes: Array) -> bool:
	if i == PIECES:
		return region.is_empty()
	nodes[0] += 1
	if nodes[0] > MAX_NODES:
		return false
	var types := bag.duplicate()
	_shuffle(types, rng)
	for type in types:
		var rest: Array = bag.duplicate()
		rest.erase(type)
		if rest.is_empty():
			rest = PieceData.ALL.duplicate()  # 次の 1 巡
		var moves := _drops(region, type)
		_shuffle(moves, rng)
		for m in moves:
			var next := _place(region, type, m.rot, m.x, m.y)
			if not _fillable(next):
				continue
			# 盤面全体での位置（region の一番上の段は、盤面の下から region.size() 段目）
			var top := Board.HEIGHT - region.size()
			steps.append({"type": type, "x": m.x, "y": top + m.y, "rot": m.rot, "rows": _to_board_rows(region)})
			if _search(next, i + 1, rest, steps, rng, nodes):
				return true
			steps.pop_back()
	return false


## 真上から落として region に収まる置き場所（同じ形になる向きは 1 つにまとめる）
static func _drops(region: PackedInt32Array, type: int) -> Array:
	var out := []
	var seen := {}
	for rot in 4:
		var cells: Array = PieceData.cells(type, rot)
		for x in range(-3, Board.WIDTH):
			# region の上から下ろしていき、ぶつかる手前で止める（一番上の段より上に出たら置けない）
			var y := -4
			if not _fits(region, cells, x, y):
				continue
			while _fits(region, cells, x, y + 1):
				y += 1
			var inside := true
			for c in cells:
				inside = inside and y + c.y >= 0
			if not inside:
				continue
			var key := str(SpinDrills.cells_at(type, rot, Vector2i(x, y)))
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"x": x, "y": y, "rot": rot})
	return out


static func _fits(region: PackedInt32Array, cells: Array, x: int, y: int) -> bool:
	for c in cells:
		var cx: int = x + c.x
		var cy: int = y + c.y
		if cx < 0 or cx >= Board.WIDTH or cy >= region.size():
			return false
		if cy >= 0 and region[cy] & (1 << cx):
			return false
	return true


## 置いて、そろった段を消す
static func _place(region: PackedInt32Array, type: int, rot: int, x: int, y: int) -> PackedInt32Array:
	var out := region.duplicate()
	for c in PieceData.cells(type, rot):
		out[y + c.y] |= 1 << (x + c.x)
	var kept := PackedInt32Array()
	for r in out:
		if r != FULL:
			kept.append(r)
	return kept


## まだ埋められる形か: 上がふさがった空きがなく、空きのかたまりがどれも 4 の倍数
static func _fillable(region: PackedInt32Array) -> bool:
	var covered := 0
	for r in region:
		if (~r) & covered & FULL:
			return false
		covered |= r
	var seen := {}
	for y in region.size():
		for x in Board.WIDTH:
			if region[y] & (1 << x) or seen.has(Vector2i(x, y)):
				continue
			# 空きのかたまりの大きさを数える
			var size := 0
			var stack := [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				size += 1
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if q.x < 0 or q.x >= Board.WIDTH or q.y < 0 or q.y >= region.size():
						continue
					if region[q.y] & (1 << q.x) or seen.has(q):
						continue
					seen[q] = true
					stack.append(q)
			if size % 4 != 0:
				return false
	return true


## region を盤面全体の行（CpuBrain.rows_from と同じ形）にする
static func _to_board_rows(region: PackedInt32Array) -> PackedInt32Array:
	var rows := PackedInt32Array()
	rows.resize(Board.HEIGHT - region.size())
	rows.append_array(region)
	return rows


## 最初の given 個を置いた盤面（ミノの色付き）と、残りの手順
static func _build(seq: Array, steps: Array, given: int) -> Dictionary:
	var board := Board.new()
	for i in given:
		var s: Dictionary = steps[i]
		board.place(s.type, s.rot, Vector2i(s.x, s.y))
		var full := board.full_rows()
		if not full.is_empty():
			board.remove_rows(full)
	return {"board": board, "queue": seq.slice(given), "steps": steps.slice(given)}
