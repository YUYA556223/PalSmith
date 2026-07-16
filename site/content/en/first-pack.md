# Your First Pack

A pack is a normal PalSchema mod folder with one extra `palsmith/` directory.
This tutorial builds "mypack" — a potion that thanks the player when used.

## 1. Folder layout

Create this under `.../ue4ss/Mods/PalSchema/mods/`:

```
MyPack/
├── metadata.json                 # PalSchema mod metadata
├── items/
│   └── items.jsonc               # item definition (PalSchema)
├── resources/
│   └── images/
│       └── my_potion.png         # 64x64+ icon, any PNG
└── palsmith/
    ├── pack.jsonc                # PalSmith manifest
    └── behaviors.jsonc           # what the item does
```

## 2. The manifest

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

`id` is your namespace. Every id you own is written `mypack:Name` and resolves
to the game row `mypack_Name` — collisions with other packs are impossible by
construction.

## 3. The item (PalSchema side)

`items/items.jsonc` — note the row key is the **resolved** form `mypack_Potion`,
and the icon uses PalSchema's `$resource` PNG import:

```json
{
  "mypack_Potion": {
    "Name": "My Potion",
    "Description": "My first PalSmith item.",
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

> `TypeA: Food` recipes appear at **cooking stations** (campfire), not the
> workbench. Recipes need a tech-tree unlock to become craftable — see the
> example pack's `raw/technology_unlock.jsonc` for the verified pattern, or
> spawn the item with cheats while testing.

## 4. The behavior (PalSmith side)

`palsmith/behaviors.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/behaviors.schema.json",
  "mypack:Potion": {
    "onUse": [
      { "action": "announce", "text": "Thanks for trying PalSmith!" }
    ]
  }
}
```

## 5. Test

1. Install the folder on client (and server if multiplayer)
2. Start the game, check `UE4SS.log` for `pack 'mypack' ... loaded`
3. Get the item (console: `GetItem mypack_Potion 5`) and use it
4. `[PalSmith] onUse -> mypack_Potion` appears in the log and the announce shows

PalSchema hot-reloads the JSON data files while the game runs; the PalSmith
runtime reads `palsmith/` at startup, so restart after changing behaviors.

Next: [Behaviors Reference](../behaviors/) ・ [Runtime Meshes](../meshes/)
