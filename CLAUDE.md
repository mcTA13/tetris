# Tetris（Godot 4）プロジェクトのメモ

コントローラーで遊ぶ Windows 向けテトリス。Godot 4.7.2 + GDScript。返答は日本語。

## 動かし方
- Godot: `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot_console.exe`（以下 `godot`）
- 自動テスト（autoload を使わない部分）: `godot --headless --path . -s tests/run_tests.gd`
- 練習モードの部品の確認（Loc・App などの autoload を使う）: `godot --headless --path . tests/practice_check.tscn`
  - `-s` で動かすスクリプトでは autoload が読み込まれない。Loc・App・Sfx・Bgm・Updater を使うコードのテストはシーンにする
- `class_name` を足した・名前を変えたあとは、テストの前に `godot --headless --path . --import` でクラスの一覧を作り直す
- 画面の確認は `tests/*_shot.tscn` や一時的な確認用シーン（`tests/tmp/`、終わったら消す）で画面写真を撮って見る
- CPU 同士の対戦: `godot --headless --path . -s tests/cpu_sim.gd -- <強さA> <強さB> <試合数>`
  - Cold Clear 2 を使う強さは実時間で動くので、2 つ同時に流さない（CPU の取り合いで結果がずれる）

## 構成
- `scripts/core/`: 描画に依存しないロジック（GameState・Board・Bag・SRS・課題データ）
- `scripts/practice/`: 練習モードごとの決まり（Practice を継承）。`game.gd` はこれを呼ぶだけ
- `scripts/view/`: 画面（title・game・versus・settings）。描画はスキン（`scripts/skin/`）が受け持つ
- `scripts/ai/`: CPU。Lv.1〜3 は自前、Lv.4/5/TAS・アシスト・デモは Cold Clear 2（`lib/cold-clear-2.exe`、TBP で通信）
- `scripts/updater.gd`: 起動時に GitHub の最新リリースを確かめるアップデート
- 文字列は `scripts/locale.gd`（日本語 / 英語の両方を書く）

## 決まり
- `tools/export.ps1` は UTF-8（BOM 付き）・CRLF で保存する（PowerShell 5.1 が BOM なしを CP932 で読むため）
- ミノを置く位置やスピンの課題・開幕テンプレのデータは、置けること・決まることをテストで確かめる
- 「ビルドはしなくていい」と言われたら書き出さない。コミット・push・リリースは頼まれたときだけ
- Cold Clear 2 に手を加えたら `lib/COLD-CLEAR-2-PATCH.diff` を更新し、`RUSTFLAGS="-C target-feature=+crt-static"` でビルドする

## リリース
- 手順は `/release` スキル（`.claude/skills/release/SKILL.md`）
- ゲーム内アップデートは GitHub の「最新リリース」の `Tetris-Setup-v*.exe` を使う。リリースには必ずインストーラーを付ける
- リリースノートはゲーム内のアップデート画面に先頭から表示されるので、変更点を先頭に書く
- ダミー版（v1.5.1・v1.6.1 を出した）は main とは別のコミットにタグを付ける。次の本番はそれより大きい番号にする
