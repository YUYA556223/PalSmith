# PalSmith PMK setup helper
# ============================
# Automates everything license-safe in poc/V4-ui/README.md Part A:
#   [auto]   Visual Studio 2022 Community (+C++ workload, MSVC v14.38), .NET 6,
#            Git, Epic Games Launcher, PMK clone, BuildConfiguration.xml
#   [manual] UE 5.1 (Epic account/EULA) and Wwise 2021.1.11 (Audiokinetic account)
#            -> the script tells you exactly what to click, then run it again.
#   [auto]   Wwise manual-integration (the error-prone copy/patch steps) once the
#            Wwise SDK + offline integration archive are present.
#
# Usage (PowerShell, run as your normal user; elevation is requested when needed):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\setup-pmk.ps1                          # default PMK dir: E:\PalworldModdingKit
#   .\setup-pmk.ps1 -PmkDir D:\PMK
#
# Re-run any time - every step is idempotent and skips what's already done.

param(
    [string]$PmkDir = "E:\PalworldModdingKit",
    # Folder that contains the Wwise *offline integration* download (Unreal.5.0.tar.xz).
    [string]$WwiseOfflineDir = "$env:USERPROFILE\Downloads",
    # Wwise SDK root; auto-detected under the Audiokinetic install dir if left empty.
    [string]$WwiseSdkDir = ""
)

$ErrorActionPreference = "Stop"
function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK   $msg" -ForegroundColor Green }
function Todo($msg) { Write-Host "  TODO $msg" -ForegroundColor Yellow }

function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# ---------------------------------------------------------------- 1. winget
Step 1 "Checking winget"
if (-not (Have winget)) {
    throw "winget not found. Update 'App Installer' from the Microsoft Store."
}
Ok "winget available"

# ---------------------------------------------------------------- 2. Git
Step 2 "Git"
if (Have git) { Ok "git installed" }
else { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements; Ok "git installed via winget" }

# ---------------------------------------------------------------- 3. VS2022 + C++
Step 3 "Visual Studio 2022 Community + C++ workload"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsFound = (Test-Path $vswhere) -and (& $vswhere -products Microsoft.VisualStudio.Product.Community -property installationPath)
if ($vsFound) {
    Ok "VS2022 Community installed"
    Todo "If missing, add via VS Installer: 'Desktop development with C++' + 'MSVC v143 (v14.38-17.8)'"
} else {
    winget install --id Microsoft.VisualStudio.2022.Community -e --accept-source-agreements --accept-package-agreements `
        --override "--passive --wait --add Microsoft.VisualStudio.Workload.NativeDesktop;includeRecommended --add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64"
    Ok "VS2022 Community + C++ workload + MSVC v14.38 installed"
}

# ---------------------------------------------------------------- 4. .NET 6
Step 4 ".NET 6 Runtime"
$dotnet6 = (Have dotnet) -and ((dotnet --list-runtimes 2>$null) -match "Microsoft\.NETCore\.App 6\.")
if ($dotnet6) { Ok ".NET 6 runtime installed" }
else { winget install --id Microsoft.DotNet.Runtime.6 -e --accept-source-agreements --accept-package-agreements; Ok ".NET 6 installed" }

# ---------------------------------------------------------------- 5. Epic Games Launcher / UE5.1
Step 5 "Epic Games Launcher / Unreal Engine 5.1"
$epicExe = "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"
if (Test-Path $epicExe) { Ok "Epic Games Launcher installed" }
else { winget install --id EpicGames.EpicGamesLauncher -e --accept-source-agreements --accept-package-agreements; Ok "Epic Games Launcher installed" }

$ue51 = Get-ChildItem "C:\Program Files\Epic Games\UE_5.1*" -ErrorAction SilentlyContinue
if (-not $ue51) {
    # UE install root may be customized; also check other drives
    $ue51 = Get-ChildItem "E:\Unreal\UE_5.1*", "E:\Epic Games\UE_5.1*", "D:\Epic Games\UE_5.1*" -ErrorAction SilentlyContinue
}
if ($ue51) { Ok ("UE 5.1 found: " + $ue51[0].FullName) }
else {
    Todo "UE 5.1 must be installed manually (Epic account / EULA consent required):"
    Todo "  Epic Games Launcher -> Unreal Engine -> Library -> [+] -> version 5.1.x -> Install"
    Todo "  Any install drive is fine; mind the disk space"
}

# ---------------------------------------------------------------- 6. PMK clone
Step 6 "Cloning PalworldModdingKit ($PmkDir)"
if (Test-Path (Join-Path $PmkDir "Pal.uproject")) { Ok "PMK already cloned" }
else {
    git clone https://github.com/localcc/PalworldModdingKit.git $PmkDir
    Ok "PMK cloned to $PmkDir"
}

# ---------------------------------------------------------------- 7. BuildConfiguration.xml
Step 7 "BuildConfiguration.xml (force VS2022)"
$bcDir  = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Unreal Engine\UnrealBuildTool"
$bcPath = Join-Path $bcDir "BuildConfiguration.xml"
if ((Test-Path $bcPath) -and ((Get-Content $bcPath -Raw) -match "VisualStudio2022")) {
    Ok "BuildConfiguration.xml already set for VS2022"
} elseif (Test-Path $bcPath) {
    Todo "$bcPath already exists. Verify it contains <Compiler>VisualStudio2022</Compiler>"
} else {
    New-Item -ItemType Directory -Force -Path $bcDir | Out-Null
    @"
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
    <WindowsPlatform>
        <Compiler>VisualStudio2022</Compiler>
    </WindowsPlatform>
</Configuration>
"@ | Set-Content -Encoding UTF8 $bcPath
    Ok "BuildConfiguration.xml created ($bcPath)"
}

# ---------------------------------------------------------------- 8. Wwise SDK detection
Step 8 "Detecting Wwise 2021.1.11 SDK"
if (-not $WwiseSdkDir) {
    $ak = Get-ChildItem "${env:ProgramFiles(x86)}\Audiokinetic\Wwise 2021.1*", "E:\AudioKinetic\Wwise_2021.1*" -ErrorAction SilentlyContinue |
          Sort-Object Name -Descending | Select-Object -First 1
    if ($ak) { $WwiseSdkDir = Join-Path $ak.FullName "SDK" }
}
$wwiseSdkOk = $WwiseSdkDir -and (Test-Path (Join-Path $WwiseSdkDir "include"))
if ($wwiseSdkOk) { Ok "Wwise SDK: $WwiseSdkDir" }
else {
    Todo "Wwise 2021.1.11 must be installed manually (Audiokinetic account required):"
    Todo "  1. Install the Audiokinetic Launcher -> select Wwise 2021.1.11"
    Todo "     - check SDK (C++) / Microsoft Windows Visual Studio 2022"
    Todo "  2. From the same launcher, download the Unreal *offline integration* files"
    Todo "     (put Unreal.5.0.tar.xz into $WwiseOfflineDir)"
    Todo "  3. Re-run this script"
}

# ---------------------------------------------------------------- 9. Wwise integration into PMK
Step 9 "Wwise integration into PMK (Plugins/)"
$pluginDir  = Join-Path $PmkDir "Plugins"
$wwisePlug  = Join-Path $pluginDir "Wwise"
$uplugin    = Join-Path $wwisePlug "Wwise.uplugin"
if (Test-Path $uplugin) {
    Ok "Wwise plugin already integrated"
} else {
    $tarXz = Get-ChildItem $WwiseOfflineDir -Filter "Unreal.5.0.tar.xz" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not ($tarXz -and $wwiseSdkOk)) {
        Todo "Re-run once the Wwise SDK and Unreal.5.0.tar.xz are in place (see Step 8)"
    } else {
        Write-Host "  extracting $($tarXz.FullName) ..."
        $tmp = Join-Path $env:TEMP "pmk_wwise_extract"
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        tar -xf $tarXz.FullName -C $tmp
        $srcWwise = Get-ChildItem $tmp -Directory -Filter "Wwise" -Recurse | Select-Object -First 1
        if (-not $srcWwise) { throw "No 'Wwise' folder found in the extracted archive" }
        New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
        Copy-Item $srcWwise.FullName $pluginDir -Recurse
        Ok "Wwise folder -> Plugins/"

        # ThirdParty: SDK components + vc170 -> vc160 duplicates
        $third = Join-Path $wwisePlug "ThirdParty"
        New-Item -ItemType Directory -Force -Path $third | Out-Null
        foreach ($c in @("Win32_vc170", "x64_vc170", "include")) {
            Copy-Item (Join-Path $WwiseSdkDir $c) $third -Recurse -Force
            Ok "SDK $c -> ThirdParty/"
        }
        foreach ($pair in @(@("Win32_vc170","Win32_vc160"), @("x64_vc170","x64_vc160"))) {
            $dst = Join-Path $third $pair[1]
            if (-not (Test-Path $dst)) { Copy-Item (Join-Path $third $pair[0]) $dst -Recurse }
            Ok "$($pair[0]) duplicated as $($pair[1])"
        }

        # Patch EngineVersion 5.0.0 -> 5.1
        (Get-Content $uplugin -Raw) -replace '"EngineVersion"\s*:\s*"5\.0\.0"', '"EngineVersion": "5.1"' |
            Set-Content -Encoding UTF8 $uplugin
        Ok 'Wwise.uplugin EngineVersion -> "5.1"'
    }
}

# ---------------------------------------------------------------- done
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " Setup summary" -ForegroundColor Cyan
Write-Host "============================================="
Write-Host " Remaining manual steps (see TODO lines above, if any):"
Write-Host "  - UE 5.1 (install inside Epic Games Launcher)"
Write-Host "  - Wwise 2021.1.11 + offline integration files (Audiokinetic Launcher)"
Write-Host " When everything is OK: double-click $PmkDir\Pal.uproject"
Write-Host " (first launch takes a long time compiling shaders)"
Write-Host " Next: poc/V4-ui/README.md Part B (author the widget)"
