extends Node
## 画面に出す文字列（日本語 / 英語）。Loc.t("key") で取り出す。
## 技名（T-SPIN DOUBLE など）はどちらの言語でも英語表記。

const LANGUAGES := ["ja", "en"]
const LANGUAGE_NAMES := {"ja": "日本語", "en": "English"}

const STRINGS := {
	# タイトル
	"mode_40l": ["40ライン", "40 LINES"],
	"mode_marathon": ["マラソン", "MARATHON"],
	"menu_settings": ["設定", "SETTINGS"],
	"best": ["ベスト", "BEST"],
	"high_score": ["ハイスコア", "HIGH SCORE"],
	"hint_title": ["十字キー: 選択　%s: 決定", "D-Pad: Select    %s: Start"],
	"controller": ["コントローラー", "Controller"],
	"not_found": ["未接続", "not found"],
	# ゲーム
	"hold": ["ホールド", "HOLD"],
	"next": ["ネクスト", "NEXT"],
	"time": ["タイム", "TIME"],
	"lines": ["ライン", "LINES"],
	"pps": ["PPS", "PPS"],
	"score": ["スコア", "SCORE"],
	"level": ["レベル", "LEVEL"],
	"ready": ["READY", "READY"],
	"go": ["GO!", "GO!"],
	"pause": ["ポーズ", "PAUSE"],
	"resume": ["再開", "Resume"],
	"to_title": ["タイトルへ", "Title"],
	"retry": ["リトライ", "Retry"],
	"finish": ["FINISH!", "FINISH!"],
	"complete": ["COMPLETE!", "COMPLETE!"],
	"game_over": ["GAME OVER", "GAME OVER"],
	"new_record": ["新記録！", "NEW RECORD!"],
	"hint_game": ["リトライ: %s　ポーズ: %s", "Retry: %s    Pause: %s"],
	# 設定
	"settings": ["設定", "SETTINGS"],
	"set_language": ["言語 / LANGUAGE", "LANGUAGE / 言語"],
	"set_skin": ["テーマ", "THEME"],
	"set_das": ["DAS（横移動が始まるまで）", "DAS"],
	"set_arr": ["ARR（横移動の間隔）", "ARR"],
	"set_soft_drop": ["ソフトドロップ速度", "SOFT DROP SPEED"],
	"set_line_clear_delay": ["ライン消去の待ち時間", "LINE CLEAR DELAY"],
	"set_are": ["出現の待ち時間（ARE）", "SPAWN DELAY (ARE)"],
	"set_das_cut": ["左右切り替えでDASをリセット", "RESET DAS ON SWITCH"],
	"set_vibration": ["振動", "VIBRATION"],
	"set_se_volume": ["効果音の音量", "SOUND VOLUME"],
	"set_confirm_b": ["決定ボタン", "CONFIRM BUTTON"],
	"set_label_style": ["ボタン表記", "BUTTON LABELS"],
	"set_pad": ["コントローラー設定", "CONTROLLER CONFIG"],
	"set_key": ["キーボード設定", "KEYBOARD CONFIG"],
	"set_reset": ["初期設定に戻す", "RESET TO DEFAULT"],
	"set_back": ["戻る", "BACK"],
	"on": ["オン", "ON"],
	"off": ["オフ", "OFF"],
	"instant": ["即時", "INSTANT"],
	"style_auto": ["自動", "AUTO"],
	"style_xbox": ["Xbox", "Xbox"],
	"style_ps": ["PlayStation", "PlayStation"],
	"press_button": ["ボタンを押してください… %d", "PRESS A BUTTON... %d"],
	"press_key": ["キーを押してください… %d", "PRESS A KEY... %d"],
	"hint_settings": ["十字キー: 選択・変更　%s: 決定　%s: 戻る", "D-Pad: Select / Change    %s: OK    %s: Back"],
	"hint_remap": ["操作を選んで %s を押し、新しいボタンを押してください", "Select an action, press %s, then press the new button"],
	"hint_remap_key": ["操作を選んで %s を押し、新しいキーを押してください", "Select an action, press %s, then press the new key"],
	"dpad_up": ["十字キー上", "D-Pad Up"],
	"dpad_down": ["十字キー下", "D-Pad Down"],
	"dpad_left": ["十字キー左", "D-Pad Left"],
	"dpad_right": ["十字キー右", "D-Pad Right"],
	# 操作名
	"act_left": ["左移動", "MOVE LEFT"],
	"act_right": ["右移動", "MOVE RIGHT"],
	"act_soft_drop": ["ソフトドロップ", "SOFT DROP"],
	"act_hard_drop": ["ハードドロップ", "HARD DROP"],
	"act_rotate_ccw": ["左回転", "ROTATE LEFT"],
	"act_rotate_cw": ["右回転", "ROTATE RIGHT"],
	"act_hold": ["ホールド", "HOLD"],
	"act_pause": ["ポーズ", "PAUSE"],
	"act_retry": ["リトライ", "RETRY"],
}

var language := "ja"


func t(key: String) -> String:
	var entry: Array = STRINGS.get(key, [key, key])
	return entry[LANGUAGES.find(language)]


static func default_language() -> String:
	return "ja" if OS.get_locale_language() == "ja" else "en"
