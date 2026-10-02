extends Node
## アップデート。起動時に GitHub の最新リリースを確かめ、新しい版があれば知らせる。
## インストーラーで入れた場合は、インストーラーをダウンロードして確認なしで実行し、ゲームを終わる
## （インストーラーが終わるとゲームを起動し直す）。zip で入れた場合はダウンロードページを開く。

signal changed                  # 確認が終わった・ダウンロードの状態が変わった

const LATEST_URL := "https://api.github.com/repos/mcTA13/tetris/releases/latest"
const INSTALLER_PREFIX := "Tetris-Setup-"
const UNINSTALLER := "unins000.exe"     # これが exe の隣にあればインストーラーで入れたもの

var available := false          # 新しい版がある
var latest_version := ""
var downloading := false
var failed := false

var _page_url := ""
var _installer_url := ""
var _http := HTTPRequest.new()


func _ready() -> void:
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	# 前のアップデートで使ったインストーラーが残っていれば消す
	if FileAccess.file_exists(_installer_path()):
		DirAccess.remove_absolute(_installer_path())
	# 書き出したゲームのときだけ確かめる（エディタから動かしているときは確かめない）
	if not OS.has_feature("template"):
		return
	_http.request(LATEST_URL, ["User-Agent: Tetris", "Accept: application/vnd.github+json"])


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## "1.10" > "1.9" のように数字ごとに比べる
static func is_newer(latest: String, current: String) -> bool:
	var a := latest.trim_prefix("v").split(".")
	var b := current.trim_prefix("v").split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


func is_installed() -> bool:
	return FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join(UNINSTALLER))


## 進み具合 0〜1（大きさが分からなければ 0）
func progress() -> float:
	var total := _http.get_body_size()
	return float(_http.get_downloaded_bytes()) / total if total > 0 else 0.0


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if downloading:
		_on_downloaded(result, code)
	else:
		_on_checked(result, code, body)


func _on_checked(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var tag: String = data.get("tag_name", "")
	if not is_newer(tag, current_version()):
		return
	latest_version = tag.trim_prefix("v")
	_page_url = data.get("html_url", "")
	for asset in data.get("assets", []):
		var name: String = asset.get("name", "")
		if name.begins_with(INSTALLER_PREFIX) and name.ends_with(".exe"):
			_installer_url = asset.get("browser_download_url", "")
	available = true
	changed.emit()


## アップデートを始める
func start() -> void:
	if downloading:
		return
	if not is_installed() or _installer_url == "":
		OS.shell_open(_page_url)
		return
	downloading = true
	failed = false
	_http.download_file = _installer_path()
	if _http.request(_installer_url, ["User-Agent: Tetris"]) != OK:
		_fail()
	changed.emit()


func _installer_path() -> String:
	return OS.get_user_data_dir().path_join("Tetris-Setup.exe")


func _on_downloaded(result: int, code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail()
		return
	# 前と同じ場所に上書きインストールし、終わったらゲームを起動し直す（tools/installer.iss の [Run]）
	OS.create_process(_installer_path(), ["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"])
	get_tree().quit()


func _fail() -> void:
	downloading = false
	failed = true
	changed.emit()
