class_name Board
## 盤面。grid[y][x]、y=0 が一番上。見える範囲は y >= HIDDEN_ROWS。

const WIDTH := 10
const VISIBLE_ROWS := 20
const HIDDEN_ROWS := 20
const HEIGHT := VISIBLE_ROWS + HIDDEN_ROWS

var grid: Array[PackedByteArray] = []


func _init() -> void:
	for _y in HEIGHT:
		grid.append(_empty_row())


func is_blocked(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return true
	return grid[y][x] != PieceData.NONE


## ミノ（type, rot）をボックス左上 pos に置けるか
func fits(type: int, rot: int, pos: Vector2i) -> bool:
	for c in PieceData.cells(type, rot):
		if is_blocked(pos.x + c.x, pos.y + c.y):
			return false
	return true


func place(type: int, rot: int, pos: Vector2i) -> void:
	for c in PieceData.cells(type, rot):
		grid[pos.y + c.y][pos.x + c.x] = type


func full_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in HEIGHT:
		if not grid[y].has(PieceData.NONE):
			rows.append(y)
	return rows


## rows（昇順）を消して上を詰める
func remove_rows(rows: Array[int]) -> void:
	for y in rows:
		grid.remove_at(y)
		grid.insert(0, _empty_row())


func is_empty() -> bool:
	for row in grid:
		for v in row:
			if v != PieceData.NONE:
				return false
	return true


func _empty_row() -> PackedByteArray:
	var row := PackedByteArray()
	row.resize(WIDTH)
	return row
