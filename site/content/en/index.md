# PalSmith

**Add new gameplay to Palworld with just JSON + PNG + (optionally) a little Lua.**

PalSmith is a content framework mod. It runs on top of
[UE4SS](https://github.com/Okaetsu/RE-UE4SS) and
[PalSchema](https://github.com/Okaetsu/PalSchema), and lets you ship *content
packs* that add:

- **New items** with recipes, technology-tree nodes and custom PNG icons — no Unreal Engine, no pak files
- **Placeable objects** that appear in the build menu and function in the world
- **Behaviors** — declarative `onUse` / `onPlace` / `onInteract` handlers that make your content *do things*, server-authoritatively
- **Runtime 3D meshes** — OBJ models attached to your placed objects, loaded at runtime with no cooking

## Why

Most Palworld mods tweak numbers. PalSmith's goal is to make it easy to extend
*what mods can do*: items you can use, objects you can place, things that react.
Every mechanism in PalSmith was first proven in-game as an isolated
concept-proof (see the [GitHub repository](https://github.com/YUYA556223/PalSmith)
`deprecated/poc/` for the receipts).

## How it fits together

```
Palworld (UE5)
└─ UE4SS (Palworld fork)         runtime scripting
   └─ PalSchema (0.5.0+)         JSON -> DataTables, PNG import
      └─ PalSmith                ids, behaviors, runtime meshes
         └─ your content pack    JSON + PNG (+ OBJ)
```

PalSchema owns the *data* (item stats, recipes, build objects). PalSmith adds
the *life*: namespaced IDs, event dispatch, actions, runtime meshes.

## Quick taste

A behavior declaration from the example pack:

```json
{
  "example:Potion": {
    "onUse": [
      { "action": "announce", "text": "The Apprentice Potion fizzes!" },
      { "action": "give_item", "item": "Wood", "count": 1 }
    ]
  }
}
```

Continue with [Installation](./install/) or jump straight to
[Your First Pack](./first-pack/).
