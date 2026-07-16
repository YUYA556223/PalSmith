# Development Environment Setup (Palworld Modding Kit)

This guide sets up everything needed to author and cook PalSmith's Unreal assets
(UMG widgets, base blueprint classes) with the
[Palworld Modding Kit (PMK)](https://github.com/localcc/PalworldModdingKit).

You only need this for **asset development** (e.g. the V4 UI widget). Running or
using PalSmith in-game does **not** require any of this.

## TL;DR

```powershell
# In Windows PowerShell:
Set-ExecutionPolicy -Scope Process Bypass
<repo>\tools\setup-pmk.ps1            # 1st run: installs tools, prints TODOs
# ... do the two manual launcher steps below (UE 5.1 + Wwise) ...
<repo>\tools\setup-pmk.ps1            # 2nd run: auto-integrates Wwise into PMK
# then double-click E:\PalworldModdingKit\Pal.uproject
```

The script is **idempotent** — re-run it any time; finished steps are skipped.

## What the script automates

| Step | Tool | How |
|---|---|---|
| 1 | winget check | fails fast with instructions if missing |
| 2 | Git | winget |
| 3 | Visual Studio 2022 Community + "Desktop development with C++" workload + MSVC v14.38 component | winget with `--override` install options |
| 4 | .NET 6 Runtime | winget |
| 5 | Epic Games Launcher | winget (UE itself stays manual, see below) |
| 6 | PMK clone | `git clone` to `E:\PalworldModdingKit` (change with `-PmkDir`) |
| 7 | `BuildConfiguration.xml` forcing VS2022 | written to `Documents\Unreal Engine\UnrealBuildTool\` |
| 8 | Wwise SDK detection | auto-detects under `%ProgramFiles(x86)%\Audiokinetic` |
| 9 | **Wwise manual-integration into PMK** | extract `Unreal.5.0.tar.xz`, copy plugin + SDK `ThirdParty` components, duplicate `vc170`→`vc160`, patch `Wwise.uplugin` EngineVersion to `5.1` |

Two steps stay manual **by design** — both require accepting a vendor EULA with
your own account, which must not be automated.

## Manual step 1: Unreal Engine 5.1 (Epic Games Launcher)

1. Start the **Epic Games Launcher** and sign in (create an Epic account if needed).
2. Left menu **Unreal Engine** → top tab **Library**.
3. Click **[+]** next to *ENGINE VERSIONS*, open the version dropdown on the new
   slot and pick **5.1.x** (any 5.1 works; older versions can be buried at the
   bottom of the list).
4. Click **Install**. Any drive is fine — mind the disk space (tens of GB).

> If you install to a custom path other than `C:\Program Files\Epic Games\UE_5.1x`,
> `D:\Epic Games\UE_5.1x` or `E:\Epic Games\UE_5.1x`, the script's detection will
> keep showing a TODO. That's cosmetic — but tell us / update Step 5 paths in
> `tools/setup-pmk.ps1`.

## Manual step 2: Wwise 2021.1.11 (Audiokinetic Launcher)

Wwise is **required even if you never touch audio** — PMK does not compile
without it.

1. Get the **Audiokinetic Launcher** from
   [audiokinetic.com/download](https://www.audiokinetic.com/download/) and sign in
   (account required).
2. In the launcher's **Wwise** tab, show *All versions* and select **2021.1.11**.
3. In the install options, check:
   - **SDK (C++)**
   - **Microsoft Windows Visual Studio 2022**
4. Also download the **Unreal offline integration files** from the launcher and
   place `Unreal.5.0.tar.xz` into your `Downloads` folder
   (or pass its folder via `-WwiseOfflineDir`).

## Second run: automatic Wwise integration

Re-run the script. Steps 8/9 should now print green `OK` lines:

- Wwise plugin copied into `<PMK>\Plugins\Wwise`
- SDK components (`Win32_vc170`, `x64_vc170`, `include`) copied into
  `Plugins\Wwise\ThirdParty`, with `vc160` duplicates
- `Wwise.uplugin` patched to `"EngineVersion": "5.1"`

## First launch

Double-click `E:\PalworldModdingKit\Pal.uproject`.
The first launch compiles thousands of shaders — expect a long wait. Subsequent
launches are fast.

Next: author the V4 widget — see [`poc/V4-ui/README.md`](../poc/V4-ui/README.md) Part B.

## Troubleshooting

- **`winget` not found** — update "App Installer" from the Microsoft Store.
- **Script prints garbled text / parser errors** — the script is ASCII-only for
  this reason; make sure you're running the current version from the repo.
- **VS was already installed but the C++ workload is missing** — open *Visual
  Studio Installer* → Modify → check *Desktop development with C++* and the
  *MSVC v143 (v14.38-17.8)* individual component.
- **`BuildConfiguration.xml` note** — the script writes to the shell *Documents*
  folder; with OneDrive redirection this lands under
  `%USERPROFILE%\OneDrive\...\Documents`. Unreal Build Tool reads it from there,
  so this is fine.
- **PMK fails to compile complaining about Wwise** — verify
  `Plugins\Wwise\ThirdParty` contains `include`, `x64_vc170` *and* `x64_vc160`,
  and that `Wwise.uplugin` says `"EngineVersion": "5.1"`. Re-running the script
  does not overwrite an existing `Plugins\Wwise` — delete it first to redo the
  integration.
