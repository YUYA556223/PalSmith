# Behaviors Reference

Behaviors bind **events** on your content to lists of **action entries**. They
are declared in `palsmith/behaviors.jsonc` and dispatched by the PalSmith runtime
through verified game hooks.

## Entry grammar (v0.2)

Each entry is `{ "handler": "ns:name", "args": { ... } }` with optional `when`
and `cooldownSec`:

```json
{
  "mypack:Bench": {
    "onInteract": [
      { "handler": "smith:give_item", "args": { "item": "Stone", "count": 5 },
        "when": { "chance": 0.5 }, "cooldownSec": 30 }
    ]
  }
}
```

Handlers are namespaced — `smith:*` are the builtins below. `when.chance` (0..1)
gates the entry with a dice roll; `cooldownSec` throttles the whole behavior.

> **Migrating from v0.1:** the old flat shape still loads (with a one-time
> deprecation warning) but you should migrate:
>
> | v0.1 (deprecated) | v0.2 |
> |---|---|
> | `{ "action": "give_item", "item": "Wood", "count": 1 }` | `{ "handler": "smith:give_item", "args": { "item": "Wood", "count": 1 } }` |
> | `cooldownSec` inline next to `action` | `cooldownSec` stays at the entry level |

## Events

| Event | Fires when | Target id source |
|---|---|---|
| `onUse` | a player uses an item (consumables etc.) | the item's static id |
| `onPlace` | a player requests placing a build object | the build object id |
| `onInteract` | a character touches/accesses a placed object | the build object id |
| `onTick` / `onCraft` | *reserved* — accepted but not dispatched in v0.2 | — |

Implementation notes (from in-game verification):

- All three dispatch on the **server side** in multiplayer.
- `onInteract` is debounced (1s) and filtered to characters — buildings
  physically touching each other do not trigger it.
- Keys can be your namespaced ids (`mypack:Thing`) or **literal game ids**
  (`Wood`, `BlueSkyDragon`) — yes, you can attach behaviors to vanilla items.

## Builtin handlers (`smith:`)

### smith:announce

```json
{ "handler": "smith:announce", "args": { "text": "Hello {id} via {event}!" } }
```

Shows a system message. Templates: `{id}`, `{event}`, `{pack}`.

### smith:give_item

```json
{ "handler": "smith:give_item", "args": { "item": "Wood", "count": 3 } }
```

Adds items to the player's inventory (server-authoritative verified call).
`item` accepts namespaced or literal ids.

### smith:spawn_pal

```json
{ "handler": "smith:spawn_pal", "args": { "pal": "Kitsunebi", "count": 1, "level": 5 } }
```

Spawns pals near the player. Pal character ids: see
[paldb.cc Mods page](https://paldb.cc/en/Mods).

### smith:spawn_mesh

```json
{ "handler": "smith:spawn_mesh", "args": { "model": "models/thing.obj", "scale": 1.0, "offset": { "z": 150 } } }
```

Attaches a runtime OBJ mesh to the context actor (the touched building, or the
player). See [Runtime Meshes](../meshes/).

## Cooldowns

Any entry may carry `"cooldownSec": N` — the whole behavior (id + event) will
fire at most once per N seconds. v0.2 cooldowns are global (not per-player) and
reset on restart.

## Extending from Lua

PalSmith exposes a small API to other UE4SS Lua mods:

```lua
PalSmith.registerHandler("mymod:my_action", function(args, ctx)
    -- args = the entry's args object from behaviors.jsonc
    -- ctx  = { id, event, pack, packDir, player, actor }
end)
```

Custom handlers become usable from any pack's `behaviors.jsonc` with
`{ "handler": "mymod:my_action", "args": { ... } }`. (`PalSmith.registerAction`
still works as a deprecated alias that registers under `smith:`.)
