# V6: Lua-native UMG(エディタ不要のUI)

**目的**: cook済みWidgetBlueprintを使わず、**Luaから実行時にUMGウィジェットを構築して画面表示**できるかを検証する。
成立すれば PalSmith のUIは永久にUE5/PMK/cook不要になり、Mod Manager もLuaだけで実装できる。

## 背景(2026-07-17 判明)

- **エディタPython authoringは不可**: UE5.1では `WidgetBlueprint.WidgetTree` が protected で読めず、
  `unreal.WidgetTree` 型も露出していない(introspectで確定)
- **一方で UMGクラスは全て存在**: UserWidget / CanvasPanel / VerticalBox / TextBlock / Border は
  `unreal.*` にあり、UE4SS のリフレクション(protected も触れる)なら実行時構築が狙える
- V5(ProceduralMesh)と同じ「StaticFindObjectでクラス取得 → 実行時construct」パターンをUIに適用

## 手順

1. `src/client/` を `ue4ss/Mods/PalSmithV6Probe/` として配置(済)
2. ゲーム内(ワールドに入った状態)で **F7** を押す
3. `UE4SS.log` の `[SmithV6]` 行で各ステージの成否を確認:
   - STAGE1: UserWidgetクラス+PlayerController取得
   - STAGE2: UUserWidget構築(StaticConstructObject)
   - STAGE3: WidgetTree取得 + ルート(VerticalBox)構築 + RootWidgetセット
   - STAGE4: TextBlock子を追加
   - STAGE5: AddToViewport → 画面にテキストが出るか

## 判定

- ✅ 画面に "PalSmith UI test" が出る → Lua-native UI成立。Mod Managerへ
- 🔶 ログ全OKだが見えない → viewport追加/slot/初期化の調整(ログ添えて相談)
- ❌ STAGE2/3で失敗 → UE4SSでのUUserWidget構築は不可。cook済みWidget方式(V4、環境構築済み)へフォールバック

## 結果記録

### 2026-07-17 検証成功 ✅ — Lua-native UI 成立、UE5完全不要

全STAGE通過、画面に "PalSmith UI test / Row A / Row B" 表示:

```
STAGE1 player controller           OK
STAGE2 construct UUserWidget       OK
STAGE3 construct + assign WidgetTree OK
STAGE4 root VerticalBox + children OK
STAGE5 AddToViewport               OK
```

**確定した手順(UE4SS Lua、cook不要)**:

1. `pc = FindFirstOf("PalPlayerController")`
2. `w = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), pc)` — 素のUserWidget
3. **`w.WidgetTree` はnull** → `tree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), w)`;
   `w.WidgetTree = tree`(★これが肝。素のUUserWidgetはWidgetTreeを持たない)
4. `vbox = construct("/Script/UMG.VerticalBox", tree)`; `tree.RootWidget = vbox`
5. `tb = construct("/Script/UMG.TextBlock", tree)`; `tb:SetText(FText(...))`; `vbox:AddChildToVerticalBox(tb)`
6. `w:AddToViewport(1000)`

キー: **F7は音量キーと干渉して不発。F9は実績あり**。複数キーをバインドすると安全。

**意義**: PalSmithのUIは永久にUE5/PMK/cook不要。エディタ環境(V4)は不要になった
(残すが非常用フォールバック)。次はこの手順を `palsmith/ui.lua` に一般化してMod Managerを実装。
