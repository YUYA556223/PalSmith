# Runtime Meshes

PalSmith can attach **3D models loaded at runtime** to your placed objects —
no Unreal Engine, no pak files, no cooking. Palworld ships the
`ProceduralMeshComponent` module, and PalSmith drives it purely through
reflection, which keeps the mechanism stable across game updates.

## Declaring a mesh

`palsmith/meshes.jsonc`:

```json
{
  "$schema": "https://raw.githubusercontent.com/YUYA556223/PalSmith/main/schemas/meshes.schema.json",
  "mypack:Statue": {
    "model": "models/statue.obj",
    "scale": 1.0,
    "offset": { "x": 0, "y": 0, "z": 100 }
  }
}
```

The key must be a build object your pack defines (see the example pack's
`buildings/` folder for the placeable-object pattern). When the object is
placed — or encountered after a world load — PalSmith attaches the mesh.

## OBJ requirements

- ASCII Wavefront OBJ, `v` and `f` records (normals/UVs are currently ignored)
- Units are **centimeters** (a 1m cube spans 100 units)
- Faces may have 3+ vertices (fan-triangulated); negative indices supported
- Both windings are rendered, so face orientation doesn't matter

## Current limitations (v0.1)

- **Visual + collision only** — the mesh is not a save-persisted actor. It's
  re-attached automatically on world load / first interaction.
- Flat shading, default material. Texturing via `ImportFileAsTexture2D` +
  dynamic materials is on the roadmap.
- ProceduralMesh skips Nanite/instancing — fine for dozens of decorative
  objects, not thousands.
- Skeletal meshes (new Pal bodies) are out of scope — that path requires
  cooked pak assets.
