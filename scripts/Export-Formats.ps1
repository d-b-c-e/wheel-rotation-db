<#
.SYNOPSIS
    Generates CSV and XML exports from the wheel-rotation.json database.

.DESCRIPTION
    Reads the primary JSON database and produces:
    - wheel-rotation.json (copy for release artifact)
    - mame-wheel-rotation.csv (flat MAME ROM-to-rotation lookup)
    - mame-wheel-rotation.xml (same data in XML format)

    Only games with a MAME romname AND a known rotation value (non-null) are
    included in the MAME-specific exports.

.PARAMETER DatabasePath
    Path to the source wheel-rotation.json file.

.PARAMETER OutputDir
    Directory where export files are written. Created if it doesn't exist.
#>
param(
    [string]$DatabasePath = "$PSScriptRoot/../data/wheel-rotation.json",
    [string]$OutputDir = "$PSScriptRoot/../dist"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve paths
$DatabasePath = Resolve-Path $DatabasePath
Write-Host "Reading database: $DatabasePath"

$db = Get-Content -Raw $DatabasePath | ConvertFrom-Json
Write-Host "Database version: $($db.version) | Total games: $(($db.games.PSObject.Properties | Measure-Object).Count)"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = Resolve-Path $OutputDir

# --- 1. Copy full JSON ---
$jsonDest = Join-Path $OutputDir "wheel-rotation.json"
Copy-Item -Path $DatabasePath -Destination $jsonDest -Force
Write-Host "Exported: $jsonDest"

# --- 2. Build MAME game list (with romname + known rotation) ---
$mameGames = [System.Collections.ArrayList]::new()

foreach ($prop in $db.games.PSObject.Properties) {
    $game = $prop.Value

    if (-not $game.emulators -or -not $game.emulators.PSObject.Properties['mame']) { continue }
    $mameInfo = $game.emulators.mame
    if ($null -eq $game.rotation_degrees) { continue }

    [void]$mameGames.Add([PSCustomObject]@{
        romname         = $mameInfo.romname
        title           = $game.title
        manufacturer    = if ($game.manufacturer) { $game.manufacturer } else { '' }
        year            = if ($game.year) { $game.year } else { '' }
        rotation_degrees = $game.rotation_degrees
        rotation_type   = $game.rotation_type
        confidence      = $game.confidence
    })
}

# Sort by romname
$mameGames = $mameGames | Sort-Object romname
Write-Host "MAME games with known rotation: $($mameGames.Count)"

# --- 3. Generate CSV ---
$csvPath = Join-Path $OutputDir "mame-wheel-rotation.csv"
$csvLines = [System.Collections.ArrayList]::new()
[void]$csvLines.Add("romname,title,manufacturer,year,rotation_degrees,rotation_type,confidence")

foreach ($g in $mameGames) {
    # Escape CSV fields that might contain commas or quotes
    $title = $g.title -replace '"', '""'
    $mfr = $g.manufacturer -replace '"', '""'
    [void]$csvLines.Add("`"$($g.romname)`",`"$title`",`"$mfr`",`"$($g.year)`",$($g.rotation_degrees),`"$($g.rotation_type)`",`"$($g.confidence)`"")
}

$csvLines -join "`n" | Set-Content -Path $csvPath -Encoding UTF8 -NoNewline
Write-Host "Exported: $csvPath ($($mameGames.Count) entries)"

# --- 4. Generate XML ---
$xmlPath = Join-Path $OutputDir "mame-wheel-rotation.xml"

$xmlSettings = [System.Xml.XmlWriterSettings]::new()
$xmlSettings.Indent = $true
$xmlSettings.IndentChars = "  "
$xmlSettings.Encoding = [System.Text.UTF8Encoding]::new($false)

$stream = [System.IO.FileStream]::new($xmlPath, [System.IO.FileMode]::Create)
$writer = [System.Xml.XmlWriter]::Create($stream, $xmlSettings)

$writer.WriteStartDocument()
$writer.WriteStartElement("wheelRotationDb")
$writer.WriteAttributeString("version", $db.version)
$writer.WriteAttributeString("generated", $db.generated.ToString("yyyy-MM-ddTHH:mm:ssZ"))
$writer.WriteAttributeString("gameCount", $mameGames.Count.ToString())

foreach ($g in $mameGames) {
    $writer.WriteStartElement("game")
    $writer.WriteAttributeString("romname", $g.romname)
    $writer.WriteAttributeString("title", $g.title)
    $writer.WriteAttributeString("manufacturer", $g.manufacturer)
    $writer.WriteAttributeString("year", $g.year)
    $writer.WriteAttributeString("rotation", $g.rotation_degrees.ToString())
    $writer.WriteAttributeString("type", $g.rotation_type)
    $writer.WriteAttributeString("confidence", $g.confidence)
    $writer.WriteEndElement()
}

$writer.WriteEndElement()
$writer.WriteEndDocument()
$writer.Flush()
$writer.Close()
$stream.Close()

Write-Host "Exported: $xmlPath ($($mameGames.Count) entries)"
Write-Host "`nExport complete. Files in: $OutputDir"
