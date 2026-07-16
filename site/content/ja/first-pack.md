# はじめてのパック

パックは「通常のPalSchema Modフォルダ+`palsmith/`ディレクトリ」です。
このチュートリアルでは、使うとお礼を言ってくれるポーションの"mypack"を作ります。

## 1. フォルダ構成

`.../ue4ss/Mods/PalSchema/mods/` の下に:

```
MyPack/
├── metadata.json                 # PalSchemaのMod情報
├── items/
│   └── items.jsonc               # アイテム定義(PalSchema側)
├── resources/
│   └── images/
│       └── my_potion.png         # 64x64以上のPNGアイコン
└── palsmith/
    ├── pack.jsonc                # PalSmithマニフェスト
    └── behaviors.jsonc           # アイテムの挙動
```

## 2. マニフェスト

`palsmith/pack.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/pack.schema.json",
  "id": "mypack",
  "name": "My First Pack",
  "version": "0.1.0",
  "requiresSmith": "0.1"
}
```

`id`があなたの名前空間です。IDは`mypack:Name`と書き、ゲーム内の行名
`mypack_Name`に解決されます — 他パックとの衝突は構造的に起きません。

## 3. アイテム(PalSchema側)

`items/items.jsonc` — 行キーは**解決後**の`mypack_Potion`で書きます。
アイコンはPalSchemaの`$resource`によるPNG直読み:

```json
{
  "mypack_Potion": {
    "Name": "My Potion",
    "Description": "はじめてのPalSmithアイテム。",
    "Type": "Consumable",
    "IconTexture": "$resource/MyPack/my_potion",
    "TypeA": "Food",
    "TypeB": "FoodDishVegetable",
    "Rank": 1, "Rarity": 2, "Price": 100,
    "MaxStackCount": 99, "SortID": 999020, "Weight": 0.5,
    "VisualBlueprintClassSoft": "/Game/Pal/Blueprint/Item/VisualModel/BP_Item_BerryRed.BP_Item_BerryRed_C",
    "RestoreSatiety": 20, "RestoreHP": 100, "CorruptionFactor": 0.0,
    "Recipe": { "Product_Count": 1, "WorkAmount": 10.0, "Material1_Count": 3, "Material1_Id": "Wood" }
  }
}
```

> `TypeA: Food`のレシピは作業台ではなく**調理設備**(キャンプファイア等)に
> 並びます。クラフト可能にするにはテクノロジーツリーの解放が必要です —
> 検証済みの書き方はサンプルパックの`raw/technology_unlock.jsonc`を参照。
> テスト中はチートコンソールでの入手でも可。

## 4. Behavior(PalSmith側)

`palsmith/behaviors.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/behaviors.schema.json",
  "mypack:Potion": {
    "onUse": [
      { "action": "announce", "text": "PalSmithを試してくれてありがとう!" }
    ]
  }
}
```

## 5. テスト

1. クライアント(マルチならサーバーにも)にフォルダを配置
2. 起動して`UE4SS.log`に`pack 'mypack' ... loaded`が出るか確認
3. アイテムを入手(コンソール: `GetItem mypack_Potion 5`)して使用
4. ログに`[PalSmith] onUse -> mypack_Potion`、画面にアナウンスが出れば成功

PalSchemaのデータJSONはゲーム起動中も自動リロードされます。PalSmithの
`palsmith/`は起動時読み込みなので、Behaviorを変えたら再起動してください。

次: [Behaviorリファレンス](../behaviors/) ・ [ランタイムメッシュ](../meshes/)
