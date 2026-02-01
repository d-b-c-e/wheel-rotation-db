<#
.SYNOPSIS
    Downloads and copies MAME data dependencies for wheel-rotation-db.

.DESCRIPTION
    Gathers the data files needed by Get-MameGames.ps1:
      - catver.ini   (game categories - copied from local LaunchBox or downloaded from GitHub)
      - controls.xml (control panel descriptions - downloaded from GitHub)
      - nplayers.ini (player counts - copied from local LaunchBox or downloaded from GitHub)
      - mame-listxml.xml (MAME machine database - generated from local MAME executable)

    Local LaunchBox installations are checked first. If not found, files are
    downloaded from GitHub mirrors. The MAME listxml is only generated if a
    local MAME executable is found (the file is ~300MB and takes a minute to generate).

.PARAMETER DownloadPath
    Directory to store downloaded/copied dependency files.

.PARAMETER MameExePath
    Path to mame64.exe (or mame.exe). Auto-detected from LaunchBox if not specified.

.PARAMETER Force
    Re-download/regenerate even if files already exist.

.PARAMETER SkipListXml
    Skip generating the large MAME listxml output.

.EXAMPLE
    .\Setup-Dependencies.ps1
    .\Setup-Dependencies.ps1 -Force
    .\Setup-Dependencies.ps1 -MameExePath "C:\mame\mame64.exe"
#>
param(
    [string]$DownloadPath = "$PSScriptRoot\..\sources\downloads",
    [string]$MameExePath,
    [switch]$Force,
    [switch]$SkipListXml
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve to absolute path
$DownloadPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\sources\downloads"))

if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Force -Path $DownloadPath | Out-Null
}

Write-Host "=== Setup Dependencies ===" -ForegroundColor Cyan
Write-Host "  Output directory: $DownloadPath"
Write-Host ""

# ============================================================
# Known local sources (LaunchBox installations)
# ============================================================

$launchBoxBase = "R:\LaunchBox"
$localSources = @{
    catver = @(
        "$launchBoxBase\Launchbox-Dance\ThirdParty\MAME\catver.ini"
        "$launchBoxBase\Launchbox-Portrait\ThirdParty\MAME\catver.ini"
        "$launchBoxBase\LaunchBox Lightgun\ThirdParty\MAME\catver.ini"
    )
    nplayers = @(
        "$launchBoxBase\Launchbox-Dance\ThirdParty\MAME\nplayers.ini"
        "$launchBoxBase\Launchbox-Portrait\ThirdParty\MAME\nplayers.ini"
        "$launchBoxBase\LaunchBox Lightgun\ThirdParty\MAME\nplayers.ini"
    )
    mame_exe = @(
        "$launchBoxBase\LaunchBox Lightgun\Emulators\MAME 0227\mame64.exe"
        "$launchBoxBase\LaunchBox Lightgun\Emulators\mame\mame64.exe"
        "$launchBoxBase\LaunchBox Lightgun\Emulators\mame\mame.exe"
    )
}

# GitHub fallback URLs
$githubUrls = @{
    catver      = "https://raw.githubusercontent.com/AntoPISA/MAME_SupportFiles/main/catver.ini"
    controls    = "https://raw.githubusercontent.com/benbaker76/ControlsDat/master/Data/Data/Controls.xml"
}

# ============================================================
# Helper: Find newest local file from a list of candidates
# ============================================================

function Find-NewestLocal {
    param([string[]]$Candidates)
    $found = $Candidates | Where-Object { Test-Path $_ } |
        Sort-Object { (Get-Item $_).LastWriteTime } -Descending |
        Select-Object -First 1
    return $found
}

# ============================================================
# Helper: Download file with retry
# ============================================================

function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [int]$MaxRetries = 3
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "    Downloading (attempt $i/$MaxRetries)..."
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
            $size = (Get-Item $Destination).Length
            Write-Host "    Downloaded: $([math]::Round($size / 1KB, 1)) KB"
            return $true
        }
        catch {
            Write-Warning "    Attempt $i failed: $_"
            if ($i -eq $MaxRetries) { return $false }
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

# ============================================================
# 1. catver.ini
# ============================================================

$catverDest = Join-Path $DownloadPath "catver.ini"

if ((Test-Path $catverDest) -and -not $Force) {
    Write-Host "[catver.ini] Already exists, skipping (use -Force to overwrite)" -ForegroundColor DarkGray
}
else {
    Write-Host "[catver.ini] " -NoNewline -ForegroundColor Yellow
    $localCatver = Find-NewestLocal $localSources.catver
    if ($localCatver) {
        Write-Host "Copying from local LaunchBox..."
        Write-Host "    Source: $localCatver"
        Copy-Item -Path $localCatver -Destination $catverDest -Force
        $size = (Get-Item $catverDest).Length
        Write-Host "    Copied: $([math]::Round($size / 1KB, 1)) KB" -ForegroundColor Green
    }
    else {
        Write-Host "Downloading from GitHub..."
        $ok = Download-File -Url $githubUrls.catver -Destination $catverDest
        if ($ok) {
            Write-Host "    Done" -ForegroundColor Green
        }
        else {
            Write-Warning "    Failed to download catver.ini"
        }
    }
}

# ============================================================
# 2. controls.xml
# ============================================================

$controlsDest = Join-Path $DownloadPath "controls.xml"

if ((Test-Path $controlsDest) -and -not $Force) {
    Write-Host "[controls.xml] Already exists, skipping (use -Force to overwrite)" -ForegroundColor DarkGray
}
else {
    Write-Host "[controls.xml] Downloading from GitHub..." -ForegroundColor Yellow
    $ok = Download-File -Url $githubUrls.controls -Destination $controlsDest
    if ($ok) {
        Write-Host "    Done" -ForegroundColor Green
    }
    else {
        Write-Warning "    Failed to download controls.xml"
    }
}

# ============================================================
# 3. nplayers.ini (optional but useful)
# ============================================================

$nplayersDest = Join-Path $DownloadPath "nplayers.ini"

if ((Test-Path $nplayersDest) -and -not $Force) {
    Write-Host "[nplayers.ini] Already exists, skipping (use -Force to overwrite)" -ForegroundColor DarkGray
}
else {
    Write-Host "[nplayers.ini] " -NoNewline -ForegroundColor Yellow
    $localNplayers = Find-NewestLocal $localSources.nplayers
    if ($localNplayers) {
        Write-Host "Copying from local LaunchBox..."
        Write-Host "    Source: $localNplayers"
        Copy-Item -Path $localNplayers -Destination $nplayersDest -Force
        $size = (Get-Item $nplayersDest).Length
        Write-Host "    Copied: $([math]::Round($size / 1KB, 1)) KB" -ForegroundColor Green
    }
    else {
        Write-Host "No local source found, skipping (optional file)" -ForegroundColor DarkGray
    }
}

# ============================================================
# 4. MAME listxml
# ============================================================

$listxmlDest = Join-Path $DownloadPath "mame-listxml.xml"

if ($SkipListXml) {
    Write-Host "[mame-listxml.xml] Skipped (use without -SkipListXml to generate)" -ForegroundColor DarkGray
}
elseif ((Test-Path $listxmlDest) -and -not $Force) {
    Write-Host "[mame-listxml.xml] Already exists, skipping (use -Force to regenerate)" -ForegroundColor DarkGray
}
else {
    # Find MAME executable
    $mameExe = $MameExePath
    if (-not $mameExe) {
        $mameExe = Find-NewestLocal $localSources.mame_exe
    }

    if ($mameExe -and (Test-Path $mameExe)) {
        Write-Host "[mame-listxml.xml] Generating from MAME executable..." -ForegroundColor Yellow
        Write-Host "    MAME: $mameExe"
        Write-Host "    This will produce a ~300MB XML file and may take a minute..."
        try {
            & $mameExe -listxml 2>$null | Set-Content -Path $listxmlDest -Encoding UTF8
            $size = (Get-Item $listxmlDest).Length
            Write-Host "    Generated: $([math]::Round($size / 1MB, 1)) MB" -ForegroundColor Green
        }
        catch {
            Write-Warning "    Failed to generate listxml: $_"
            if (Test-Path $listxmlDest) { Remove-Item $listxmlDest }
        }
    }
    else {
        Write-Host "[mame-listxml.xml] No MAME executable found, skipping" -ForegroundColor DarkGray
        Write-Host "    Provide -MameExePath or install MAME under R:\LaunchBox"
    }
}

# ============================================================
# Summary
# ============================================================

Write-Host ""
Write-Host "=== Dependency Status ===" -ForegroundColor Cyan

$files = @(
    @{ Name = "catver.ini";        Path = $catverDest;   Required = $true }
    @{ Name = "controls.xml";      Path = $controlsDest; Required = $true }
    @{ Name = "nplayers.ini";      Path = $nplayersDest; Required = $false }
    @{ Name = "mame-listxml.xml";  Path = $listxmlDest;  Required = $true }
)

$allReady = $true
foreach ($f in $files) {
    $exists = Test-Path $f.Path
    $label = if ($f.Required) { "REQUIRED" } else { "optional" }
    if ($exists) {
        $size = (Get-Item $f.Path).Length
        $sizeStr = if ($size -gt 1MB) { "$([math]::Round($size / 1MB, 1)) MB" } else { "$([math]::Round($size / 1KB, 1)) KB" }
        Write-Host "  [OK]      $($f.Name) ($sizeStr)" -ForegroundColor Green
    }
    else {
        if ($f.Required) {
            Write-Host "  [MISSING] $($f.Name) ($label)" -ForegroundColor Red
            $allReady = $false
        }
        else {
            Write-Host "  [MISSING] $($f.Name) ($label)" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
if ($allReady) {
    Write-Host "All required dependencies are ready. Run Get-MameGames.ps1 next." -ForegroundColor Green
}
else {
    Write-Host "Some required dependencies are missing. See above for details." -ForegroundColor Yellow
}
