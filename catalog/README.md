# PalSmith Catalog

A community reference of Palworld's data, extracted for modders. Two sources:

## Static (checked in) — from the UE4SS CXXHeaderDump

Class names and key API surfaces, extracted offline from `Pal.hpp`:

- `classes.json` — machine-readable index (map-object models, UI widget classes,
  container classes) + `keyFindings` (the exact accessors PalSmith uses).
- `mapobject_models.txt` — every `UPalMapObject*Model` (the "machine" types:
  storage, product, convert, energy, dispenser, chest, …).
- `ui_widget_classes.txt` — every `UPalUI*` widget class (for native UI reuse).
- `container_classes.txt` — inventory/container/storage classes.

These are class NAMES. The concrete content ids (item ids like `Wood`, build ids
like the chest's) are DataTable **row names**, which live in the game data, not
the header — dump those in-game (below).

## Runtime (checked in + regenerable) — DataTable row dump

`datatables/` here is a full dump of **390 game DataTables** (~2.4 MB), generated
by PalSmith's catalog dumper. Each file is `{ table, count, rows[] }` — the row
names are the concrete ids modders need. Highlights (`index.json` → `friendly`):

| what | table | rows |
|---|---|---|
| items (static ids, e.g. `Wood`) | `DT_ItemDataTable` | 2468 |
| build objects (e.g. `ItemChest`) | `DT_BuildObjectDataTable` | 501 |
| pals | `DT_PalMonsterParameter` | 753 |
| tech unlocks | `DT_TechnologyRecipeUnlock` | 593 |

Also inside: recipes (`DT_ItemRecipeDataTable`), icons (`DT_ItemIconDataTable`,
`DT_BuildObjectIconDataTable`), localized names/descriptions (`DT_ItemNameText`,
`DT_UI_Common_Text`), and 380+ more.

**Regenerate** (any game version): the dumper runs **automatically ~15s after a
world is ready** (no keypress), or call `PalSmith.dumpCatalog()`. It enumerates
every loaded `UDataTable` (row names via `UDataTable:GetRowNames()`, with a
`UDataTableFunctionLibrary:GetDataTableRowNames` fallback) and writes to
`<Mods>/PalSmith/catalog/`. Copy `datatables/` + `index.json` here to refresh
the checked-in snapshot.

## Why PalSmith catalogs

A thriving mod community needs a shared, discoverable map of what exists — item
ids, build ids, pal ids, UI widgets, machine types. PalSmith makes that a
first-class, regenerable artifact so pack authors don't reverse-engineer ids by
hand, and so tooling (editor autocomplete, validators) can build on it.
