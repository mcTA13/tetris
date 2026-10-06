---
name: release
description: テトリスの新しいバージョンをリリースする（バージョン番号の更新、書き出し、インストーラー作成、コミット・タグ・push、GitHub リリース作成、公開の確認）。「v1.8 をリリース」「リリース作成」「ダミーで 1.8.1 を作成」などと頼まれたときに使う。引数はバージョン番号（例: 1.8）。
---

# リリース手順

引数のバージョン（例: `1.8`）でリリースする。プロジェクトのフォルダは `C:\Users\ta13\tetris`。

## 1. 確認
- `git status` で未コミットの変更を見る。あれば内容ごとにコミットしてから進める（コミットメッセージは日本語、末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`）
- 今のバージョン（`project.godot` の `config/version`）と、公開済みの最新リリース（`gh release list`）より大きい番号か確かめる。ダミー版を含めて最新より小さいと、インストーラー版の人に更新が届かない
- 自動テストを流す: `godot --headless --path . -s tests/run_tests.gd` と `godot --headless --path . tests/practice_check.tscn`。失敗したら止めて報告する

## 2. バージョン番号
- `project.godot`: `config/version="<版>"`
- `export_presets.cfg`: `application/file_version` と `application/product_version` を `"<版>.0"` の 4 桁（例: `1.8.0.0`）

## 3. 書き出し
- PowerShell で `powershell -ExecutionPolicy Bypass -File tools\export.ps1`
  - `dist\Tetris-windows-x86_64.zip` と `dist\Tetris-Setup-v<版>.exe` ができる
- zip を `dist\Tetris-v<版>-windows-x86_64.zip` にコピーする
- `build\Tetris.exe` を数秒起動して落ちないことを確かめ、終わらせる（`build\lib\cold-clear-2.exe` も残っていれば止める）。インストール済みのゲーム（`%LOCALAPPDATA%\Programs\Tetris`）には触らない

## 4. コミット・タグ・push
- ふつうのリリース: main で `バージョン <版>` とコミット → `git tag v<版>` → `git push` と `git push origin v<版>`
- ダミー版（動作確認用）: `git switch --detach` してからバージョンだけ変えてコミット → タグ → `git push origin v<版>`（タグだけ）→ `git switch main`。main の履歴には入れない

## 5. GitHub リリース
- リリースノートを書く（日本語）。ゲーム内のアップデート画面に先頭から出るので、**前の本番リリースからの変更点を先頭に**書く。そのあとに「遊び方」（インストーラー版はゲーム内から更新できる、初めてならインストーラー、入れたくなければ zip）、動作環境、ライセンス、`BGM: KOROBUSHKA (Ryu☆Remix)`
- ダミー版はリリースノートの冒頭に、動作確認用で中身は前の版と同じだと書く
- `gh release create v<版> dist/Tetris-Setup-v<版>.exe dist/Tetris-v<版>-windows-x86_64.zip --title "Tetris v<版>" --notes-file <ノート>`
- 通信エラーで下書き（draft）のまま止まることがある。`gh release view v<版> --json isDraft` を見て、下書きなら `gh release edit v<版> --draft=false`

## 6. 公開の確認
- `curl -s https://api.github.com/repos/mcTA13/tetris/releases/latest` の `tag_name` が `v<版>` で、`assets` に `Tetris-Setup-v<版>.exe` があること
- 報告: リリースの URL、コミット、配布ファイルの名前と大きさ、確認したこと
