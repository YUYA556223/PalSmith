# PalSmith

**JSON + PNG +(必要なら少しのLua)だけで、Palworldに新しい遊びを追加する。**

PalSmithはコンテンツ基盤Modです。[UE4SS](https://github.com/Okaetsu/RE-UE4SS)と
[PalSchema](https://github.com/Okaetsu/PalSchema)の上で動作し、
*コンテンツパック*として次のものを追加できます:

- **新アイテム** — レシピ・テクノロジーツリー登録・PNGアイコン込み。Unreal Engine不要、pak不要
- **配置可能オブジェクト** — 建築メニューに並び、ワールドで機能する
- **Behavior** — `onUse` / `onPlace` / `onInteract` を宣言的に書くだけで、コンテンツが*動く*(サーバー権威)
- **ランタイム3Dメッシュ** — OBJモデルを実行時に読み込み、配置物に取り付け。cook不要

## なぜ作ったか

Palworldの既存Modの多くは数値調整です。PalSmithの目標は「Modに*できること*を
拡張する」こと — 使えるアイテム、置けるオブジェクト、反応する仕掛け。
すべての仕組みは、単体のコンセプト実証としてゲーム内で先に検証済みです
([GitHubリポジトリ](https://github.com/YUYA556223/PalSmith)の`deprecated/poc/`に記録があります)。

## 全体像

```
Palworld (UE5)
└─ UE4SS (Palworld fork)         ランタイムスクリプティング
   └─ PalSchema (0.5.0+)         JSON -> DataTable、PNGインポート
      └─ PalSmith                ID解決・Behavior・ランタイムメッシュ
         └─ あなたのコンテンツパック  JSON + PNG (+ OBJ)
```

データ(アイテム定義・レシピ・建築物)はPalSchemaが担当し、PalSmithはそこに
*命*を吹き込みます: 名前空間ID、イベントディスパッチ、アクション、ランタイムメッシュ。

## ひと目でわかる例

サンプルパックのBehavior宣言:

```json
{
  "example:Potion": {
    "onUse": [
      { "action": "announce", "text": "見習いポーションがシュワシュワと弾けた!" },
      { "action": "give_item", "item": "Wood", "count": 1 }
    ]
  }
}
```

[インストール](./install/)へ進むか、[はじめてのパック](./first-pack/)からどうぞ。
