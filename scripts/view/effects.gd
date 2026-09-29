class_name Effects
extends RefCounted
## 画面演出の状態（粒・大きな文字・残像・揺れ・フラッシュ・カウンターの跳ね）。
## 動きの計算だけを持ち、描き方はスキンに任せる。

const POPUP_DURATION := 1.4
const TRAIL_DURATION := 0.2
const FLASH_DURATION := 0.25
const BOUNCE_DURATION := 0.25

var _particles := []
var _popups := []
var _trails := []
var _shake := 0.0
var _shake_time := 0.0
var _bump := 0.0
var _flash := 0.0
var _bounce := {}               # カウンター名 → 残り時間
var _rng := RandomNumberGenerator.new()


func burst(center: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var angle := _rng.randf_range(-PI, 0.0) + _rng.randf_range(-0.4, 0.4)
		var v := Vector2.from_angle(angle) * speed * _rng.randf_range(0.35, 1.0)
		_particles.append({
			"pos": center, "vel": v, "color": color,
			"life": 0.0, "max_life": _rng.randf_range(0.5, 0.9),
			"size": _rng.randf_range(6.0, 11.0),
			"rot": _rng.randf_range(0.0, TAU), "spin": _rng.randf_range(-12.0, 12.0),
		})


## 大技の文字。今出ているものは新しいものに置き換える
func popup(lines: Array) -> void:
	_popups = [{"lines": lines, "t": 0.0}]


## 今出ているものが消えてから出す（レベルアップなど）
func queue_popup(lines: Array) -> void:
	_popups.append({"lines": lines, "t": 0.0})


func trail(rect: Rect2, color: Color) -> void:
	_trails.append({"rect": rect, "color": color, "t": 0.0})


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func bump(amount: float) -> void:
	_bump = maxf(_bump, amount)


func flash(alpha: float) -> void:
	_flash = maxf(_flash, alpha)


func bounce(key: String) -> void:
	_bounce[key] = BOUNCE_DURATION


## 0〜1。増えた直後ほど大きい
func bounce_amount(key: String) -> float:
	return _bounce.get(key, 0.0) / BOUNCE_DURATION


func clear() -> void:
	_particles.clear()
	_popups.clear()
	_trails.clear()
	_shake = 0.0
	_bump = 0.0
	_flash = 0.0
	_bounce.clear()


func update(delta: float, gravity: float) -> void:
	for p in _particles:
		p.life += delta
		p.vel = p.vel + Vector2(0, gravity * delta)
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	_particles = _particles.filter(func(p): return p.life < p.max_life)
	if not _popups.is_empty():
		_popups[0].t += delta
		if _popups[0].t >= POPUP_DURATION:
			_popups.pop_front()
	for tr in _trails:
		tr.t += delta
	_trails = _trails.filter(func(tr): return tr.t < TRAIL_DURATION)
	_shake = move_toward(_shake, 0.0, delta * 60.0)
	_shake_time += delta
	_bump = move_toward(_bump, 0.0, delta * 40.0)
	_flash = move_toward(_flash, 0.0, delta * 0.35 / FLASH_DURATION)
	for k in _bounce.keys():
		_bounce[k] = maxf(_bounce[k] - delta, 0.0)


## 画面全体のずれ（揺れ）
func screen_offset() -> Vector2:
	if _shake <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_shake_time * 71.0), cos(_shake_time * 53.0)) * _shake


## 盤面だけのずれ（ハードドロップで沈む）
func board_offset() -> Vector2:
	return Vector2(0, _bump)


func draw_trails(ci: CanvasItem, skin: UiSkin) -> void:
	for tr in _trails:
		skin.draw_trail(ci, tr.rect, tr.color, 1.0 - tr.t / TRAIL_DURATION)


func draw_particles(ci: CanvasItem, skin: UiSkin) -> void:
	for p in _particles:
		skin.draw_particle(ci, p.pos, p.size, p.color, p.rot, 1.0 - p.life / p.max_life)


func draw_popups(ci: CanvasItem, skin: UiSkin, center: Vector2, scale := 1.0) -> void:
	if not _popups.is_empty():
		skin.draw_popup(ci, center, _popups[0].lines, _popups[0].t, POPUP_DURATION, scale)


func draw_flash(ci: CanvasItem, skin: UiSkin, rect: Rect2) -> void:
	if _flash > 0.0:
		skin.draw_flash(ci, rect, _flash)
