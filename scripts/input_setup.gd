extends Node
## ボタン割り当て（キーボード＋コントローラー）と、1 tick 分の入力状態の取り出し。

const ACTIONS := [
	"left", "right", "soft_drop", "hard_drop", "rotate_cw", "rotate_ccw", "hold", "pause", "retry",
	"accept", "back", "menu_up", "menu_down", "menu_left", "menu_right",
]
# 設定画面で割り当てを変えられる操作（メニュー操作は固定）
const REMAPPABLE := ["left", "right", "soft_drop", "hard_drop", "rotate_ccw", "rotate_cw", "hold", "pause", "retry"]
const STICK_DEADZONE := 0.5
const MENU_REPEAT_DELAY := 0.4  # メニューで倒しっぱなしにしたとき、連続で進み始めるまで
const MENU_REPEAT_RATE := 0.12
const STICK_DOWN_HALF_ANGLE := deg_to_rad(30.0)  # 真下 ±30° だけを下入力にする

const DEFAULT_KEYS := {
	"left": [KEY_LEFT], "right": [KEY_RIGHT], "soft_drop": [KEY_DOWN], "hard_drop": [KEY_UP, KEY_SPACE],
	"rotate_cw": [KEY_X], "rotate_ccw": [KEY_Z], "hold": [KEY_C, KEY_SHIFT],
	"pause": [KEY_ESCAPE], "retry": [KEY_R], "accept": [KEY_ENTER], "back": [KEY_BACKSPACE],
	"menu_up": [KEY_UP], "menu_down": [KEY_DOWN], "menu_left": [KEY_LEFT], "menu_right": [KEY_RIGHT],
}
const DEFAULT_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"soft_drop": [JOY_BUTTON_DPAD_DOWN], "hard_drop": [JOY_BUTTON_DPAD_UP],
	"rotate_cw": [JOY_BUTTON_B], "rotate_ccw": [JOY_BUTTON_A],
	"hold": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
	"pause": [JOY_BUTTON_START], "retry": [JOY_BUTTON_BACK],
	"accept": [JOY_BUTTON_A], "back": [JOY_BUTTON_B],
	"menu_up": [JOY_BUTTON_DPAD_UP], "menu_down": [JOY_BUTTON_DPAD_DOWN],
	"menu_left": [JOY_BUTTON_DPAD_LEFT], "menu_right": [JOY_BUTTON_DPAD_RIGHT],
}

var _pressed_since_poll := {}
var _menu_dir := ""
var _menu_timer := 0.0


var _current := {"pad": {}, "key": {}}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply({}, false)


## 割り当てを反映する。overrides: {"pad": {action: [button]}, "key": {action: [keycode]}}
func apply(overrides: Dictionary, confirm_b: bool) -> void:
	_current = {"pad": DEFAULT_BUTTONS.duplicate(true), "key": DEFAULT_KEYS.duplicate(true)}
	for kind in ["pad", "key"]:
		for action in overrides.get(kind, {}):
			if action in REMAPPABLE:
				_current[kind][action] = overrides[kind][action].duplicate()
	if confirm_b:
		_current.pad.accept = [JOY_BUTTON_B]
		_current.pad.back = [JOY_BUTTON_A]

	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for key in _current.key[action]:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button in _current.pad[action]:
			var ev := InputEventJoypadButton.new()
			ev.device = -1  # 全コントローラー対象（既定の 0 だと 1台目以外が反応しない）
			ev.button_index = button
			InputMap.action_add_event(action, ev)


## 今の割り当て（kind: "pad" / "key"）
func bindings_of(kind: String, action: String) -> Array:
	return _current[kind][action]


## action に value を割り当てた後の、割り当て変更分（REMAPPABLE 全体）を返す。
## ほかの操作が同じボタンを使っていたら外し、ボタンが無くなるなら元のボタンと入れ替える。
func rebind(kind: String, action: String, value: int) -> Dictionary:
	var table: Dictionary = {}
	for a in REMAPPABLE:
		table[a] = _current[kind][a].duplicate()
	var old: Array = table[action]
	for other in REMAPPABLE:
		if other != action and value in table[other]:
			table[other].erase(value)
			if table[other].is_empty() and not old.is_empty():
				table[other] = [old[0]]
	table[action] = [value]
	return table


func _input(event: InputEvent) -> void:
	# tick の間に押して離した短いタップも拾う
	for action in ACTIONS:
		if event.is_action_pressed(action):
			_pressed_since_poll[action] = true


## 1 tick 分の入力。戻り値 [held, pressed]
func poll() -> Array:
	var held := {}
	for action in ACTIONS:
		held[action] = Input.is_action_pressed(action)
	var stick := _stick_directions()
	held.left = held.left or stick.left
	held.right = held.right or stick.right
	held.soft_drop = held.soft_drop or stick.down
	var pressed := _pressed_since_poll
	_pressed_since_poll = {}
	return [held, pressed]


## メニュー用の上下左右。押した瞬間に1回、倒しっぱなしなら一定間隔で繰り返す。
## 毎フレーム呼ぶ。戻り値 "up" / "down" / "left" / "right" / ""
func menu_direction(delta: float) -> String:
	var dir := ""
	for d in ["up", "down", "left", "right"]:
		if Input.is_action_pressed("menu_" + d):
			dir = d
	if dir == "":
		dir = _stick_menu_direction()
	if dir != _menu_dir:
		_menu_dir = dir
		_menu_timer = MENU_REPEAT_DELAY
		return dir
	if dir == "":
		return ""
	_menu_timer -= delta
	if _menu_timer <= 0.0:
		_menu_timer += MENU_REPEAT_RATE
		return dir
	return ""


func _stick_menu_direction() -> String:
	for device in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() < STICK_DEADZONE:
			continue
		if absf(v.x) > absf(v.y):
			return "left" if v.x < 0.0 else "right"
		return "up" if v.y < 0.0 else "down"
	return ""


## 画面切り替え時などに、それまでに押された入力を捨てる
func clear_pressed() -> void:
	_pressed_since_poll = {}


func _stick_directions() -> Dictionary:
	var result := {"left": false, "right": false, "down": false}
	for device in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() < STICK_DEADZONE:
			continue
		var from_down := absf(v.angle_to(Vector2.DOWN))
		if from_down <= STICK_DOWN_HALF_ANGLE:
			result.down = true
		elif v.y < 0.0 and absf(v.x) < absf(v.y):
			pass  # 上方向は使わない（ハードドロップの誤爆防止）
		elif v.x < 0.0:
			result.left = true
		else:
			result.right = true
	return result


const XBOX_LABELS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_MISC1: "Share",
}
const PS_LABELS := {
	JOY_BUTTON_A: "×", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
	JOY_BUTTON_BACK: "Share", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_MISC1: "Mic", JOY_BUTTON_TOUCHPAD: "Touchpad",
}


const DPAD_KEYS := {
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}


func button_label(button: int) -> String:
	if DPAD_KEYS.has(button):
		return Loc.t(DPAD_KEYS[button])
	var table := PS_LABELS if _use_ps_labels() else XBOX_LABELS
	return table.get(button, "Button %d" % button)


func key_label(keycode: int) -> String:
	return OS.get_keycode_string(keycode)


## 画面のヒント用。例: "A / Enter"
func action_hint(action: String) -> String:
	var parts := []
	if not _current.pad[action].is_empty():
		parts.append(button_label(_current.pad[action][0]))
	if not _current.key[action].is_empty():
		parts.append(key_label(_current.key[action][0]))
	return " / ".join(parts)


func _use_ps_labels() -> bool:
	match App.settings.label_style:
		"ps":
			return true
		"xbox":
			return false
	return is_playstation_pad()


## PS系コントローラーがつながっているか（ボタン表示の切り替え用）
func is_playstation_pad() -> bool:
	for device in Input.get_connected_joypads():
		var name := Input.get_joy_name(device).to_lower()
		if name.contains("ps4") or name.contains("ps5") or name.contains("dualshock") or name.contains("dualsense") or name.contains("playstation"):
			return true
	return false


func vibrate(weak: float, strong: float, duration: float) -> void:
	if not App.settings.vibration:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)
