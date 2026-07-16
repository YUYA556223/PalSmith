# V5: ランタイム3Dオブジェクト生成(ProceduralMesh・ABI非依存)

**目的**: UE5もpakも使わず、Luaのリフレクション呼び出しだけで
「頂点データ→ワールド上の3Dオブジェクト(コリジョン付き)」が成立するか確認する。
通れば ⑦ランタイム3Dオブジェクト(plan.md)が確定し、
**「モデルファイルを置くだけでワールドに置ける」**への道が開く。

## 背景(2026-07-16 CXXHeaderDump調査)

Palworldは `ProceduralMeshComponent` モジュールを同梱しており、以下がすべて
BlueprintCallable(=UE4SS Luaから呼べる見込み、ABI非依存):

- `AActor::AddComponentByClass` — コンポーネントの実行時追加+登録
- `UProceduralMeshComponent::CreateMeshSection` — 頂点/三角形配列からメッシュ生成(bCreateCollision付き)
- `UKismetRenderingLibrary::ImportFileAsTexture2D` — PNG直読み
- `CreateAndSetMaterialInstanceDynamic` / `SetMaterial` — マテリアル差し替え

## 手順

1. `src/client/` を クライアントの `Pal/Binaries/Win64/ue4ss/Mods/PalSmithV5Probe/` として配置
   (`Scripts/main.lua` + `enabled.txt`)
2. クライアント起動 → ワールドに入る
3. **F9キー**を押す → プレイヤーの周囲に1mの立方体が出現するか
4. `UE4SS.log` の `[SmithV5]` 行で各ステージの成否を確認:
   - STAGE1: ProceduralMeshComponentクラスの取得
   - STAGE2: プレイヤーPawn取得
   - STAGE3: AddComponentByClass(コンポーネント追加)
   - STAGE4: CreateMeshSection(メッシュ生成)
   - STAGE5: 位置設定

## 判定

- ✅ 立方体が見える(+ぶつかれる) → ⑦確定。次は .obj パーサ(Lua)とテクスチャ適用
- 🔶 ログは全ステージOKだが見えない → 三角形の巻き方向/マテリアル/位置の問題(ログを添えて相談)
- ❌ STAGE3/4で失敗 → FTransformやTArray<FVector>のLua渡しの制約。C++ミニモッド
  (UE4SSの安定APIのみ使用)へのフォールバックを検討

## 結果記録

(実施後にここへ)
