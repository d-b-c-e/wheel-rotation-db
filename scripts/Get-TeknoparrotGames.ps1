<#
.SYNOPSIS
    Scans a TeknoParrot installation to inventory all wheel-equipped arcade games.

.DESCRIPTION
    Parses TeknoParrot GameProfiles XML files to find games with steering wheel
    controls (AnalogType=Wheel), enriches with Metadata JSON (game name, platform,
    year, wheel rotation), and cross-references the existing wheel-rotation database.

    Outputs a structured JSON inventory to sources/cache/teknoparrot-games.json.

.PARAMETER TeknoparrotPath
    Path to the TeknoParrot installation directory containing GameProfiles/ and Metadata/.

.PARAMETER DatabasePath
    Path to the unified wheel-rotation.json database for cross-referencing.

.PARAMETER OutputPath
    Path to write the output JSON inventory.

.EXAMPLE
    .\Get-TeknoparrotGames.ps1
    .\Get-TeknoparrotGames.ps1 -TeknoparrotPath "C:\TeknoParrot"
#>
param(
    [string]$TeknoparrotPath = "R:\LaunchBox\Launchbox-Racing\LaunchBox\LaunchBox\Emulators\Coinops NEXT - TeknoParrot\emulators\TeknoParrot",
    [string]$DatabasePath = "$PSScriptRoot\..\data\wheel-rotation.json",
    [string]$OutputPath = "$PSScriptRoot\..\sources\cache\teknoparrot-games.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Validate TeknoParrot path
$gameProfilesDir = Join-Path $TeknoparrotPath "GameProfiles"
if (-not (Test-Path $gameProfilesDir)) {
    Write-Error "GameProfiles directory not found at: $gameProfilesDir"
    exit 1
}

$metadataDir = Join-Path $TeknoparrotPath "Metadata"
$userProfilesDir = Join-Path $TeknoparrotPath "UserProfiles"

if (-not (Test-Path $metadataDir)) {
    Write-Warning "Metadata directory not found at: $metadataDir - game names and rotation data will be unavailable"
}
if (-not (Test-Path $userProfilesDir)) {
    Write-Warning "UserProfiles directory not found at: $userProfilesDir - executable paths will be unavailable"
}

# Load existing database for cross-referencing
$profileLookup = @{}
if (Test-Path $DatabasePath) {
    try {
        $db = Get-Content $DatabasePath -Raw | ConvertFrom-Json
        foreach ($prop in $db.games.PSObject.Properties) {
            $tp = $prop.Value.emulators.PSObject.Properties['teknoparrot']
            if ($tp -and $tp.Value.profile) {
                $profileLookup[$tp.Value.profile] = @{
                    key = $prop.Name
                    rotation_degrees = $prop.Value.rotation_degrees
                }
            }
        }
        Write-Host "Loaded database with $($profileLookup.Count) TeknoParrot entries"
    }
    catch {
        Write-Warning "Could not load database at $DatabasePath : $_"
    }
}
else {
    Write-Warning "Database not found at $DatabasePath - cross-referencing disabled"
}

# Scan GameProfiles for wheel-equipped games
$xmlFiles = Get-ChildItem -Path $gameProfilesDir -Filter "*.xml" -File
$totalScanned = $xmlFiles.Count
$games = [System.Collections.ArrayList]::new()

Write-Host "Scanning $totalScanned GameProfiles..."

foreach ($xmlFile in $xmlFiles) {
    $profileId = $xmlFile.BaseName

    try {
        [xml]$xml = Get-Content $xmlFile.FullName -Raw

        # Check for wheel analog type using XPath
        $nsMgr = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
        $wheelNodes = $xml.SelectNodes("//JoystickButtons[AnalogType='Wheel']", $nsMgr)

        if ($wheelNodes.Count -eq 0) {
            continue
        }

        # Extract profile fields (some may be absent in certain profiles)
        $gp = $xml.GameProfile
        $emulationProfile = if ($gp.PSObject.Properties['EmulationProfile']) { $gp.EmulationProfile } else { $null }
        $emulatorType = if ($gp.PSObject.Properties['EmulatorType']) { $gp.EmulatorType } else { $null }
        $executableName = if ($gp.PSObject.Properties['ExecutableName']) { $gp.ExecutableName } else { $null }

        # Build game entry
        $game = [ordered]@{
            profile_id         = $profileId
            game_name          = $null
            game_genre         = $null
            platform           = $null
            release_year       = $null
            emulation_profile  = $emulationProfile
            emulator_type      = $emulatorType
            executable_name    = $executableName
            metadata_wheel_rotation = $null
            already_in_database     = $false
            database_key            = $null
            database_rotation_degrees = $null
        }

        # Enrich from Metadata JSON
        if (Test-Path $metadataDir) {
            $metaFile = Join-Path $metadataDir "$profileId.json"
            if (Test-Path $metaFile) {
                try {
                    $meta = Get-Content $metaFile -Raw | ConvertFrom-Json
                    $game.game_name = $meta.game_name
                    $game.game_genre = $meta.game_genre
                    $game.platform = $meta.platform
                    $game.release_year = $meta.release_year
                    if ($meta.PSObject.Properties['wheel_rotation'] -and $meta.wheel_rotation) {
                        $game.metadata_wheel_rotation = $meta.wheel_rotation
                    }
                }
                catch {
                    Write-Warning "Could not parse metadata for $profileId : $_"
                }
            }
        }

        # Fallback game name from profile ID if metadata unavailable
        if (-not $game.game_name) {
            $game.game_name = $profileId
        }

        # Cross-reference database
        if ($profileLookup.ContainsKey($profileId)) {
            $dbEntry = $profileLookup[$profileId]
            $game.already_in_database = $true
            $game.database_key = $dbEntry.key
            $game.database_rotation_degrees = $dbEntry.rotation_degrees
        }

        [void]$games.Add($game)
    }
    catch {
        Write-Warning "Error processing $($xmlFile.Name): $_"
    }
}

# Sort by game name
$sortedGames = $games | Sort-Object { $_.game_name }

# Build summary
$withMetadataRotation = ($sortedGames | Where-Object { $_.metadata_wheel_rotation }).Count
$alreadyInDb = ($sortedGames | Where-Object { $_.already_in_database }).Count
$needsResearch = ($sortedGames | Where-Object { -not $_.already_in_database -and -not $_.metadata_wheel_rotation }).Count

$output = [ordered]@{
    generated        = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    teknoparrot_path = $TeknoparrotPath
    games            = @($sortedGames)
    summary          = [ordered]@{
        total_profiles_scanned = $totalScanned
        wheel_equipped_games   = $sortedGames.Count
        with_metadata_rotation = $withMetadataRotation
        already_in_database    = $alreadyInDb
        needs_research         = $needsResearch
    }
}

# Ensure output directory exists
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Write output
$output | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
Write-Host ""
Write-Host "=== TeknoParrot Wheel Game Inventory ==="
Write-Host "  Profiles scanned:        $totalScanned"
Write-Host "  Wheel-equipped games:    $($sortedGames.Count)"
Write-Host "  With metadata rotation:  $withMetadataRotation"
Write-Host "  Already in database:     $alreadyInDb"
Write-Host "  Needs research:          $needsResearch"
Write-Host ""
Write-Host "Output written to: $OutputPath"
