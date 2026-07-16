# V1: 「配置できるアイテム」をUE5なしで追加できるか

**目的**: PalSchema `buildings` + **既存Blueprintの流用**で、新規の配置可能オブジェクトが
JSONだけで成立するかを確認する。これが通れば「持てるだけでなく置ける」がコード不要で手に入る。

## 背景

PalSchemaの公式ガイド(craftingstation.md)は新規BPをUE5で作ってpak化しているが、
`BlueprintClassSoft` は単なるソフト参照なので、**既存ゲーム内建物のBPクラスを指せば
pak不要で「見た目と物理は既存流用の新建物」になるはず**(itemsの
`VisualBlueprintClassSoft` で既存BP流用が成立しているのと同じ理屈)。

## 手順

1. FModelでPalworldの `Pal.pak` を開き、既存建物のBPクラスパスを1つ特定する
   - 例: 作業台系 `DT_BuildObjectDataTable` の既存行(`WorkBench` 等)の
     `BlueprintClassSoft` / `BlueprintClassName` の値をそのまま書き写すのが確実
   - CXXHeaderDump(zDev UE4SS)でも可
2. `SmithV1Pack/buildings/smith_test_bench.jsonc` のTODOを埋める
3. PoC-Aと同様にサーバー+クライアントへ配置して起動
4. 確認: 建築ホイールに出るか → 設置できるか → 設置物が機能するか(作業台なら既存レシピが出るか)

## 判定

- ✅ 全部通る → 「配置物の追加」はJSONのみで可。Behaviorレイヤーは既存BP流用を第一級サポート
- 🔶 設置はできるが機能しない → 見た目だけの配置物としては使える。機能はBehavior(onTick/onInteract)で補う
- ❌ 建築ホイールに出ない → `Technology`ブロックや他テーブルとの整合を調査。
  最悪、配置物は①基底クラスpak(UE5一回作業)が前提になる

## 結果記録

(実施後にここへ)
