# Pack Format

## Layout

A pack is a PalSchema mod folder plus a `palsmith/` directory:

```
MyPack/
├── metadata.json           # PalSchema metadata (name/authors/version)
├── items/ buildings/ raw/ translations/ resources/ ...   # PalSchema data
└── palsmith/
    ├── pack.jsonc          # manifest (required)
    ├── behaviors.jsonc     # optional
    ├── meshes.jsonc        # optional
    └── models/*.obj        # optional
```

Install location: `.../ue4ss/Mods/PalSchema/mods/MyPack/`.

## ID resolution

| You write | Resolves to | Meaning |
|---|---|---|
| `mypack:Potion` | `mypack_Potion` | your content (PalSchema row key) |
| `Wood` | `Wood` | literal vanilla id |

Rules:

- A pack may only declare behaviors/meshes for its **own** namespace or for
  literal ids. Declaring `otherpack:x` is rejected at load.
- Pack ids and names are `[A-Za-z0-9_]+`.
- Duplicate pack ids: the second pack is skipped with an error (fail-soft).

## pack.jsonc

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/pack.schema.json",
  "id": "mypack",
  "name": "My Pack",
  "version": "1.0.0",
  "requiresSmith": "0.1",
  "authors": ["you"],
  "homepage": "https://github.com/you/mypack"
}
```

## Editor validation

All three JSONC files declare `$schema` URLs served from this repository, so
VS Code (and any JSON-schema-aware editor) gives autocompletion and validation
out of the box:

- `schemas/pack.schema.json`
- `schemas/behaviors.schema.json`
- `schemas/meshes.schema.json`

## Distributing packs

A pack is just a folder — distribute it however you like:

- **GitHub**: keep the pack folder as a repository root; users clone or download
  a release zip into `PalSchema/mods/`. Set `homepage` in `pack.jsonc`.
  The [ExamplePack](https://github.com/YUYA556223/PalSmith/tree/main/packs/ExamplePack)
  doubles as a template — copy it and rename.
- **Nexus Mods**: zip the folder with `MyPack/` as the root and mark PalSmith
  (plus UE4SS + PalSchema) as requirements.

Multiplayer reminder: server and all clients need the same packs installed.
