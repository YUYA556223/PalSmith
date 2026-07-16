# V4: UI拡張(cook済みUMG Widget + Luaデータ駆動)

**目的**: C5(UI拡張)の実証。自作WidgetBlueprint(UMG)をpak化してゲームに読み込ませ、
Luaから「開閉・タイトル設定・ボタンクリック受信」ができることを確認する。
これが通れば、PalSmithの宣言的UIフレームワーク(plan.md ④)の土台が確定する。

構成: **UE5での一回きりの作業(Part A/B)** + **用意済みのLuaプローブ(Part C)**

---

## Part A: 環境構築(一回きり・Windows作業)

出典: [PMK Prerequisites](https://pwmodding.wiki/docs/developers/palworld-modding-kit/prerequisites) /
[Installation](https://pwmodding.wiki/docs/developers/palworld-modding-kit/installation)

1. **Unreal Engine 5.1.x** — Epic Games Launcher → Unreal Engine → ライブラリ → 5.1(5.1でも5.1.1でも可)
2. **Visual Studio 2022 Community** — ワークロード「C++によるデスクトップ開発」+
   個別コンポーネント「MSVC v143 - VS 2022 C++ x64/x86 Build Tools (v14.38-17.8)」
3. **.NET 6 Runtime (x64)**
4. **Wwise 2021.1.11** — Audiokinetic Launcherから。**サウンドを作らなくても必須**(無いとプロジェクトがコンパイルできない)。
   SDK: C++ / Microsoft Windows Visual Studio 2022、オフライン統合ファイルも取得
5. **PMK** — `git clone https://github.com/localcc/PalworldModdingKit`(7MBと軽量。E:配下推奨)
6. **Wwise手動統合**(インストールガイドの通り):
   - オフラインファイルの `Unreal.5.0.tar.xz` を展開 → `Wwise` フォルダをPMKの `Plugins/` へ
   - `ThirdParty` フォルダを作り Win32_vc170 / x64_vc170 / include をコピー、vc170をvc160として複製
   - `Wwise.uplugin` の `EngineVersion` を `"5.0.0"` → `"5.1"` に変更
   - `BuildConfiguration.xml` をVS2022指定に更新
7. `Pal.uproject` をダブルクリックで起動(初回はシェーダーコンパイルで長時間)

## Part B: 検証用Widgetの作成(UE5エディタ内・15分)

最小構成のメニューWidgetを1個作る。**名前とパスは厳守**(Luaプローブがこのパスを見る):

1. Content Browserで `Content/Mods/PalSmithUI/` フォルダを作成
2. そこに Widget Blueprint を新規作成 → 名前 **`WBP_SmithMenu`**
3. 階層(Hierarchy)を組む:
   ```
   Canvas Panel
   └─ Border (中央寄せ、適当な背景色、Padding 16)
      └─ Vertical Box
         ├─ Text Block  [名前: TitleText]   ☑ Is Variable
         ├─ Button      [名前: Button_A] └ Text Block (label: "Entry A")
         ├─ Button      [名前: Button_B] └ Text Block (label: "Entry B")
         └─ Button      [名前: Button_C] └ Text Block (label: "Entry C")
   ```
4. 関数を2つ作る(どちらも **BlueprintCallable**):
   - **`SetTitle`** — 入力: `NewTitle (Text)`。中身: `TitleText` に SetText
   - **`EntryClicked`** — 入力: `EntryId (Name)`。**中身は空でOK**(Print Stringを置いても可)
     ← これがLuaのフックポイント
5. 各ボタンの `OnClicked` イベント → `EntryClicked` を呼ぶ(Button_Aは EntryId=`A`、以下B/C)
6. コンパイル・保存

### パッケージング(pak化)

出典: [PalSchema弓ガイドのパッケージング節](https://okaetsu.github.io/PalSchema/docs/guides/items/creatingabow)と同じ手順:

1. `Content/Mods/PalSmithUI/` に **Primary Asset Label** を作成(名前: `PalSmithUI`)
   - Label設定: Explicit Assets に `WBP_SmithMenu` を追加(またはRecursive指定)、Chunk ID: 任意の空き番号(例 **5100**)
2. Project Settings → Project → Packaging → 「Generate Chunks」☑
3. **Cook Content**(Project Settingsのcookボタン or Platforms → Windows → Cook Content)
4. 出来た `pakchunk5100-Windows.pak` を取得(PMKの `Windows/Pal/Content/Paks/` 配下に出る)
5. **`PalSmithUI_P.pak` にリネーム**

## Part C: 配置と検証(こちらで用意済み)

1. `PalSmithUI_P.pak` をクライアントの `Pal/Content/Paks/~mods/` に置く(フォルダが無ければ作成)
2. Luaプローブ(`src/client/` → `ue4ss/Mods/PalSmithV4Probe/`)は**配置済み**。動作:
   - **F11** = メニュー開閉。開くとき `LoadAsset` → `WidgetBlueprintLibrary.Create` → `AddToViewport` → `SetTitle("PalSmith V4")`
   - Widgetの `EntryClicked` に `RegisterHook` を張り、ボタンクリックで `[SmithV4] CLICKED id=A/B/C` をログ出力
3. 判定:
   - ✅ メニューが表示され、クリックがログに出る → **C5成立**。④の宣言的UIフレームワーク設計へ
   - 🔶 表示されるがクリックが取れない → BPファンクションのフック可否を調査(代替: ボタンWidgetのOnClickedを直接フック)
   - ❌ LoadAssetで見つからない → pakのマウント/チャンク設定を再確認(ログにSTAGEごとの失敗理由が出る)

## 結果記録

(実施後にここへ)
