# Behaviorリファレンス

Behaviorはコンテンツの**イベント**に**アクション**のリストを結び付けます。
`palsmith/behaviors.jsonc`で宣言し、PalSmithランタイムが検証済みの
ゲームフックを通じてディスパッチします。

## イベント

| イベント | 発火タイミング | 対象IDの由来 |
|---|---|---|
| `onUse` | プレイヤーがアイテムを使用(消耗品等) | アイテムの静的ID |
| `onPlace` | プレイヤーが建築物の設置を要求 | 建築物ID |
| `onInteract` | キャラクターが設置物にアクセス | 建築物ID |

実装ノート(実機検証に基づく):

- 3イベントともマルチプレイでは**サーバー側**でディスパッチされます。
- `onInteract`はデバウンス(1秒)+キャラクターフィルタ済み —
  建物同士が接触しても発火しません。
- キーには名前空間ID(`mypack:Thing`)のほか**バニラの素のID**
  (`Wood`、`BlueSkyDragon`)も使えます — 既存アイテムにBehaviorを付けることも可能。

## アクション

### announce

```json
{ "action": "announce", "text": "Hello {id} via {event}!" }
```

システムメッセージを表示。テンプレート: `{id}`、`{event}`、`{pack}`。

### give_item

```json
{ "action": "give_item", "item": "Wood", "count": 3 }
```

プレイヤーのインベントリにアイテムを付与(サーバー権威の検証済みコール)。
`item`は名前空間IDでも素のIDでも可。

### spawn_pal

```json
{ "action": "spawn_pal", "pal": "Kitsunebi", "count": 1, "level": 5 }
```

プレイヤーの近くにパルを召喚。キャラクターIDは
[paldb.ccのModsページ](https://paldb.cc/en/Mods)参照。

### spawn_mesh

```json
{ "action": "spawn_mesh", "model": "models/thing.obj", "scale": 1.0, "offset": { "z": 150 } }
```

ランタイムOBJメッシュをコンテキストのアクター(触られた建築物、または
プレイヤー)に取り付け。[ランタイムメッシュ](../meshes/)参照。

## クールダウン

どのアクションにも`"cooldownSec": N`を付けられます — そのBehavior
(ID+イベント)はN秒に1回しか発火しません。v0.1のクールダウンは
グローバル(プレイヤー別ではない)で、再起動でリセットされます。

## Luaからの拡張

PalSmithは他のUE4SS Lua Modに小さなAPIを公開しています:

```lua
PalSmith.registerAction("my_action", function(a, ctx)
    -- a   = behaviors.jsonc のアクションオブジェクト
    -- ctx = { id, event, pack, packDir, player, actor }
end)
```

登録したアクションは、どのパックの`behaviors.jsonc`からでも
`{ "action": "my_action", ... }`で使えるようになります。
