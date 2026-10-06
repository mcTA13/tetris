class_name Practice
extends RefCounted
## 練習モードの共通部分。ゲーム画面（game.gd）から呼ばれる。
## 課題ごとに「盤面を用意 → 置く → 成功 / 失敗」を繰り返す練習と、
## REN 練習のようにゲームオーバーまで続ける練習（continuous）がある。

var attempts := 0
var successes := 0
var show_hint := false          # 失敗したら、お手本の置き場所をガイドで見せる


## 新しい GameState に盤面などを用意する（READY の前）
func setup(_game: GameState) -> void:
	pass


## GO! のとき
func start(game: GameState) -> void:
	game.start()


## ホールドを使えるか
func allow_hold() -> bool:
	return true


## ゲームのイベントごとに必ず呼ばれる（盤面の積み足しや記録など、判定以外のこと）
func on_event(_kind: String, _data: Dictionary, _game: GameState) -> void:
	pass


## 課題の判定。結果が出たら "success" / "fail" を返す（結果が出るまでのイベントだけ呼ばれる）
func judge(_kind: String, _data: Dictionary, _game: GameState) -> String:
	return ""


## 結果を見せたあとに呼ばれる。成功なら次の課題、失敗なら同じ課題をお手本付きで
func advance(success: bool) -> void:
	show_hint = not success


## ガイドで見せる置き場所 {"type", "x", "y", "rot"}。なければ空
func guide(_game: GameState) -> Dictionary:
	return {}


## 情報パネルの [見出し, 値] の並び
func stats() -> Array:
	return [[Loc.t("practice_success"), "%d / %d" % [successes, attempts]]]


## ゲームオーバーまで続ける練習か（課題ごとに区切らない）
func continuous() -> bool:
	return false


## ゲームオーバーのときの結果表示（continuous の練習だけ）
func result_lines() -> Array:
	return []


## 成功 / 失敗を記録して返す
func _result(success: bool) -> String:
	attempts += 1
	if success:
		successes += 1
	return "success" if success else "fail"
