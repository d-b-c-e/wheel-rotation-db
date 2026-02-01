<#
.SYNOPSIS
    Parses MAME data sources to inventory all racing/driving games with wheel controls.

.DESCRIPTION
    Combines data from MAME -listxml output, catver.ini, and controls.xml to identify
    all games with steering wheel, paddle, or dial controls. Cross-references the
    existing wheel-rotation database and outputs a structured JSON inventory.

    Uses streaming XML parsing (XmlReader) for the MAME listxml file since it can
    be hundreds of MB.

.PARAMETER MameXmlPath
    Path to cached MAME -listxml XML output.

.PARAMETER CatverPath
    Path to catver.ini category file.

.PARAMETER ControlsPath
    Path to controls.xml / controls.dat XML file.

.PARAMETER DatabasePath
    Path to the unified wheel-rotation.json database for cross-referencing.

.PARAMETER OutputPath
    Path to write the output JSON inventory.

.EXAMPLE
    .\Get-MameGames.ps1
    .\Get-MameGames.ps1 -MameXmlPath "C:\mame\listxml.xml" -CatverPath "C:\mame\catver.ini"
#>
param(
    [string]$MameXmlPath = "$PSScriptRoot\..\sources\downloads\mame-listxml.xml",
    [string]$CatverPath = "$PSScriptRoot\..\sources\downloads\catver.ini",
    [string]$ControlsPath = "$PSScriptRoot\..\sources\downloads\controls.xml",
    [string]$DatabasePath = "$PSScriptRoot\..\data\wheel-rotation.json",
    [string]$OutputPath = "$PSScriptRoot\..\sources\cache\mame-games.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$hasMameXml = Test-Path $MameXmlPath
$hasCatver = Test-Path $CatverPath
$hasControls = Test-Path $ControlsPath

if (-not $hasMameXml -and -not $hasCatver -and -not $hasControls) {
    Write-Warning @"
No MAME data sources found. Expected at least one of:
  - MAME listxml:  $MameXmlPath
  - catver.ini:    $CatverPath
  - controls.xml:  $ControlsPath

Run Setup-Dependencies.ps1 first to download these files.
"@
    # Output empty result
    $emptyOutput = [ordered]@{
        generated    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        sources_used = [ordered]@{ mame_listxml = $false; catver_ini = $false; controls_xml = $false }
        games        = @()
        summary      = [ordered]@{
            total_racing_games  = 0
            with_wheel_controls = 0
            parents_only        = 0
            already_in_database = 0
            needs_research      = 0
        }
    }
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    }
    $emptyOutput | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
    Write-Host "Empty inventory written to: $OutputPath"
    exit 0
}

# ============================================================
# Phase 1: Parse catver.ini for Driving/Racing categories
# ============================================================

$catverGames = @{}  # romname -> category string

if ($hasCatver) {
    Write-Host "Parsing catver.ini..."
    $inCategorySection = $false
    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path $CatverPath).Path)) {
        $line = $line.Trim()
        if ($line -eq '[Category]') {
            $inCategorySection = $true
            continue
        }
        if ($line.StartsWith('[') -and $line.EndsWith(']')) {
            if ($inCategorySection) { break }
            continue
        }
        if (-not $inCategorySection) { continue }
        if ($line -eq '' -or $line.StartsWith(';')) { continue }

        $eqIdx = $line.IndexOf('=')
        if ($eqIdx -gt 0) {
            $romname = $line.Substring(0, $eqIdx).Trim()
            $category = $line.Substring($eqIdx + 1).Trim()
            if ($category -match '(?i)(driving|racing)') {
                $catverGames[$romname] = $category
            }
        }
    }
    Write-Host "  Found $($catverGames.Count) driving/racing games in catver.ini"
}

# ============================================================
# Phase 2: Stream-parse MAME listxml for wheel/paddle/dial controls
# ============================================================

$mameGames = @{}  # romname -> hashtable of game info

if ($hasMameXml) {
    Write-Host "Parsing MAME listxml (streaming)..."
    $resolvedPath = (Resolve-Path $MameXmlPath).Path
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.IgnoreWhitespace = $true
    $reader = [System.Xml.XmlReader]::Create($resolvedPath, $settings)

    $wheelControlTypes = @('paddle', 'dial', 'ad_stick', 'lightgun_x')  # lightgun_x excluded, just paddle/dial/ad_stick
    $wheelControlTypes = @('paddle', 'dial', 'ad_stick')
    $machineCount = 0

    try {
        while ($reader.ReadToFollowing('machine')) {
            $machineCount++
            $name = $reader.GetAttribute('name')
            $cloneof = $reader.GetAttribute('cloneof')
            $romof = $reader.GetAttribute('romof')

            # Read the inner XML of this machine element
            $innerXml = $reader.ReadInnerXml()

            # Quick string check before expensive XML parse
            $hasRelevantControl = $false
            foreach ($ct in $wheelControlTypes) {
                if ($innerXml.Contains("type=`"$ct`"")) {
                    $hasRelevantControl = $true
                    break
                }
            }

            $isRacingCategory = $catverGames.ContainsKey($name)

            if (-not $hasRelevantControl -and -not $isRacingCategory) {
                continue
            }

            # Parse the inner XML fragment
            try {
                [xml]$fragment = "<machine>$innerXml</machine>"

                $title = $fragment.machine.description
                $year = $fragment.machine.year
                $manufacturer = $fragment.machine.manufacturer

                # Extract control types
                $controlTypes = @()
                $inputNode = $fragment.machine.input
                if ($inputNode) {
                    $controls = $inputNode.SelectNodes('control')
                    foreach ($ctrl in $controls) {
                        $ctype = $ctrl.GetAttribute('type')
                        if ($ctype -and $ctype -in $wheelControlTypes) {
                            $controlTypes += $ctype
                        }
                    }
                }

                $detectedBy = @()
                if ($controlTypes.Count -gt 0) { $detectedBy += 'listxml' }
                if ($isRacingCategory) { $detectedBy += 'catver' }

                if ($detectedBy.Count -gt 0) {
                    $mameGames[$name] = @{
                        romname      = $name
                        title        = $title
                        year         = $year
                        manufacturer = $manufacturer
                        category     = if ($catverGames.ContainsKey($name)) { $catverGames[$name] } else { $null }
                        parent       = $cloneof
                        is_clone     = [bool]$cloneof
                        input_types  = $controlTypes
                        detected_by  = $detectedBy
                    }
                }
            }
            catch {
                # Skip malformed fragments
            }
        }
    }
    finally {
        $reader.Close()
        $reader.Dispose()
    }
    Write-Host "  Scanned $machineCount machines, found $($mameGames.Count) wheel/racing games"
}

# ============================================================
# Phase 3: Parse controls.xml for wheel/steering/paddle mentions
# ============================================================

$controlsGames = @{}  # romname -> control type description

if ($hasControls) {
    Write-Host "Parsing controls.xml..."
    try {
        [xml]$controlsXml = Get-Content $ControlsPath -Raw

        # controls.xml from ControlsDat uses capitalized tags: <Game RomName="...">
        # with <Control Name="270 Steering Wheel"> inside <Controls> inside <Player>
        # Try multiple node name variants for compatibility
        $gameNodes = @()
        foreach ($xpath in @("//Game", "//game", "//machine")) {
            $found = $controlsXml.SelectNodes($xpath)
            if ($found -and $found.Count -gt 0) {
                $gameNodes += $found
            }
        }

        foreach ($node in $gameNodes) {
            # Try both capitalized and lowercase attribute names
            $romname = $node.GetAttribute('RomName')
            if (-not $romname) { $romname = $node.GetAttribute('romname') }
            if (-not $romname) { $romname = $node.GetAttribute('name') }
            if (-not $romname) { continue }

            # Check Control elements for wheel/steering/paddle in Name attribute
            $controlNodes = $node.SelectNodes('.//Control')
            if (-not $controlNodes) { $controlNodes = $node.SelectNodes('.//control') }
            $foundControl = $null
            if ($controlNodes) {
                foreach ($ctrl in $controlNodes) {
                    $cname = $ctrl.GetAttribute('Name')
                    if (-not $cname) { $cname = $ctrl.GetAttribute('name') }
                    if ($cname -match '(?i)(wheel|steering|paddle)') {
                        $foundControl = $cname
                        break
                    }
                }
            }

            # Also check MiscDetails text and InnerText as fallback
            if (-not $foundControl) {
                $miscNode = $node.SelectSingleNode('.//MiscDetails')
                if ($miscNode -and $miscNode.InnerText -match '(?i)(wheel|steering|paddle)') {
                    $foundControl = $Matches[0]
                }
            }
            if (-not $foundControl) {
                $nodeText = $node.InnerText
                if ($nodeText -match '(?i)(wheel|steering|paddle)') {
                    $foundControl = $Matches[0]
                }
            }

            if ($foundControl) {
                $controlsGames[$romname] = $foundControl
            }
        }
        Write-Host "  Found $($controlsGames.Count) games with wheel/steering/paddle in controls.xml"
    }
    catch {
        Write-Warning "Error parsing controls.xml: $_"
    }
}

# ============================================================
# Phase 4: Merge results from all sources
# ============================================================

$allGames = @{}

# Add from MAME listxml / catver
foreach ($entry in $mameGames.Values) {
    $allGames[$entry.romname] = $entry
}

# Add from catver-only (games not in listxml results, e.g. if listxml wasn't parsed)
foreach ($romname in $catverGames.Keys) {
    if (-not $allGames.ContainsKey($romname)) {
        $allGames[$romname] = @{
            romname      = $romname
            title        = $null
            year         = $null
            manufacturer = $null
            category     = $catverGames[$romname]
            parent       = $null
            is_clone     = $false
            input_types  = @()
            detected_by  = @('catver')
        }
    }
}

# Merge controls.xml data
foreach ($romname in $controlsGames.Keys) {
    if ($allGames.ContainsKey($romname)) {
        $allGames[$romname]['controls_dat_type'] = $controlsGames[$romname]
        if ($allGames[$romname].detected_by -notcontains 'controls_xml') {
            $allGames[$romname].detected_by += 'controls_xml'
        }
    }
    else {
        $allGames[$romname] = @{
            romname          = $romname
            title            = $null
            year             = $null
            manufacturer     = $null
            category         = $null
            parent           = $null
            is_clone         = $false
            input_types      = @()
            controls_dat_type = $controlsGames[$romname]
            detected_by      = @('controls_xml')
        }
    }
}

# ============================================================
# Phase 5: Cross-reference existing database
# ============================================================

$mameLookup = @{}
if (Test-Path $DatabasePath) {
    try {
        $db = Get-Content $DatabasePath -Raw | ConvertFrom-Json
        foreach ($prop in $db.games.PSObject.Properties) {
            $mame = $prop.Value.emulators.PSObject.Properties['mame']
            if ($mame -and $mame.Value.romname) {
                $mameLookup[$mame.Value.romname] = $prop.Name
            }
        }
        Write-Host "Loaded database with $($mameLookup.Count) MAME entries"
    }
    catch {
        Write-Warning "Could not load database: $_"
    }
}

# ============================================================
# Phase 6: Build output
# ============================================================

$outputGames = foreach ($game in $allGames.Values | Sort-Object { $_.romname }) {
    $inDb = $mameLookup.ContainsKey($game.romname)
    [ordered]@{
        romname           = $game.romname
        title             = $game.title
        year              = $game.year
        manufacturer      = $game.manufacturer
        category          = $game.category
        parent            = $game.parent
        is_clone          = $game.is_clone
        input_types       = @($game.input_types)
        controls_dat_type = $game['controls_dat_type']
        detected_by       = @($game.detected_by)
        already_in_database = $inDb
        database_key      = if ($inDb) { $mameLookup[$game.romname] } else { $null }
    }
}

$outputGamesList = @($outputGames)
$parentsOnly = ($outputGamesList | Where-Object { -not $_.is_clone }).Count
$inDbCount = ($outputGamesList | Where-Object { $_.already_in_database }).Count

$output = [ordered]@{
    generated    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    sources_used = [ordered]@{
        mame_listxml = $hasMameXml
        catver_ini   = $hasCatver
        controls_xml = $hasControls
    }
    games   = $outputGamesList
    summary = [ordered]@{
        total_racing_games  = $outputGamesList.Count
        with_wheel_controls = ($outputGamesList | Where-Object { $_.input_types.Count -gt 0 }).Count
        parents_only        = $parentsOnly
        already_in_database = $inDbCount
        needs_research      = $outputGamesList.Count - $inDbCount
    }
}

$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$output | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "=== MAME Wheel Game Inventory ==="
Write-Host "  Sources: listxml=$hasMameXml catver=$hasCatver controls=$hasControls"
Write-Host "  Total racing/driving games: $($outputGamesList.Count)"
Write-Host "  With wheel controls:        $(($outputGamesList | Where-Object { $_.input_types.Count -gt 0 }).Count)"
Write-Host "  Parent ROMs only:           $parentsOnly"
Write-Host "  Already in database:        $inDbCount"
Write-Host "  Needs research:             $($outputGamesList.Count - $inDbCount)"
Write-Host ""
Write-Host "Output written to: $OutputPath"
