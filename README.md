# Tetris（Godot 4）

コントローラーで遊べる Windows 向けテトリス。

- SRS（壁蹴り）、7種1巡、ホールド、NEXT 5
- Tスピン（Mini / TST 蹴り含む）と全ミノスピン、B2B、REN、全消し
- モード: 40ライン、マラソン（対 CPU は予定）
- 設定: DAS / ARR / ソフトドロップ速度などの調整、ボタン割り当て、日本語 / 英語
- 見た目・演出・効果音は「スキン」単位で差し替え可能（今は POP）

## 起動

Godot 4.7 で `project.godot` を開くか:

```
godot --path .
```

## テスト

```
godot --headless --path . -s tests/run_tests.gd
```

## 構成

| 場所 | 内容 |
|---|---|
| `scripts/core/` | 描画に依存しないゲームロジック（盤面、SRS、スピン判定、得点、DAS/ARR） |
| `scripts/view/` | 画面（タイトル、ゲーム、設定）と演出の動き |
| `scripts/skin/` | 見た目・演出の描き方・効果音。新しいテイストはここに追加して `App.SKINS` に登録 |
| `scripts/audio/` | 効果音の合成と再生 |
| `tests/` | ロジックのテストと、画面確認用のスクリーンショット |

## ライセンス

同梱フォント M PLUS Rounded 1c は SIL Open Font License 1.1（`assets/fonts/OFL.txt`）。
