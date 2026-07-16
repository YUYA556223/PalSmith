# V3: onPlace / onInteract フックの検証(C4の残り)

**目的**: 建築物の「配置」と「インタラクト」をLuaでフックし、対象IDが取れることを確認する。
V2(onUse)と合わせて、Behaviorレイヤー(plan.md ⑥)の主要イベントが出揃う。

## 候補(2026-07-16 CXXHeaderDumpから抽出・所属クラス解決済み)

| イベント | 関数 | 所属 | 期待 |
|---|---|---|---|
| onPlace(要求) | `RequestBuild_ToServer(FName BuildObjectId, FVector, FQuat, ...)` | `UPalNetworkPlayerComponent` | ★建築IDと座標が引数に直接入っている |
| onPlace(完了) | `OnCompleteBuild_ServerInternal(UPalMapObjectModel*)` | `UPalPlayerRecordData` | 建築完了時。ModelからID逆引き |
| onInteract | `OnBeginInteractBuilding(AActor*, InteractiveObject)` | `APalBuildObject` | self=建築物actor → クラスで対象特定 |

## 手順

1. プローブは受動型(キー不要)。クライアントの `ue4ss/Mods/PalSmithV3Probe/` に配置済み
2. ゲーム内で:
   - 適当な建築物を置く(スミスの試験台でも可) → `[SmithV3] FIRED` で BuildObjectId が出るか
   - 作業台などにアクセスする → OnBeginInteractBuilding が出るか
3. UE4SS.log の `[SmithV3]` 行を確認

## 判定

- ✅ 3つとも発火しID特定可 → C4完全成立(onUse/onPlace/onInteract)
- 🔶 一部のみ → 発火したものだけでBehavior v1を設計(不足分は別候補を再抽出)

## 結果記録

(実施後にここへ)
