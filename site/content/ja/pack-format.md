# パック形式

## 構成

パックは「PalSchema Modフォルダ+`palsmith/`ディレクトリ」です:

```
MyPack/
├── metadata.json           # PalSchemaメタデータ(name/authors/version)
├── items/ buildings/ raw/ translations/ resources/ ...   # PalSchemaデータ
└── palsmith/
    ├── pack.jsonc          # マニフェスト(必須)
    ├── behaviors.jsonc     # 任意
    ├── meshes.jsonc        # 任意
    └── models/*.obj        # 任意
```

配置先: `.../ue4ss/Mods/PalSchema/mods/MyPack/`

## ID解決

| 記述 | 解決後 | 意味 |
|---|---|---|
| `mypack:Potion` | `mypack_Potion` | 自パックのコンテンツ(PalSchemaの行キー) |
| `Wood` | `Wood` | バニラの素のID |

ルール:

- パックがBehavior/メッシュを宣言できるのは**自分の名前空間**と素のIDのみ。
  `otherpack:x`の宣言はロード時に拒否されます。
- パックIDと名前は`[A-Za-z0-9_]+`。
- パックIDの重複: 後から来たパックはエラー付きでスキップ(フェイルソフト)。

## pack.jsonc

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/pack.schema.json",
  "formatVersion": 2,
  "id": "mypack",
  "name": "My Pack",
  "version": "1.0.0",
  "requiresSmith": ">=0.2",
  "depends":    { "somelib": "^1.0.0" },
  "recommends": { "prettyhud": ">=0.3" },
  "conflicts":  { "oldpack": "<1.0.0" },
  "breaks":     { "brokenpack": "*" },
  "authors": ["you"],
  "homepage": "https://github.com/you/mypack"
}
```

## 依存関係とロード順

PalSmithは起動時に依存を解決します(Fabric式)。各フィールドは `packId -> semver範囲` のマップ:

| フィールド | 意味 | 未充足時 |
|---|---|---|
| `depends` | 必須 | パックが**非アクティブ** |
| `recommends` | 推奨 | 警告のみ |
| `conflicts` | 軟衝突(該当版が存在) | 警告のみ |
| `breaks` | 硬衝突 | パックが**非アクティブ** |

`requiresSmith`はPalSmith本体バージョンへの範囲(素の`"0.1"`は`">=0.1.0"`)。
範囲は `>= <= > < = ^ ~`、`x`/`*` ワイルドカード、`||` に対応。パックは
**トポロジカル順**で読み込まれ、循環は検出・報告されます。

**非アクティブ≠削除。** PalSchemaはPalSmithより先に行を適用するため、依存未充足でも
アイテム自体は消えず、PalSmithがそのパックの**Behavior登録をスキップ**するだけです。
Mod Managerは2軸(**Data**=ディスク上の有効/無効、**Behaviors**=アクティブ/非アクティブ)を
表示します。データを本当に消すにはMod Managerで無効化(フォルダ移動)して再起動します。

## エディタでの検証

3つのJSONCファイルはこのリポジトリから配信される`$schema` URLを宣言している
ので、VS Code等のJSON Schema対応エディタなら補完と検証がそのまま効きます:

- `schemas/pack.schema.json`
- `schemas/behaviors.schema.json`
- `schemas/meshes.schema.json`

## パックの配布

パックはただのフォルダなので、配布方法は自由です:

- **GitHub**: パックフォルダをリポジトリのルートにして公開。利用者はcloneか
  リリースzipを`PalSchema/mods/`に展開。`pack.jsonc`の`homepage`にリポジトリを
  設定しましょう。[ExamplePack](https://github.com/YUYA556223/PalSmith/tree/main/packs/ExamplePack)
  はテンプレートを兼ねています — コピーしてリネームすれば雛形になります。
- **Nexus Mods**: `MyPack/`をルートにしたzipで公開し、PalSmith(+UE4SS+PalSchema)を
  Requirementsに指定。

マルチプレイの注意: サーバーと全クライアントに同じパックが必要です。
