class_name TSpinDrills
## Tスピン練習の課題。盤面の下側を文字列で持つ（'X' が埋まり、'.' が空き。最後が一番下の行）。
## 左右反転した課題も自動で作る。

const BASE := [
	{
		"name": "TSD", "lines": 2,
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
		"name": "TST", "lines": 3,
		"rows": [
			"......XXXX",
			".......XXX",
			"XXXXXX.XXX",
			"XXXXX..XXX",
			"XXXXXX.XXX",
		],
	},
]


## すべての課題（元の形と左右反転を交互に）。"side" は屋根（高く積んである側）が "left" か "right"
static func all() -> Array:
	var out := []
	for d in BASE:
		var original: Dictionary = d.duplicate()
		original["side"] = _roof_side(original.rows)
		out.append(original)
		var flipped: Dictionary = d.duplicate()
		flipped.rows = d.rows.map(func(r: String) -> String: return r.reverse())
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


## 正解の置き場所（出現位置から行けて、Tスピンで lines 段消せるもの）。なければ空
static func solution(drill: Dictionary, board: Board, start: Vector3i) -> Dictionary:
	var rows := CpuBrain.rows_from(board)
	for p in CpuBrain.find_placements(rows, PieceData.T, start):
		if p.spin != GameState.Spin.FULL:
			continue
		var placed := CpuBrain.place(rows, PieceData.T, p.rot, p.x, p.y)
		if placed[1] == drill.lines:
			return p
	return {}
