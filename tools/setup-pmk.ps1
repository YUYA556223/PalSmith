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
    # Wwise SDK root; auto-detected under Audiokinetic install dir if left empty.
    [string]$WwiseSdkDir = ""
)

$ErrorActionPreference = "Stop"
function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Todo($msg) { Write-Host "  TODO $msg" -ForegroundColor Yellow }

function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# ---------------------------------------------------------------- 1. winget
Step 1 "winget の確認"
if (-not (Have winget)) {
    throw "winget が見つかりません。Microsoft Store で「アプリ インストーラー」を更新してください。"
}
Ok "winget available"

# ---------------------------------------------------------------- 2. Git
Step 2 "Git"
if (Have git) { Ok "git installed" }
else { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements; Ok "git installed via winget" }

# ---------------------------------------------------------------- 3. VS2022 + C++
Step 3 "Visual Studio 2022 Community + C++ワークロード"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsFound = (Test-Path $vswhere) -and (& $vswhere -products Microsoft.VisualStudio.Product.Community -property installationPath)
if ($vsFound) {
    Ok "VS2022 Community installed"
    Todo "未導入なら VS Installer で「C++によるデスクトップ開発」+「MSVC v143 (v14.38-17.8)」を追加してください"
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
    # UE default install root may be customized; also check E:
    $ue51 = Get-ChildItem "E:\Epic Games\UE_5.1*", "D:\Epic Games\UE_5.1*" -ErrorAction SilentlyContinue
}
if ($ue51) { Ok ("UE 5.1 found: " + $ue51[0].FullName) }
else {
    Todo "UE 5.1 は手動導入が必要です(EpicアカウントでのEULA同意のため):"
    Todo "  Epic Games Launcher → Unreal Engine → ライブラリ → [+] → バージョン 5.1.x → インストール"
    Todo "  ※容量に注意。インストール先はどのドライブでも可"
}

# ---------------------------------------------------------------- 6. PMK clone
Step 6 "PalworldModdingKit のクローン ($PmkDir)"
if (Test-Path (Join-Path $PmkDir "Pal.uproject")) { Ok "PMK already cloned" }
else {
    git clone https://github.com/localcc/PalworldModdingKit.git $PmkDir
    Ok "PMK cloned to $PmkDir"
}

# ---------------------------------------------------------------- 7. BuildConfiguration.xml
Step 7 "BuildConfiguration.xml (VS2022を明示)"
$bcDir  = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Unreal Engine\UnrealBuildTool"
$bcPath = Join-Path $bcDir "BuildConfiguration.xml"
if ((Test-Path $bcPath) -and ((Get-Content $bcPath -Raw) -match "VisualStudio2022")) {
    Ok "BuildConfiguration.xml already set for VS2022"
} elseif (Test-Path $bcPath) {
    Todo "$bcPath が既に存在します。<Compiler>VisualStudio2022</Compiler> を手で確認してください"
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
Step 8 "Wwise 2021.1.11 SDK の検出"
if (-not $WwiseSdkDir) {
    $ak = Get-ChildItem "${env:ProgramFiles(x86)}\Audiokinetic\Wwise 2021.1*" -ErrorAction SilentlyContinue |
          Sort-Object Name -Descending | Select-Object -First 1
    if ($ak) { $WwiseSdkDir = Join-Path $ak.FullName "SDK" }
}
$wwiseSdkOk = $WwiseSdkDir -and (Test-Path (Join-Path $WwiseSdkDir "include"))
if ($wwiseSdkOk) { Ok "Wwise SDK: $WwiseSdkDir" }
else {
    Todo "Wwise 2021.1.11 は手動導入が必要です(Audiokineticアカウントのため):"
    Todo "  1. Audiokinetic Launcher をインストール → Wwise 2021.1.11 を選択"
    Todo "     - SDK(C++) / Microsoft Windows Visual Studio 2022 にチェック"
    Todo "  2. 同ランチャーの Unreal integration から offline integration files をDL"
    Todo "     (Unreal.5.0.tar.xz を $WwiseOfflineDir に置く)"
    Todo "  3. このスクリプトを再実行"
}

# ---------------------------------------------------------------- 9. Wwise integration into PMK
Step 9 "Wwise手動統合の自動実行 (PMKのPlugins配下)"
$pluginDir  = Join-Path $PmkDir "Plugins"
$wwisePlug  = Join-Path $pluginDir "Wwise"
$uplugin    = Join-Path $wwisePlug "Wwise.uplugin"
if (Test-Path $uplugin) {
    Ok "Wwise plugin already integrated"
} else {
    $tarXz = Get-ChildItem $WwiseOfflineDir -Filter "Unreal.5.0.tar.xz" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not ($tarXz -and $wwiseSdkOk)) {
        Todo "Wwise SDK と Unreal.5.0.tar.xz が揃ってから再実行してください(手順はStep 8参照)"
    } else {
        Write-Host "  extracting $($tarXz.FullName) ..."
        $tmp = Join-Path $env:TEMP "pmk_wwise_extract"
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        tar -xf $tarXz.FullName -C $tmp
        $srcWwise = Get-ChildItem $tmp -Directory -Filter "Wwise" -Recurse | Select-Object -First 1
        if (-not $srcWwise) { throw "展開結果に Wwise フォルダが見つかりません" }
        New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
        Copy-Item $srcWwise.FullName $pluginDir -Recurse
        Ok "Wwise folder -> Plugins/"

        # ThirdParty: SDK components + vc170->vc160 duplicates
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
Write-Host " セットアップ状況まとめ" -ForegroundColor Cyan
Write-Host "============================================="
Write-Host " 残っている手動ステップ(あれば上のTODOを参照):"
Write-Host "  - UE 5.1 (Epic Games Launcher内でインストール)"
Write-Host "  - Wwise 2021.1.11 + offline integration files (Audiokinetic Launcher)"
Write-Host " すべてOKなら: $PmkDir\Pal.uproject をダブルクリックで起動"
Write-Host " (初回はシェーダーコンパイルで長時間かかります)"
Write-Host " 次: poc/V4-ui/README.md の Part B (Widget作成) へ"
