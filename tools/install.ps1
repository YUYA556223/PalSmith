# PalSmith installer - copies the runtime (and optionally the example pack)
# into a Palworld installation that already has UE4SS + PalSchema.
#
# Usage:
#   .\install.ps1 -GameDir "E:\SteamLibrary\steamapps\common\Palworld" [-WithExample]
#   .\install.ps1 -GameDir "E:\steam_hosts\pal\palserver"              # dedicated server

param(
    [Parameter(Mandatory = $true)]
    [string]$GameDir,
    [switch]$WithExample
)

$ErrorActionPreference = "Stop"

# Works from both layouts:
#   repo:        <repo>/tools/install.ps1  with src/PalSmith + packs/ExamplePack
#   release zip: install.ps1 next to PalSmith/ + ExamplePack/
$here = $PSScriptRoot
if (Test-Path (Join-Path $here "PalSmith")) {
    $runtimeSrc = Join-Path $here "PalSmith"
    $exampleSrc = Join-Path $here "ExamplePack"
} else {
    $repo = Split-Path -Parent $here
    $runtimeSrc = Join-Path $repo "src\PalSmith"
    $exampleSrc = Join-Path $repo "packs\ExamplePack"
}

# Locate the Win64 binaries dir (client and server layouts differ one level).
$win64 = @(
    (Join-Path $GameDir "Pal\Binaries\Win64"),
    (Join-Path $GameDir "PalServer\Pal\Binaries\Win64")
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $win64) { throw "Could not find Pal\Binaries\Win64 under $GameDir" }

$modsDir = Join-Path $win64 "ue4ss\Mods"
if (-not (Test-Path $modsDir)) { throw "UE4SS not found ($modsDir missing). Install the Palworld UE4SS fork first." }
if (-not (Test-Path (Join-Path $modsDir "PalSchema\dlls\main.dll"))) {
    throw "PalSchema not found under $modsDir. Install PalSchema 0.5.0+ first."
}

# Runtime
$dst = Join-Path $modsDir "PalSmith"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item (Join-Path $runtimeSrc "*") $dst -Recurse -Force
New-Item -ItemType File -Force -Path (Join-Path $dst "enabled.txt") | Out-Null
Write-Host "OK   PalSmith runtime -> $dst" -ForegroundColor Green

# Example pack
if ($WithExample) {
    $packDst = Join-Path $modsDir "PalSchema\mods\ExamplePack"
    Copy-Item $exampleSrc (Join-Path $modsDir "PalSchema\mods") -Recurse -Force
    Write-Host "OK   ExamplePack -> $packDst" -ForegroundColor Green
}

Write-Host "Done. Start the game and check ue4ss\UE4SS.log for [PalSmith] lines."
