# PalSmith

**Add new gameplay to Palworld with just JSON + PNG + a little Lua.**

PalSmith is a content framework mod for Palworld: new items, recipes, technology-tree
nodes, placeable objects, custom behaviors, runtime 3D objects and UI — all without
touching Unreal Engine.

It runs as a companion to [PalSchema](https://github.com/Okaetsu/PalSchema): data
definitions are delegated to PalSchema, while PalSmith provides **behaviors, UI,
actions/events, and the content-pack ecosystem** on top.

- Status: **design + concept-proof phase** (started 2026-07)
- Design doc: [docs/plan.md](docs/plan.md) (Japanese — working document)
- Planned distribution: Nexus Mods (Vortex support) / manual install

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
docs/plan.md       - design document (layers, cross-cutting infra, verification matrix)
docs/pmk-setup.md  - dev environment setup guide (UE5 modkit, English)
poc/               - concept-proof probes and test packs (see each README)
src/               - PalSmith runtime (starts after the verification phase)
tools/             - setup automation (setup-pmk.ps1)
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
