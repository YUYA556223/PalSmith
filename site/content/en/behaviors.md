# Behaviors Reference

Behaviors bind **events** on your content to lists of **actions**. They are
declared in `palsmith/behaviors.jsonc` and dispatched by the PalSmith runtime
through verified game hooks.

## Events

| Event | Fires when | Target id source |
|---|---|---|
| `onUse` | a player uses an item (consumables etc.) | the item's static id |
| `onPlace` | a player requests placing a build object | the build object id |
| `onInteract` | a character touches/accesses a placed object | the build object id |

Implementation notes (from in-game verification):

- All three dispatch on the **server side** in multiplayer.
- `onInteract` is debounced (1s) and filtered to characters — buildings
  physically touching each other do not trigger it.
- Keys can be your namespaced ids (`mypack:Thing`) or **literal game ids**
  (`Wood`, `BlueSkyDragon`) — yes, you can attach behaviors to vanilla items.

## Actions

### announce

```json
{ "action": "announce", "text": "Hello {id} via {event}!" }
```

Shows a system message. Templates: `{id}`, `{event}`, `{pack}`.

### give_item

```json
{ "action": "give_item", "item": "Wood", "count": 3 }
```

Adds items to the player's inventory (server-authoritative verified call).
`item` accepts namespaced or literal ids.

### spawn_pal

```json
{ "action": "spawn_pal", "pal": "Kitsunebi", "count": 1, "level": 5 }
```

Spawns pals near the player. Pal character ids: see
[paldb.cc Mods page](https://paldb.cc/en/Mods).

### spawn_mesh

```json
{ "action": "spawn_mesh", "model": "models/thing.obj", "scale": 1.0, "offset": { "z": 150 } }
```

Attaches a runtime OBJ mesh to the context actor (the touched building, or the
player). See [Runtime Meshes](../meshes/).

## Cooldowns

Any action may carry `"cooldownSec": N` — the whole behavior (id + event) will
fire at most once per N seconds. v0.1 cooldowns are global (not per-player) and
reset on restart.

## Extending from Lua

PalSmith exposes a small API to other UE4SS Lua mods:

```lua
PalSmith.registerAction("my_action", function(a, ctx)
    -- a   = the action object from behaviors.jsonc
    -- ctx = { id, event, pack, packDir, player, actor }
end)
```

Custom actions become usable from any pack's `behaviors.jsonc` with
`{ "action": "my_action", ... }`.
