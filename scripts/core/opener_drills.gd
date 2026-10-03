class_name OpenerDrills
## 開幕テンプレ練習の課題。テンプレを「段階」の並びで持つ。
##  形の段階: 盤面の下側の文字列（上の行から）。ミノの文字のマスがその段階で置くミノ、'G' は前の段階までのマス、'.' は空き
##  Tスピンの段階: {"tspin": 消す段数}。置き場所はその時点の盤面から探す（その段数を消せる T の置き場所）
## 形は Hard Drop Wiki とテンプレ解説サイトの図から写した。置く順番は、実際に置ける順をランダムに探して決める。

const OPENERS := {
	# TKI（開幕TSD）。キャッスルトップ型
	"op_tki": [
		[
			".........J",
			".........J",
			"L..ZZ.S.JJ",
			"L...ZZSSOO",
			"LL.IIIISOO",
		],
		{"tspin": 2},
	],
	# パフェ開幕（I を縦に置く型）。2 巡目の J・T・I で全消し
	"op_pco": [
		[
			"LLLI....SS",
			"LOOI...SST",
			"JOOI..ZZTT",
			"JJJI...ZZT",
		],
		[
			"GGGGIIIIGG",
			"GGGGTTTGGG",
			"GGGGJTGGGG",
			"GGGGJJJGGG",
		],
	],
	# DT 砲（JL 土台）。2 巡目のあと TSD → TST
	"op_dt": [
		[
			"....T.....",
			"...TTTI...",
			"....ZJILS.",
			"OO.ZZJILSS",
			"OO.ZJJILLS",
		],
		[
			"..LL....SS",
			"...LZZ.SSI",
			"JJ.LGZZOOI",
			"J..GGGGOOI",
			"J...GGGGGI",
			"GG.GGGGGGG",
			"GG.GGGGGGG",
		],
		{"tspin": 2},
		{"tspin": 3},
	],
	# はちみつ砲（2 巡目 A）。2 巡目のあと TST
	"op_honey": [
		[
			"L.........",
			"L......ZZ.",
			"LLT....JZZ",
			"OOTTSS.JJJ",
			"OOTSS.IIII",
		],
		[
			"......LLLI",
			"..ZJ..LOOI",
			"GZZJ...OOI",
			"GZJJSS.GGI",
			"GGGSS..GGG",
			"GGGGGG.GGG",
			"GGGGG.GGGG",
		],
		{"tspin": 3},
	],
	# 山岳積み。1 巡目の J は 2 巡目で使う（この練習ではホールドしなくても組める順番で出す）
	"op_mountain": [
		[
			"LS........",
			"LSS....T..",
			"LLS.ZZTTOO",
			"IIII.ZZTOO",
		],
		[
			"OOJJ.....I",
			"OOJ......I",
			"GGJ.ZZJJJI",
			"GGG..ZZGJI",
			"GGG.GGGGGG",
			"GGGG.GGGGG",
		],
		{"tspin": 3},
	],
}
const LETTERS := {"I": PieceData.I, "O": PieceData.O, "T": PieceData.T, "S": PieceData.S,
	"Z": PieceData.Z, "J": PieceData.J, "L": PieceData.L}


## 置く手順を作る。戻り値 {"steps": [{"type", "cells"（並べ替えたマス）, "x", "y", "rot", "stage", "tspin"}...], "queue": [ミノ...]}。
## 置き方が見つからなければ空
static func build(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var rows := PackedInt32Array()
	rows.resize(Board.HEIGHT)
	var steps := []
	var stages: Array = OPENERS[id]
	for i in stages.size():
		var stage = stages[i]
		if stage is Dictionary:
			var t := _tspin(rows, stage.tspin)
			if t.is_empty():
				return {}
			t["stage"] = i
			steps.append(t)
			rows = CpuBrain.place(rows, PieceData.T, t.rot, t.x, t.y)[0]
			continue
		var pieces := _pieces(stage)
		var order := []
		if not _order(rows, pieces, order, rng):
			return {}
		for p in order:
			p["stage"] = i
			p["tspin"] = 0
			steps.append(p)
			rows = CpuBrain.place(rows, p.type, p.rot, p.x, p.y)[0]
	return {"steps": steps, "queue": steps.map(func(s: Dictionary) -> int: return s.type)}


## 形の段階の文字列から、置くミノ（種類とマス）を取り出す
static func _pieces(grid: Array) -> Array:
	var top := Board.HEIGHT - grid.size()
	var seen := {}
	var out := []
	for r in grid.size():
		for x in Board.WIDTH:
			var ch: String = grid[r][x]
			if not LETTERS.has(ch) or seen.has(Vector2i(x, top + r)):
				continue
			# 同じ文字でつながったマスを 1 個のミノとして集める
			var cells := []
			var stack := [Vector2i(x, top + r)]
			seen[stack[0]] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				cells.append(p)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					var gr := q.y - top
					if q.x < 0 or q.x >= Board.WIDTH or gr < 0 or gr >= grid.size():
						continue
					if grid[gr][q.x] == ch and not seen.has(q):
						seen[q] = true
						stack.append(q)
			cells.sort()
			out.append({"type": LETTERS[ch], "cells": cells})
	return out


## 置ける順番を探す（出現位置から行けるミノから置いていく）。見つかれば order に入れて true。
## 人が組むときの自然な順番になるよう、下の段に置くミノを先に、同じ高さなら回さずに置けるミノを先にする
static func _order(rows: PackedInt32Array, pieces: Array, order: Array, rng: RandomNumberGenerator) -> bool:
	if pieces.is_empty():
		return true
	var candidates := []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var placement := _find(rows, p.type, p.cells)
		if placement.is_empty():
			continue
		var bottom := 0
		for c in p.cells:
			bottom = maxi(bottom, c.y)
		var by_drop := not _find(rows, p.type, p.cells, true).is_empty()
		candidates.append({"i": i, "placement": placement, "key": bottom * 4 + (2 if by_drop else 0) + rng.randi_range(0, 1)})
	candidates.sort_custom(func(a, b): return a.key > b.key)
	for cand in candidates:
		var i: int = cand.i
		var p: Dictionary = pieces[i]
		var placement: Dictionary = cand.placement
		var rest := pieces.duplicate()
		rest.remove_at(i)
		var step := {"type": p.type, "cells": p.cells, "x": placement.x, "y": placement.y, "rot": placement.rot}
		order.append(step)
		if _order(CpuBrain.place(rows, p.type, placement.rot, placement.x, placement.y)[0], rest, order, rng):
			return true
		order.pop_back()
	return false


## そのマスにぴったり置ける置き場所（出現位置から行けるもの）
static func _find(rows: PackedInt32Array, type: int, cells: Array, hard_drop_only := false) -> Dictionary:
	for p in CpuBrain.find_placements(rows, type, _spawn(type), hard_drop_only):
		if SpinDrills.cells_at(type, p.rot, Vector2i(p.x, p.y)) == cells:
			return p
	return {}


## lines 段消せる Tスピンの置き場所
static func _tspin(rows: PackedInt32Array, lines: int) -> Dictionary:
	for p in CpuBrain.find_placements(rows, PieceData.T, _spawn(PieceData.T)):
		if p.spin == GameState.Spin.FULL and CpuBrain.place(rows, PieceData.T, p.rot, p.x, p.y)[1] == lines:
			return {"type": PieceData.T, "cells": SpinDrills.cells_at(PieceData.T, p.rot, Vector2i(p.x, p.y)),
				"x": p.x, "y": p.y, "rot": p.rot, "tspin": lines}
	return {}


static func _spawn(type: int) -> Vector3i:
	return Vector3i(GameState.SPAWN_POS.x + (1 if type == PieceData.O else 0), GameState.SPAWN_POS.y, 0)
