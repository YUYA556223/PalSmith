# V7: タイトルメニューへのエントリ注入(Palリソース活用)

**目的**: 起動画面(タイトルメニュー)に、Palworld自身のUIリソース(ボタンスタイル・フォント)を
使ったPalSmithのエントリを追加する。これが成立すれば PalSmith は「既存メニューを拡張できる基盤」になり、
他のModもこの仕組みに乗れる。

## 段取り

1. **V7a 調査(このプローブ)**: タイトル画面のWidget階層を自動ダンプ。
   - タイトルメニューのBlueprintクラスパス
   - ボタンを並べているコンテナ(VerticalBox/一覧Widget)の名前
   - 既存ボタンのWidgetクラス(これを複製してスタイルを継承する)
2. **V7b 注入**: 調査結果をもとに、既存ボタンWidgetを`StaticConstructObject`で複製 →
   ラベルを差し替え → コンテナに追加 → クリックでPalSmith Mod Managerを開く
3. **フォールバック**: 注入が不安定なら「Palリソースを使った独自パネル」を
   タイトルからキーで開く方式(既に動作しているLua-native UIの延長)

## V7a プローブ(キー不要・自動ダンプ)

`src/client/` を `ue4ss/Mods/PalSmithTitleProbe/` に配置。起動してタイトル画面に到達すると、
LoopAsyncで `UPalUITitleBase` を探し、見つかったら階層を
`Win64/ue4ss/Mods/PalSmithTitleProbe/title_dump.txt` に書き出す(1回のみ)。

ダンプ内容: 各Widgetの `名前 / クラス / 種別(Panel/Button/Text)`、ボタン候補、テキスト候補。

## 結果記録

(実施後にここへ: タイトルメニューのクラスパス、ボタンコンテナ名、既存ボタンクラス)
