# PalSmith

**「JSON + PNG + 少しのLua」だけで、Palworldに“新しい遊び”を追加できるようにするコンテンツ基盤Mod。**
A content framework mod for Palworld: add new items, recipes, tech-tree nodes, placeable objects,
custom behaviors and UI — without touching Unreal Engine.

[PalSchema](https://github.com/Okaetsu/PalSchema) のコンパニオンとして動作し、データ定義はPalSchemaに委譲、
PalSmithは**挙動(Behavior)・UI・アクション/イベント・配布エコシステム**を担当する。

- ステータス: **設計+前提検証フェーズ**(2026-07 開始)
- 設計書: [docs/plan.md](docs/plan.md)
- 配布予定: Nexus Mods (Vortex対応) / 手動インストール

## 設計原則

**数値調整Modではなく、「できること」を拡張するModを作れる基盤にする。**
アイテムは「持てる」だけでなく「使える・配置できる・動く」ところまでが目標。
そのために、追加したゲームオブジェクトに独自の挙動(使用時・配置時・インタラクト時・定期処理)を
紐付けられる Behavior レイヤーを中核に据える。

## リポジトリ構成

```
docs/plan.md   — 設計書(レイヤー構成・横断基盤・検証マトリクス・ロードマップ)
poc/           — 前提検証用PoC群(それぞれのREADME参照)
src/           — PalSmithランタイム本体(検証完了後に着手)
```

## 依存スタック

```
Palworld (UE5)
└─ UE4SS (Palworld専用fork)
   └─ PalSchema (v0.5.0+ … $resource画像インポート必須)
      └─ PalSmith ← このリポジトリ
         └─ 各コンテンツパック (JSON + PNG)
```

## License / Credits

TBD。PalSchema (Okaetsu) と UE4SS チームの成果の上に成り立っています。
