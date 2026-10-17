class_name MenuCursor
extends RefCounted
## メニューで選んでいる項目を示すカーソル。選んでいる項目の枠へ、ばねのように近づいていく。
## 画面は描くたびに update() へ選んでいる項目の枠を渡し、スキンの draw_cursor() で描く。
## 動き方はスキンの cursor_motion で決める（stiffness が大きいほど速く、damping 1 で行き過ぎずに止まる。stiffness 0 は一瞬で移る）。

const TRAIL_SECONDS := 0.3      # 残像のために覚えておく長さ
const SUBSTEPS := 8             # ばねが強くても暴れないよう、1 フレームを細かく分けて動かす

var rect := Rect2()
var velocity := Vector2.ZERO    # 位置の速さ（ピクセル/秒）
var rest := 0.0                 # 目標で止まってからの秒数（動いている間は 0）
var _size_velocity := Vector2.ZERO
var _placed := false
var _last_time := 0.0
var _trail := []                # [時刻, 枠]。古い順


## 次の update() で目標へそのまま置く（メニューを開き直したときに、前の位置から滑ってこないように）
func reset() -> void:
	_placed = false
	_trail.clear()


## time: 画面の経過秒。target: 選んでいる項目の枠
func update(time: float, target: Rect2, motion: Dictionary) -> void:
	var delta := clampf(time - _last_time, 0.0, 0.05)
	_last_time = time
	var stiffness: float = motion.get("stiffness", 0.0)
	if not _placed or stiffness <= 0.0:
		rect = target
		velocity = Vector2.ZERO
		_size_velocity = Vector2.ZERO
		_placed = true
	else:
		var damping: float = 2.0 * sqrt(stiffness) * motion.get("damping", 1.0)
		var h := delta / SUBSTEPS
		for i in SUBSTEPS:
			velocity += (stiffness * (target.position - rect.position) - damping * velocity) * h
			_size_velocity += (stiffness * (target.size - rect.size) - damping * _size_velocity) * h
			rect.position += velocity * h
			rect.size += _size_velocity * h
	var settled := velocity.length() < 30.0 and rect.position.distance_to(target.position) < 1.0
	rest = rest + delta if settled else 0.0
	_trail.append([time, rect])
	while _trail.size() > 1 and time - _trail[0][0] > TRAIL_SECONDS:
		_trail.pop_front()


## age 秒前の枠（そこまで覚えていなければ、覚えている一番古い枠）
func trail_at(age: float) -> Rect2:
	for i in range(_trail.size() - 1, -1, -1):
		if _last_time - _trail[i][0] >= age:
			return _trail[i][1]
	return _trail[0][1] if not _trail.is_empty() else rect


## 枠 r にカーソルがどれだけ重なっているか（0〜1）
func coverage(r: Rect2) -> float:
	if r.get_area() <= 0.0:
		return 0.0
	return clampf(r.intersection(rect).get_area() / r.get_area(), 0.0, 1.0)
