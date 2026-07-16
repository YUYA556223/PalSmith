# V1: 「配置できるアイテム」をUE5なしで追加できるか

**目的**: PalSchema `buildings` + **既存Blueprintの流用**で、新規の配置可能オブジェクトが
JSONだけで成立するかを確認する。これが通れば「持てるだけでなく置ける」がコード不要で手に入る。

## 背景

PalSchemaの公式ガイド(craftingstation.md)は新規BPをUE5で作ってpak化しているが、
`BlueprintClassSoft` は単なるソフト参照なので、**既存ゲーム内建物のBPクラスを指せば
pak不要で「見た目と物理は既存流用の新建物」になるはず**(itemsの
`VisualBlueprintClassSoft` で既存BP流用が成立しているのと同じ理屈)。

## 手順

1. ~~BPクラスパスの特定~~ → **済(2026-07-16)**: 同梱の`src/client`プローブ(F10)で実機から取得。
   建築物のパス規則: `/Game/Pal/Blueprint/MapObject/BuildObject/BP_BuildObject_<名前>.BP_BuildObject_<名前>_C`
2. ~~`smith_test_bench.jsonc` のTODOを埋める~~ → 済(WorkBench流用)
3. `SmithV1Pack/` をPalSchemaのmodsフォルダへ配置して起動
4. 確認: テクノロジーLv2「スミスの試験台」解放 → 建築ホイール(Bメニュー)に出るか →
   設置できるか → 設置物が機能するか(作業台流用なので既存レシピが出るはず)

## 判定

- ✅ 全部通る → 「配置物の追加」はJSONのみで可。Behaviorレイヤーは既存BP流用を第一級サポート
- 🔶 設置はできるが機能しない → 見た目だけの配置物としては使える。機能はBehavior(onTick/onInteract)で補う
- ❌ 建築ホイールに出ない → `Technology`ブロックや他テーブルとの整合を調査。
  最悪、配置物は①基底クラスpak(UE5一回作業)が前提になる

## 結果記録

### 2026-07-16 シングルプレイで検証成功 ✅ — C3(ワールド配置)成立

`BP_BuildObject_WorkBench` 流用の `PalSmith_TestBench` が:

- テクノロジーLv2に自作ノードとして出現 → 解放OK
- **Bメニュー(建築ホイール)に出現** → 木材5で設置OK
- 設置物は作業台として機能(既存レシピ一覧が表示)

**結論**: `buildings` + 既存BPの `BlueprintClassSoft` 参照で、**UE5もpakも不要**の
新規配置物がJSONだけで成立する。建築システムに乗るため配置・セーブ・レプリケーションは
Palworld本体が処理してくれる。

**確定した仕様**:
- 建築物BPのパス規則: `/Game/Pal/Blueprint/MapObject/BuildObject/BP_BuildObject_<名前>.BP_BuildObject_<名前>_C`
  (実機のF10プローブ=`FindAllOf("PalBuildObject")`で収集可能)

**次**: V5(ProceduralMesh)との統合 — onPlaceフックで元メッシュを隠し独自メッシュを被せる
「Bメニューから置ける自作3Dオブジェクト」。+ 専用サーバー構成での検証
