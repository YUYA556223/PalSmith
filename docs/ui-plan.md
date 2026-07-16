# UI実装計画(C5) — PalSmith Mod Manager

**ゴール**: タイトル画面/ゲーム内からキーで開ける「Mod Manager」。導入済みModの一覧表示と
有効/無効の切替(反映は再起動後)。SMAPIのMod Menuに相当するPalSmithの看板UI。

前提環境: UE 5.1 (`E:\Unreal\UE_5.1`) + Wwise 2021.1.11 (`E:\AudioKinetic\Wwise_2021.1.11.7933`) +
PMK (`E:\PalworldModdingKit`)。セットアップは [pmk-setup.md](pmk-setup.md) / `tools/setup-pmk.ps1`。

## 段取り

1. **Step 1 — パイプライン検証(15分)**: 最小のテストWidget(下記B-1)をcook →
   `PalSmithUI_P.pak` → `~mods` → 検証プローブ(F11、配置済み)で
   「表示・タイトル設定・クリック受信」の3点を確認。ここが通れば残りは量産
2. **Step 2 — Mod Manager Widget(B-2)**: 本命UIを作成してcook
3. **Step 3 — ランタイム統合**: `palsmith/modmanager.lua` + `ui.lua` を実装(F8トグル)
4. **ストレッチ**: タイトル画面Widgetへのボタン注入(注入ポイントの調査が必要。まずはキーバインドで出荷)

## B-1: テストWidget(パイプライン検証用)

`Content/Mods/PalSmithUI/WBP_SmithMenu` を作成:

```
Canvas Panel
└─ Border (中央寄せ、背景色、Padding 16)
   └─ Vertical Box
      ├─ Text Block  [TitleText]   ☑ Is Variable
      ├─ Button      [Button_A] └ Text Block "Entry A"
      ├─ Button      [Button_B] └ Text Block "Entry B"
      └─ Button      [Button_C] └ Text Block "Entry C"
```

BlueprintCallable関数を2つ:
- `SetTitle(NewTitle: Text)` — TitleTextにSetText
- `EntryClicked(EntryId: Name)` — **中身は空**(Luaフックポイント)。各ボタンのOnClickedから
  EntryId=`A`/`B`/`C`で呼ぶ

パッケージング: `Content/Mods/PalSmithUI/` にPrimary Asset Label(名前`PalSmithUI`、
Chunk ID 5100、`WBP_SmithMenu`を含める)→ Project Settings → Packaging → Generate Chunks ☑
→ Cook → `pakchunk5100-Windows.pak` を `PalSmithUI_P.pak` にリネーム →
クライアントの `Pal/Content/Paks/~mods/` へ。F11プローブが自動検出します。

## B-2: 本命Widget — WBP_SmithModManager

対象にするMod種別(ランタイム側で列挙):

| 種別 | 列挙方法 | 有効/無効の切替 |
|---|---|---|
| UE4SS Luaモッド | `Mods/`のフォルダ+`enabled.txt`有無 | `enabled.txt`の作成/削除 |
| PalSchemaパック(PalSmithパック含む) | `PalSchema/mods/`のフォルダ | `PalSchema/mods_disabled/`へ移動 |

### Widget構成

`WBP_SmithModManager`:

```
Canvas Panel
└─ Border [背景]
   └─ Vertical Box
      ├─ Text Block [TitleText]  ☑ Is Variable
      ├─ Scroll Box [RowContainer] ☑ Is Variable   ← 行を動的追加
      └─ Text Block [FooterText] ☑ Is Variable     ← "Restart to apply" 等
```

行ウィジェット `WBP_SmithModRow`(別Widget BPとして作成):

```
Horizontal Box
├─ Text Block [NameText]   ☑ Is Variable
├─ Text Block [StateText]  ☑ Is Variable   ← "ENABLED" / "DISABLED"
└─ Button    [ToggleButton] └ Text Block "Toggle"
```

### BP関数(すべてBlueprintCallable、Luaフック前提の設計)

WBP_SmithModManager:
- `SetTitle(Text)` / `SetFooter(Text)`
- `ClearRows()` — RowContainerの子を全削除
- `AddRow(ModId: Name, DisplayName: Text, Enabled: Boolean)` — Create Widget(WBP_SmithModRow)
  → Row変数へModId/表示を設定 → RowContainerへAdd Child
- `RowToggled(ModId: Name)` — **中身は空**(Luaフックポイント)。
  WBP_SmithModRow の ToggleButton.OnClicked → 親ManagerのRowToggledをModId付きで呼ぶ
  (RowにManager参照を持たせる: AddRow時にSelfをセット)

### ランタイム側(palsmith/modmanager.lua + ui.lua)

- キーバインド(既定F8)でトグル表示。タイトル画面でも動くか要検証(PlayerControllerなしの場合の
  Create引数を調整)
- 開くたびにMod列挙 → `ClearRows` + `AddRow`×N
- `RowToggled`フック → enabled.txt作成/削除 or フォルダ移動 → 行を更新 →
  Footerに "Restart the game to apply changes"
- World-Readyゲートとは独立(UIはロード嵐と無関係)だが、ファイル操作はpcall+ログ必須

## 検証記録

(実施後にここへ)
