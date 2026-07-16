# PoC-A: PalSchemaのみで「新アイテム+レシピ+PNGアイコン+ツリー解放」

**目的**: データ層をPalSchemaに全委譲できることを実機で確認する。コード不要。

## 検証項目

1. `items` フォルダの行追加だけで新アイテム `PalSmith_TestPotion` がゲームに存在するか
2. インライン `Recipe` でクラフトできるか
3. `$resource/PalSmithPoC/smith_potion` のPNGアイコンが表示されるか(**専用サーバー+クライアント構成で**)
4. `raw` の `DT_TechnologyRecipeUnlock` 行追加でテクノロジーツリーにノードが出るか
   (アイテムレシピ解放用の**列名が未確定** → ログの `Property 'X' not found` 警告で特定する)

## 手順

1. `PalSmithPoC/` フォルダを**サーバーとクライアント両方**の
   `Pal/Binaries/Win64/ue4ss/Mods/PalSchema/mods/` にコピー
   - サーバー: `palserver/PalServer/Pal/Binaries/Win64/ue4ss/Mods/PalSchema/mods/`
   - クライアント: Steamの `Palworld/Pal/Binaries/Win64/ue4ss/Mods/PalSchema/mods/`
   - ※PalSchema 0.5.0以上が必要($resource機能)。ModManagerのframeworksが古い場合は更新
2. サーバー起動 → UE4SSログ(`Win64/UE4SS.log` とPalSchemaのログ出力)で
   ロード成功/警告を確認
3. クライアントで接続して確認:
   - インベントリに付与して存在確認(AdminCommandsで `!give PalSmith_TestPotion 1` 相当、
     または CheatManager `cm:GetItem(FName("PalSmith_TestPotion"), 1)`)
   - アイコンがポーション画像(オレンジのフラスコ)で出るか ← $resource検証
   - テクノロジータブにレベル2・コスト1の「試作ポーション」ノードが出るか
   - 解放して作業台でクラフト(木材3)できるか
   - 使用してHP回復するか

## フォールバック/切り分け

| 症状 | 意味 | 次の一手 |
|---|---|---|
| アイテム自体が存在しない | items行追加が失敗 | ログの列名警告を確認、ExampleModと差分比較 |
| アイテムはあるがアイコンが白/デフォルト | $resourceがこの構成で無効 | クライアント側ログ確認。最悪アイコンはcookパスで代替 |
| ツリーにノードが出ない | rawの列名違い or 別テーブルも必要 | 警告ログ→FModel/CXXHeaderDumpで `FTechnologyRecipeUnlock` 構造体を確認 |
| ノードは出るがレシピが解放されない | アイテム用解放列が別(建物はUnlockBuildObjects) | 同上。`UnlockItemRecipes`/`UnlockRecipes` 等の候補を試す |
| クラフトはできるが使用しても無反応 | RestoreHP系の列が効いていない | 既存Consumable(Berries等)の行をFModelで見て列を合わせる |

## 結果記録

### 2026-07-16 クライアント(シングル新規ワールド)で検証成功 ✅

環境: クライアント UE4SS 7月版(v3.0.1-1012系) + PalSchema **0.6.0** / 他Modなしのクリーン構成

| 項目 | 結果 |
|---|---|
| アイテム追加 | ✅ ログ `Added Item 'PalSmith_TestPotion'` |
| レシピ追加 | ✅ ログ `Added new Recipe for Item 'PalSmith_TestPotion'` |
| PNGアイコン($resource) | ✅ `Registered Image Resource` → ゲーム内でフラスコ画像表示 |
| ツリーノード出現(Lv2) | ✅ 日本語名「試作ポーション」で表示・解放OK |
| raw行追加 | ✅ `DT_TechnologyRecipeUnlock_Common: 1 rows added, 0 errors` |
| クラフト | ✅ **ただし作業台ではなく調理設備(キャンプファイア)に並ぶ**(下記) |
| 使用 | ✅ |

**特定した仕様**:

- 実テーブル名は `DT_TechnologyRecipeUnlock_Common`(JSONには `DT_TechnologyRecipeUnlock` と
  書いてもPalSchemaが名前解決した)
- `UnlockItemRecipes` 列名は**正解**(CXXHeaderDump `FPalTechnologyRecipeUnlockDataTableRow` で確認:
  `UnlockBuildObjects` / `UnlockItemRecipes` + 基底に Name/Description/IconName/
  RequireDefeatTowerBoss/RequireTechnology/RequireResearchId/IsBossTechnology/LevelCap/**Tier**/Cost)
- **レシピが並ぶ設備はアイテムの `TypeA`/`TypeB` で決まる**: `Food` → 調理設備。
  作業台に出したければ工作系Typeにする
- **UE4SSとPalSchemaのバージョンペアが重要**: 7月版UE4SS + PalSchema 0.5.2 は
  `0x7f (procedure not found)` でロード失敗 → 0.6.0が必要。1月版UE4SSには0.5.2
- PalSchema 0.6.0は本ゲームビルドとシグネチャ1件不一致
  (`UPalItemSlot::UpdateItem_ServerInternal`)→ 不正アイテムがセーブに入るとワールドが
  ロード不能になり得る警告。**検証は使い捨てワールドで行うこと**

**残タスク**: セーブ→再ロードの健全性確認 / 専用サーバー+クライアント(マルチ)構成での同検証
