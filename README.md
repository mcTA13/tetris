# Tetris（Godot 4）

コントローラーで遊べる Windows 向けテトリス。

- SRS（壁蹴り）、7種1巡、ホールド、NEXT 5
- Tスピン（Mini / TST 蹴り含む）と全ミノスピン、B2B、REN、全消し
- モード: 40ライン、マラソン、CPU 対戦（Lv.1〜5 ＋ 隠しの TAS）
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
| `scripts/ai/` | CPU。Lv.1〜3 は自前の思考（`cpu_brain.gd`）、Lv.4 以上は Cold Clear 2 |
| `bin/` | Cold Clear 2 の実行ファイルとライセンス |
| `tests/` | ロジックのテストと、画面確認用のスクリーンショット |

## CPU（Cold Clear 2）

Lv.4・Lv.5・TAS は [Cold Clear 2](https://github.com/MinusKelvin/cold-clear-2)（MinusKelvin 作、MIT / Apache-2.0）を
外部プロセスとして起動し、Tetris Bot Protocol（標準入出力の JSON）で置き場所を聞いている。
`bin/cold-clear-2.exe` が見つからないときは自前の思考で代わりに戦う。

作り直すとき（Rust が必要）:

```
git clone https://github.com/MinusKelvin/cold-clear-2.git
cd cold-clear-2
cargo build --release
copy target\release\cold-clear-2.exe <このプロジェクト>\bin\
```

使っているコミットは `bin/COLD-CLEAR-2-VERSION.txt`。ゲームを書き出したときは、exe と同じフォルダに `cold-clear-2.exe` を置く。

## ライセンス

- 同梱フォント M PLUS Rounded 1c は SIL Open Font License 1.1（`assets/fonts/OFL.txt`）
- 同梱の Cold Clear 2 は MIT / Apache-2.0（`bin/COLD-CLEAR-2-LICENSE-*`）
