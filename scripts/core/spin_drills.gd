class_name SpinDrills
## スピン練習の課題。盤面の下側を文字列で持つ（'X' が埋まり、'.' が空き。最後が一番下の行）。
## 左右反転した課題も自動で作る（S と Z、L と J は反転すると入れ替わる）。
## 正解は「その段数を消せるただ一つの置き場所」（tests で、回さないと入らないことも確かめている）。

const BASE := [
	{
		"set": "t", "piece": PieceData.T, "name": "TSD", "lines": 2,
		"rows": [
			"XXX.......",
			"XX...XXXXX",
			"XXX.XXXXXX",
			"XXXXXXXXX.",
			"XXXXXXXXX.",
		],
	},
	{
		# 屋根の下にすべり込ませて回すと、5 番目の壁蹴りで縦の溝にはまる
		"set": "t", "piece": PieceData.T, "name": "TST", "lines": 3,
		"rows": [
			"......XXXX",
			".......XXX",
			"XXXXXX.XXX",
			"XXXXX..XXX",
			"XXXXXX.XXX",
		],
	},
	{
		# 段差の下に、横向きの S を回して押し込む
		"set": "sz", "piece": PieceData.S, "name": "SSD", "lines": 2,
		"rows": [
			"......XXXX",
			"XXX..XXXXX",
			"XX..XXXXXX",
		],
	},
	{
		# 縦向きの S を、屋根の下の溝に回して入れる
		"set": "sz", "piece": PieceData.S, "name": "SST", "lines": 3,
		"rows": [
			".......XXX",
			"......XXXX",
			"XXXX.XXXXX",
			"XXXX..XXXX",
			"XXXXX.XXXX",
		],
	},
	{
		"set": "lj", "piece": PieceData.L, "name": "LSD", "lines": 2,
		"rows": [
			".......XXX",
			"XXX.XXXXXX",
			"X...XXXXXX",
		],
	},
	{
		# 屋根の下の段差に、L を回して入れる
		"set": "lj", "piece": PieceData.L, "name": "LSD", "lines": 2,
		"rows": [
			"XXX.......",
			"XXXXX.....",
			"XXXXXX.XXX",
			"XXXX...XXX",
		],
	},
]
const MIRROR := {PieceData.T: PieceData.T, PieceData.S: PieceData.Z, PieceData.Z: PieceData.S,
	PieceData.L: PieceData.J, PieceData.J: PieceData.L}


## 課題の一覧。sets は "t" / "sz" / "lj" の並び（元の形と左右反転を交互に）。
## "side" は屋根（高く積んである側）が "left" か "right"
static func all(sets: Array = ["t", "sz", "lj"]) -> Array:
	var out := []
	for d in BASE:
		if not sets.has(d.set):
			continue
		var original: Dictionary = d.duplicate()
		original["side"] = _roof_side(original.rows)
		out.append(original)
		var flipped: Dictionary = d.duplicate()
		flipped.rows = d.rows.map(func(r: String) -> String: return r.reverse())
		flipped.piece = MIRROR[d.piece]
		flipped.name = PieceData.NAMES[flipped.piece] + d.name.substr(1)  # 頭の文字がミノの名前（SSD → ZSD）
		flipped["side"] = _roof_side(flipped.rows)
		out.append(flipped)
	return out


## 一番上の行で、埋まっているのが左半分か右半分か
static func _roof_side(rows: Array) -> String:
	var top: String = rows[0]
	return "left" if top.find("X") < Board.WIDTH / 2 else "right"


## 課題の盤面を作る
static func apply(drill: Dictionary, board: Board) -> void:
	var rows: Array = drill.rows
	var top := Board.HEIGHT - rows.size()
	for i in rows.size():
		var line: String = rows[i]
		for x in Board.WIDTH:
			board.grid[top + i][x] = PieceData.GARBAGE if line[x] == "X" else PieceData.NONE


## 正解の置き場所（start から行けて、lines 段消せるもの）。なければ空
static func solution(drill: Dictionary, board: Board, start: Vector3i) -> Dictionary:
	var rows := CpuBrain.rows_from(board)
	for p in CpuBrain.find_placements(rows, drill.piece, start):
		var placed := CpuBrain.place(rows, drill.piece, p.rot, p.x, p.y)
		if placed[1] == drill.lines:
			return p
	return {}


## ミノが盤面で占めるマス（向きが違っても同じ形なら同じになるよう、並べ替えて返す）
static func cells_at(type: int, rot: int, pos: Vector2i) -> Array:
	var out := []
	for c in PieceData.cells(type, rot):
		out.append(pos + c)
	out.sort()
	return out
