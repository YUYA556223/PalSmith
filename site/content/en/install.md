# Installation

## Prerequisites

| Requirement | Notes |
|---|---|
| Palworld (Steam) | Client, and/or a dedicated server |
| UE4SS (Palworld fork) | The **Palworld-specific** build — the vanilla UE4SS will crash. Match the fork build to your game version |
| PalSchema **0.5.0+** | 0.6.0 recommended; required for `$resource` PNG import. Must match your UE4SS generation (a January UE4SS needs 0.5.x, the July one needs 0.6.0) |

## Install PalSmith

### With the installer script (Windows)

From a clone or release of the repository:

```powershell
.\tools\install.ps1 -GameDir "E:\SteamLibrary\steamapps\common\Palworld" -WithExample
```

The script verifies UE4SS + PalSchema, copies the runtime to
`Pal/Binaries/Win64/ue4ss/Mods/PalSmith/`, and (with `-WithExample`) installs
the example pack.

### Manually

1. Copy `src/PalSmith/` to `<game>/Pal/Binaries/Win64/ue4ss/Mods/PalSmith/`
2. Make sure an empty `enabled.txt` exists in that folder
3. Optionally copy `packs/ExamplePack/` to `.../ue4ss/Mods/PalSchema/mods/`

## Verify

Start the game and check `Pal/Binaries/Win64/ue4ss/UE4SS.log` for:

```
[PalSmith] PalSmith v0.1.0 starting
[PalSmith] pack 'example' v0.1.0 loaded (2 behaviors, 1 meshes) from ExamplePack
[PalSmith] events installed: 4/4 hooks active
[PalSmith] ready
```

With the example pack installed, unlock **Apprentice Bench** / **Apprentice
Potion** at technology level 2, then:

- craft & use the potion → announce message + 1 wood
- place the bench and touch it → stone gift (30s cooldown) and a floating
  crystal appears above it

## Multiplayer

Gameplay data must match on both sides: install PalSmith **and the same packs**
on the dedicated server and on every client. Behaviors execute
server-authoritatively where the underlying game call is.

> **Test worlds recommended.** PalSchema warns that invalid items inside a save
> can make a world fail to load. Always try new packs on a throwaway world first.

## Uninstalling packs safely

**Never remove a pack while a world still contains its content.** Items and
placed objects whose definitions disappear become *invalid* in the save, and
the world may lag heavily or fail to load (verified the hard way).

Safe removal order:

1. In every world that used the pack: destroy its placed objects, discard its
   items from all inventories/chests, then save and exit.
2. Remove the pack folder from `PalSchema/mods/`.

If a world already got into this state, **reinstall the pack** — the world
loads again, and you can then clean up in the right order.
