# ===================== USER CONFIG =====================
$Depots = @(
    @{ AppId  = 1794680; DepotId = 1794681; Manifest = 8734072661229265420 },
    @{ AppId  = 2230760; DepotId = 2230761; Manifest = 8810650450200200831 },
    @{ AppId  = 2313550; DepotId = 2313551; Manifest = 6130364014836738278 },
    @{ AppId  = 2690330; DepotId = 2690331; Manifest = 58333059023800463 },
    @{ AppId  = 2887680; DepotId = 2887681; Manifest = 3514133824999244705 },
    @{ AppId  = 3210350; DepotId = 3210351; Manifest = 8060350983363650803 },
    @{ AppId  = 3451100; DepotId = 3451101; Manifest = 1117835708715944408 }
)
# ======================================================

$ErrorActionPreference = "Stop"

function Parse-VDF {
    param ([string]$Text)

    $stack = @(@{})
    $key = $null

    foreach ($line in $Text -split "`n") {
        $line = $line.Trim()

        if ($line -eq '{') {
            $new = @{}
            $stack[-1][$key] = $new
            $stack += $new
            continue
        }

        if ($line -eq '}') {
            $stack = $stack[0..($stack.Count - 2)]
            continue
        }

        if ($line -match '^"(.+?)"\s+"(.*?)"$') {
            $stack[-1][$Matches[1]] = $Matches[2]
            continue
        }

        if ($line -match '^"(.+?)"$') {
            $key = $Matches[1]
            continue
        }
    }

    return $stack[0]
}

function Test-DotNetRuntime {
    param (
        [string]$VersionPrefix
    )

    try {
        $installed = & dotnet --list-runtimes 2>$null
        return $installed -match "^Microsoft\.NETCore\.App\s+$VersionPrefix"
    }
    catch {
        return $false
    }
}

# ===================== PATHS =====================
$WorkDir   = Join-Path $env:TEMP "VSModSetup"
$ToolDir   = Join-Path $WorkDir "Tools"
$DepotDir  = Join-Path $WorkDir "Depot"
$dotnet6Url = "https://dotnet.microsoft.com/download/dotnet/thank-you/runtime-6.0.28-windows-x64-installer"
$dotnet10Url = "https://dotnet.microsoft.com/download/dotnet/thank-you/runtime-10.0.1-windows-x64-installer"
$dotnetInstallPath = "$env:TEMP\DotNetInstallers"

New-Item -ItemType Directory -Force -Path $WorkDir,$ToolDir,$DepotDir,$dotnetInstallPath | Out-Null

if (-not (Test-DotNetRuntime -VersionPrefix "6.")) {
    Write-Host ".NET 6 runtime not found. Installing..."
    $dotnet6Installer = Join-Path $dotnetInstallPath "dotnet6.exe"
    Invoke-WebRequest -Uri $dotnet6Url -OutFile $dotnet6Installer
    Start-Process -FilePath $dotnet6Installer -ArgumentList "/install","/quiet","/norestart" -Wait
    Write-Host ".NET 6 installation completed."
}
else {
    Write-Host ".NET 6 runtime detected."
}

# --- Check .NET 10 ---
if (-not (Test-DotNetRuntime -VersionPrefix "10.")) {
    Write-Host ".NET 10 runtime not found. Installing..."
    $dotnet10Installer = Join-Path $dotnetInstallPath "dotnet10.exe"
    Invoke-WebRequest -Uri $dotnet10Url -OutFile $dotnet10Installer
    Start-Process -FilePath $dotnet10Installer -ArgumentList "/install","/quiet","/norestart" -Wait
    Write-Host ".NET 10 installation completed."
}
else {
    Write-Host ".NET 10 runtime detected."
}

Write-Host "All required .NET runtimes are installed."


Write-Host "=== Detecting Steam path ==="

$SteamReg = Get-ItemProperty "HKCU:\Software\Valve\Steam"
$SteamPath = $SteamReg.SteamPath

if (-not $SteamPath) {
    Write-Error "Steam installation not found."
}

$VdfPath = Join-Path $SteamPath "config\libraryfolders.vdf"
$TargetAppId = "1794680"
$content = Get-Content $VdfPath -Raw
$vdf = Parse-VDF $content
$SteamLib = ""

foreach ($lib in $vdf.libraryfolders.GetEnumerator()) {
    if ($lib.Value.apps.ContainsKey($TargetAppId)) {
        $path = $lib.Value.path -replace '\\\\','\'
        Write-Host "FOUND:" $path
		$SteamLib = $path
        break
    }
}

$SteamCommon = Join-Path $SteamLib "steamapps\common"
$VSModded    = Join-Path $SteamCommon "VSModded"
$VSBackup    = Join-Path $SteamCommon "VSDLCBackup"

Write-Host "Steam path found: $SteamPath"

# ===================== AUTO-DETECT STEAM USER =====================
Write-Host "`n=== Detecting Steam user ==="

$LoginUsersVdf = Join-Path $SteamPath "config\loginusers.vdf"
$SteamUser = $null

if (Test-Path $LoginUsersVdf) {
    $content = Get-Content $LoginUsersVdf -Raw

    $matches = [regex]::Matches(
        $content,
        '"AccountName"\s+"([^"]+)"[\s\S]*?"MostRecent"\s+"1"'
    )

    if ($matches.Count -gt 0) {
        $SteamUser = $matches[0].Groups[1].Value
        Write-Host "Detected Steam user: $SteamUser"
    }
}

if (-not $SteamUser) {
    Write-Host "Could not auto-detect Steam user."
    $SteamUser = Read-Host "Enter your Steam username"
}

# ===================== DOWNLOAD DEPOTDOWNLOADER =====================
Write-Host "`n=== Downloading latest DepotDownloader ==="

$DepotRelease = Invoke-RestMethod "https://api.github.com/repos/SteamRE/DepotDownloader/releases/latest"
$DepotAsset   = $DepotRelease.assets | Where-Object { $_.name -match "zip" } | Select-Object -First 1

$DepotZip = Join-Path $ToolDir "DepotDownloader.zip"
Invoke-WebRequest $DepotAsset.browser_download_url -OutFile $DepotZip

$DepotExtract = Join-Path $ToolDir "DepotDownloader"
Expand-Archive $DepotZip $DepotExtract -Force

$DepotDownloaderExe = Get-ChildItem $DepotExtract -Recurse -Filter "DepotDownloader.exe" | Select-Object -First 1

# ===================== CREATE VSMODDED =====================
Write-Host "`n=== Creating VSModded directory ==="
if (-not (Test-Path $VSModded)) {
	New-Item -ItemType Directory -Force -Path $VSModded | Out-Null
}
if (-not (Test-Path $VSBackup)) {
	New-Item -ItemType Directory -Force -Path $VSBackup | Out-Null
}

# ===================== DOWNLOAD ALL DEPOTS =====================
Write-Host "`n=== Downloading Steam depot ==="
Write-Host "Steam Guard prompt is normal."
foreach ($depot in $Depots) {

    $CurrentDepotDir = Join-Path $DepotDir $depot.DepotId
    New-Item -ItemType Directory -Force -Path $CurrentDepotDir | Out-Null

    Write-Host "`n=== Downloading depot $($depot.DepotId) ==="

    & $DepotDownloaderExe.FullName `
        -app $depot.AppId `
        -depot $depot.DepotId `
        -manifest $depot.Manifest `
        -username $SteamUser `
		-remember-password `
        -dir $CurrentDepotDir

    Write-Host "Merging depot $($depot.DepotId) into VSModded..."

    Get-ChildItem $CurrentDepotDir -Force | Where-Object {
        $_.Name -ne ".DepotDownloader"
    } | ForEach-Object {
        Copy-Item $_.FullName $VSModded -Recurse -Force
    }
}

# ===================== DOWNLOAD MELONLOADER NIGHTLY =====================
Write-Host "`n=== Downloading MelonLoader alpha-development nightly ==="

$MelonLoaderUrl = "https://nightly.link/LavaGang/MelonLoader/workflows/build/alpha-development/MelonLoader.Windows.x64.CI.Release.zip"
$MelonZip = Join-Path $ToolDir "MelonLoader.zip"

Invoke-WebRequest $MelonLoaderUrl -OutFile $MelonZip
Expand-Archive $MelonZip $VSModded -Force

# ===================== DOWNLOAD ICO AND BAT FILE =====================
Write-Host "`n=== Downloading VSModded.ico and MoveDLC.bat ==="
$IconUrl = "https://github.com/takacomic/VSModdedScript/raw/main/VSModded.ico"
$BatUrl  = "https://github.com/takacomic/VSModdedScript/raw/main/MoveDLC.bat"

$IconPath = Join-Path $VSModded "VSModded.ico"
$BatPath  = Join-Path $VSModded "MoveDLC.bat"

Invoke-WebRequest $IconUrl -OutFile $IconPath
Invoke-WebRequest $BatUrl -OutFile $BatPath

$lines = Get-Content $BatPath

$found = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    if (-not $found -and $lines[$i] -match '^SET\s+"STEAM_DIR=') {

        # Replace only the first occurrence
        $lines[$i] = 'SET "STEAM_DIR=' + $SteamLib + '"'
        $found = $true
    }
}

if (-not $found) {
    throw 'SET "STEAM_DIR=" not found in MoveDLC.bat'
}

Set-Content -Path $BatPath -Value $lines -Encoding ASCII


# ===================== CREATE DESKTOP SHORTCUTS =====================
Write-Host "`n=== Creating desktop shortcuts ==="

$Desktop = [Environment]::GetFolderPath("Desktop")
$WshShell = New-Object -ComObject WScript.Shell

# Game shortcut points to MoveDLC.bat
$GameShortcut = $WshShell.CreateShortcut(
    (Join-Path $Desktop "VSModded.exe.lnk")
)
$GameShortcut.TargetPath = $BatPath
$GameShortcut.WorkingDirectory = $VSModded
$GameShortcut.IconLocation = $IconPath
$GameShortcut.Save()

# Folder shortcut
$FolderShortcut = $WshShell.CreateShortcut(
    (Join-Path $Desktop "VSModded (Folder).lnk")
)
$FolderShortcut.TargetPath = $VSModded
$FolderShortcut.WorkingDirectory = $VSModded
$FolderShortcut.IconLocation = "$env:SystemRoot\system32\shell32.dll,3"
$FolderShortcut.Save()

# ===================== CLEANUP =====================
Write-Host "`n=== Cleaning up temporary files ==="

try {
    if (Test-Path $DepotZip) {
        Remove-Item $DepotZip -Force
    }
    if (Test-Path $DepotExtract) {
        Remove-Item $DepotExtract -Recurse -Force
    }
    if (Test-Path $MelonZip) {
        Remove-Item $MelonZip -Force
    }
    Write-Host "Cleanup completed."
}
catch {
    Write-Warning "Cleanup encountered an issue, but setup is complete."
}

# ===================== DONE =====================
Write-Host "`n=== VSModded setup complete ==="
Pause
