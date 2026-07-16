# ランタイムメッシュ

PalSmithは**実行時に読み込んだ3Dモデル**を配置物に取り付けられます —
Unreal Engine不要、pak不要、cook不要。Palworldは`ProceduralMeshComponent`
モジュールを同梱しており、PalSmithはそれをリフレクション経由だけで駆動する
ため、ゲームアップデートに対して安定です。

## メッシュの宣言

`palsmith/meshes.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/meshes.schema.json",
  "mypack:Statue": {
    "model": "models/statue.obj",
    "scale": 1.0,
    "offset": { "x": 0, "y": 0, "z": 100 }
  }
}
```

キーは自パックが定義する建築物です(配置物の作り方はサンプルパックの
`buildings/`フォルダ参照)。オブジェクトが設置されたとき、または
ワールドロード後に再会したときに、PalSmithがメッシュを取り付けます。

## OBJの要件

- ASCII形式のWavefront OBJ、`v`と`f`レコード(法線/UVは現状無視)
- 単位は**センチメートル**(1mの立方体=100ユニット)
- 4頂点以上の面も可(扇形三角形分割)。負のインデックス対応
- 両面が描画されるので面の向きは気にしなくてOK

## 現在の制限(v0.1)

- **見た目+コリジョンのみ** — メッシュはセーブに永続化されるアクターでは
  ありません。ワールドロード/最初のインタラクト時に自動で再取り付けされます。
- フラットシェーディング・デフォルトマテリアル。`ImportFileAsTexture2D`+
  ダイナミックマテリアルによるテクスチャ対応はロードマップにあります。
- ProceduralMeshはNanite/インスタンシング非対応 — 装飾用途の数十個なら
  問題ありませんが、数千個には向きません。
- スケルタルメッシュ(新規Palの体)は対象外 — そちらはcook済みpakが必要です。
