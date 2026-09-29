class_name PieceData
## ミノの形とSRSの壁蹴り表。座標は x が右、y が下向き。

enum { NONE, I, O, T, S, Z, J, L, GARBAGE }

const NAMES := ["", "I", "O", "T", "S", "Z", "J", "L", "G"]
const ALL := [I, O, T, S, Z, J, L]

# 回転状態 0 の形（バウンディングボックス左上が原点）
const SHAPES := {
	I: [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	O: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	T: [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	S: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Z: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	J: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	L: [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}

const BOX_SIZE := {I: 4, O: 2, T: 3, S: 3, Z: 3, J: 3, L: 3}

# SRSの壁蹴り表（ガイドラインの y 上向き表記を y 下向きに変換済み）
# キーは "回転前->回転後"。0=初期, 1=R, 2=180, 3=L
const KICKS_JLSTZ := {
	"0>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"1>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"1>2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"2>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"2>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"0>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
}

const KICKS_I := {
	"0>1": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"1>0": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"1>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	"2>1": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"2>3": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"0>3": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
}

static var _cells_cache := {}


## 回転状態 rot のセル一覧（ボックス内座標）
static func cells(type: int, rot: int) -> Array:
	var key := type * 4 + rot
	if _cells_cache.has(key):
		return _cells_cache[key]
	var n: int = BOX_SIZE[type]
	var result: Array = SHAPES[type].duplicate()
	for _i in rot:
		var rotated := []
		for c in result:
			rotated.append(Vector2i(n - 1 - c.y, c.x))
		result = rotated
	_cells_cache[key] = result
	return result


static func kicks(type: int, from_rot: int, to_rot: int) -> Array:
	if type == O:
		return [Vector2i(0, 0)]
	var key := "%d>%d" % [from_rot, to_rot]
	return KICKS_I[key] if type == I else KICKS_JLSTZ[key]
