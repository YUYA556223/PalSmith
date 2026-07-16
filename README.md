# PalSmith

**Add new gameplay to Palworld with just JSON + PNG + a little Lua.**

PalSmith is a content framework mod for Palworld: new items, recipes, technology-tree
nodes, placeable objects, custom behaviors, runtime 3D objects and UI — all without
touching Unreal Engine.

It runs as a companion to [PalSchema](https://github.com/Okaetsu/PalSchema): data
definitions are delegated to PalSchema, while PalSmith provides **behaviors, UI,
actions/events, and the content-pack ecosystem** on top.

- Status: **v0.1 runtime** — all core concepts proven in-game, UI layer in progress
- Documentation: **[GitHub Pages site](https://yuya556223.github.io/PalSmith/)** (EN/JA)
- Design doc: [docs/plan.md](docs/plan.md) (Japanese — working document)
- Planned distribution: Nexus Mods (Vortex support) / manual install

## Quick start

```powershell
# Requires: Palworld + UE4SS (Palworld fork) + PalSchema 0.5.0+
.\tools\install.ps1 -GameDir "E:\SteamLibrary\steamapps\common\Palworld" -WithExample
```

Then check `ue4ss\UE4SS.log` for `[PalSmith] ready`. Full instructions on the
[docs site](https://yuya556223.github.io/PalSmith/en/install/).

## Creating content packs

A pack is a PalSchema mod folder plus a `palsmith/` directory with namespaced
ids (`mypack:Thing`), declarative behaviors and optional runtime OBJ meshes:

```json
{
  "mypack:Bench": {
    "onInteract": [
      { "action": "give_item", "item": "Stone", "count": 5, "cooldownSec": 30 }
    ]
  }
}
```

Start from [`packs/ExamplePack`](packs/ExamplePack) (it doubles as a template)
and the [Your First Pack](https://yuya556223.github.io/PalSmith/en/first-pack/)
tutorial. JSON Schemas in [`schemas/`](schemas/) give editor autocompletion.

## Concept-proof scoreboard

| Concept | Status |
|---|---|
| C1 Add items (recipes + tech tree) | ✅ verified in-game |
| C2 Add resources (PNG icons, no pak) | ✅ verified in-game |
| C3 Place objects in the world (build menu) | ✅ verified in-game |
| C4 Custom behaviors (onUse / onPlace / onInteract hooks with IDs) | ✅ verified in-game |
| C5 Custom UI (cooked UMG + Lua data-driving) | 🔜 in progress |
| Bonus: runtime 3D meshes (no pak, ABI-independent) | ✅ verified in-game |

## Design principle

**Extend what mods *can do*, not just tweak numbers.** Items should be usable,
placeable, and alive — not just holdable. The Behavior layer (declarative
`onUse` / `onPlace` / `onInteract` / `onTick` handlers, server-authoritative)
is the core of the framework.

## Repository layout

```
src/PalSmith/      - the runtime (UE4SS Lua mod): ids, registry, events, actions, meshes
packs/ExamplePack/ - example content pack (also the template for new packs)
schemas/           - JSON Schemas for pack.jsonc / behaviors.jsonc / meshes.jsonc
site/              - documentation site (Next.js + Markdoc, EN/JA, GitHub Pages)
docs/plan.md       - design document (layers, cross-cutting infra, verification matrix)
docs/pmk-setup.md  - dev environment setup guide (UE5 modkit, English)
tools/             - install.ps1 (game install), setup-pmk.ps1 (dev env)
deprecated/poc/    - concept-proof probes and packs that seeded the runtime
```

## Dependency stack

```
Palworld (UE5)
└─ UE4SS (Palworld-specific fork)
   └─ PalSchema (v0.5.0+ ... $resource image import required)
      └─ PalSmith  <- this repository
         └─ content packs (JSON + PNG)
```

## License / Credits

TBD. Built on the work of PalSchema (Okaetsu) and the UE4SS team.
