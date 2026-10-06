extends Node
## 選択中のモード、自己ベスト、設定の保存、今の見た目（スキン）。

enum Mode { SPRINT_40L, MARATHON, ULTRA, DIG, PRACTICE }

const SAVE_PATH := "user://save.json"
const LEVEL_SCHEME := 2         # CPU の強さの番号の付け方（2: Lv.1〜7 と TAS=8）
const OLD_LEVELS := {1: 1, 2: 2, 3: 4, 4: 6, 5: 7, 6: 8}  # 5 段階のころの番号 → 今の番号
const MODE_KEYS := {  # Loc のキー
	Mode.SPRINT_40L: "mode_40l", Mode.MARATHON: "mode_marathon", Mode.ULTRA: "mode_ultra",
	Mode.DIG: "mode_dig", Mode.PRACTICE: "mode_practice",
}
const ASSIST_MODES := ["off", "free", "six_three"]
const SOFT_DROP_INSTANT := 0    # soft_drop がこの値なら即座に一番下まで
# 見た目の一覧。テイストを増やすときはここに追加する
const SKINS := {"pop": preload("res://scripts/skin/pop_skin.gd"), "classic": preload("res://scripts/skin/classic_skin.gd")}

const DEFAULT_SETTINGS := {
	"das": 10,
	"arr": 2,
	"soft_drop": 20,
	"line_clear_delay": 18,
	"are": 0,
	"das_cut": true,
	"vibration": true,
	"se_volume": 7,             # 効果音の音量 0〜10
	"bgm_volume": 6,            # BGM の音量 0〜10
	"confirm_b": false,         # true なら B(○) で決定
	"label_style": "auto",      # auto / xbox / ps
	"language": "",             # 空なら OS の言語に合わせる
	"skin": "pop",
	"assist": "off",            # 40ラインのアシスト: off / free（自由に積む）/ six_three（6-3 積み）
}

var mode := Mode.SPRINT_40L
var best_40l_ticks := 0         # 0 は記録なし
var marathon_best_score := 0
var ultra_best_score := 0
var dig_best := 0               # 掘りモードで掘った最多段数
var ren_best := 0               # REN 練習の最大 REN
var practice := "spin_t"        # 練習の種類（Mode.PRACTICE のとき。保存しない）
var menu_category := ""         # タイトルで開いていた大分類（保存しない）
# CPU 対戦
var versus_level := 4           # 1〜7（CpuPlayer.MAX_LEVEL）、8 は隠しの TAS
var versus_first_to := 2
var versus_records := {}        # 強さ → [勝ち, 負け]
var demo := false               # CPU 同士のデモを見ている（保存しない）
var demo_levels := [6, 6]       # デモの左右の CPU の強さ
var settings := DEFAULT_SETTINGS.duplicate()
var bindings := {}              # {"pad": {action: [button]}, "key": {action: [keycode]}}。空なら既定
var skin: UiSkin


func _ready() -> void:
	_load()
	InputSetup.apply(bindings, settings.confirm_b)
	apply_look()


## 言語とスキンを設定に合わせる
func apply_look() -> void:
	if settings.language not in Loc.LANGUAGES:
		settings.language = Loc.default_language()
	Loc.language = settings.language
	if not SKINS.has(settings.skin):
		settings.skin = SKINS.keys()[0]
	if skin == null or skin.get_script() != SKINS[settings.skin]:
		skin = SKINS[settings.skin].new()


## 新記録なら true
func submit_40l(ticks: int) -> bool:
	if best_40l_ticks != 0 and ticks >= best_40l_ticks:
		return false
	best_40l_ticks = ticks
	save()
	return true


func submit_versus(level: int, won: bool) -> void:
	var record: Array = versus_record(level)
	record[0 if won else 1] += 1
	versus_records[level] = record
	save()


## 強さの名前（"Lv.3" / "TAS"）
static func level_name(level: int) -> String:
	return "TAS" if level == CpuPlayer.TAS_LEVEL else "Lv.%d" % level


## 強さの目安（例「速さ ★★★☆☆　読み ★★☆☆☆　攻撃 ★★★☆☆」）
static func level_stars(level: int) -> String:
	var stars: Array = CpuPlayer.CONFIG[level].stars
	var parts := []
	for i in 3:
		parts.append("%s %s" % [Loc.t(["star_speed", "star_read", "star_attack"][i]), "★".repeat(stars[i]) + "☆".repeat(5 - stars[i])])
	return "　".join(parts)


## [勝ち, 負け]
func versus_record(level: int) -> Array:
	return versus_records.get(level, [0, 0]).duplicate()


func submit_ultra(score: int) -> bool:
	if score <= ultra_best_score:
		return false
	ultra_best_score = score
	save()
	return true


func submit_dig(dug: int) -> bool:
	if dug <= dig_best:
		return false
	dig_best = dug
	save()
	return true


func submit_ren(ren: int) -> bool:
	if ren <= ren_best:
		return false
	ren_best = ren
	save()
	return true


func submit_marathon(score: int) -> bool:
	if score <= marathon_best_score:
		return false
	marathon_best_score = score
	save()
	return true


## 設定を GameState / InputHandler に反映する
func configure(game: GameState, input: InputHandler) -> void:
	game.are_frames = settings.are
	game.line_clear_frames = settings.line_clear_delay
	game.soft_drop_factor = 1000.0 if settings.soft_drop == SOFT_DROP_INSTANT else float(settings.soft_drop)
	input.das = settings.das
	input.arr = settings.arr
	input.das_cut_on_switch = settings.das_cut


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"best_40l_ticks": best_40l_ticks,
		"marathon_best_score": marathon_best_score,
		"ultra_best_score": ultra_best_score,
		"dig_best": dig_best,
		"ren_best": ren_best,
		"versus_level": versus_level,
		"versus_first_to": versus_first_to,
		"versus_records": versus_records,
		"demo_levels": demo_levels,
		"level_scheme": LEVEL_SCHEME,
		"settings": settings,
		"bindings": bindings,
	}, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	best_40l_ticks = int(data.get("best_40l_ticks", 0))
	marathon_best_score = int(data.get("marathon_best_score", 0))
	ultra_best_score = int(data.get("ultra_best_score", 0))
	dig_best = int(data.get("dig_best", 0))
	ren_best = int(data.get("ren_best", 0))
	# 強さが 5 段階だったころの保存データは、7 段階の番号に移し替える
	var remap: Dictionary = {} if int(data.get("level_scheme", 1)) >= LEVEL_SCHEME else OLD_LEVELS
	versus_level = clampi(remap.get(int(data.get("versus_level", 3)), int(data.get("versus_level", 3))), 1, CpuPlayer.MAX_LEVEL)  # 隠しの TAS は毎回コマンドで出す
	versus_first_to = clampi(int(data.get("versus_first_to", 2)), 1, 3)
	var saved_demo = data.get("demo_levels", [4, 4])
	if saved_demo is Array and saved_demo.size() == 2:
		# 隠しの TAS は保存しない（毎回コマンドで出す）
		demo_levels = [clampi(remap.get(int(saved_demo[0]), int(saved_demo[0])), 1, CpuPlayer.MAX_LEVEL),
			clampi(remap.get(int(saved_demo[1]), int(saved_demo[1])), 1, CpuPlayer.MAX_LEVEL)]
	var records = data.get("versus_records", {})
	if records is Dictionary:
		for k in records:
			versus_records[remap.get(int(k), int(k))] = [int(records[k][0]), int(records[k][1])]
	var saved: Dictionary = data.get("settings", {})
	for k in DEFAULT_SETTINGS:
		if saved.has(k):
			# JSON の数値は float で戻るので既定値の型に合わせる
			settings[k] = type_convert(saved[k], typeof(DEFAULT_SETTINGS[k]))
	# 前の版はアシストがオン / オフだった（true は「フリー」に引き継ぐ）
	if settings.assist not in ASSIST_MODES:
		settings.assist = "free" if settings.assist == "true" else "off"
	var saved_bindings = data.get("bindings", {})
	if saved_bindings is Dictionary:
		for kind in saved_bindings:
			bindings[kind] = {}
			for action in saved_bindings[kind]:
				bindings[kind][action] = saved_bindings[kind][action].map(func(v): return int(v))


## 分:秒.1/100 秒（例 01:23.45）
static func format_time(ticks: int) -> String:
	var cs := ticks * 100 / 60
	return "%02d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]
