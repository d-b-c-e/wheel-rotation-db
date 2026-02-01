# CLAUDE.md - wheel-rotation-db

## Project Overview

**wheel-rotation-db** is a community database of steering wheel rotation degrees for classic arcade racing/driving games. This metadata helps emulator users (MAME, Teknoparrot, etc.) configure their USB racing wheels to match the original arcade cabinet's wheel rotation, providing an authentic gameplay experience.

### Why This Matters

Modern racing wheels typically support 270°, 540°, 900°, or 1080° rotation. Original arcade cabinets varied widely:
- Some used ~180° (very twitchy, race car style)
- Many used 270° (common for arcade racers)
- Some used 360° or more (simulation-style games)
- A few used infinite rotation optical encoders (spinners)

Without this metadata, players must guess or manually research each game.

### Primary Goals

1. **Build a complete inventory first** - Identify ALL games with wheel/steering controls across MAME and Teknoparrot before researching rotation values. Every wheel-equipped game should have an entry, even if the rotation is unknown initially.
2. Create a comprehensive, machine-readable database of wheel rotation values for arcade racing games
3. Document data sources and confidence levels for each entry
4. Provide tooling to help frontends and emulators auto-configure wheel rotation
5. Cover both MAME and Teknoparrot platforms from the start

### Phased Approach

- **Phase 1: Inventory** - Enumerate all wheel-equipped games from MAME (via `-listxml`, `controls.dat`, `catver.ini`) and Teknoparrot (via GameProfiles XML). Every game gets an entry with `rotation_degrees: null` (unknown) initially.
- **Phase 2: Seed Known Values** - Populate well-known rotation values from manufacturer patterns, service manuals, and community consensus.
- **Phase 3: Research** - Systematically research unknown games, starting with parent ROMs and popular titles.
- **Phase 4: Community** - Accept contributions and corrections via pull requests.

### Special Values

- **`-1`** = Infinite rotation / optical encoder (no physical stops). Used for spinners, dial controls, and early steering wheels that rotate continuously. These games need special handling in emulators (map to mouse/spinner input rather than a fixed-range wheel).
- **`null`** = Rotation value not yet determined. The game is in the inventory but needs research.

### Unified Game-Centric Model

A single physical arcade game may be emulated by multiple platforms (MAME, TeknoParrot, Supermodel, Model2 Emulator, Flycast, etc.). The database should have **one entry per game** with emulator-specific metadata as sub-entries, rather than duplicating game data across platform-specific files.

**Roadmap**: Migrate from per-platform files (`data/mame/`, `data/teknoparrot/`) to a unified structure where each game entry contains an `emulators` map linking to platform-specific identifiers (ROM names, profile filenames, etc.). This avoids data duplication and conflicting entries for the same physical cabinet.

### Other Emulators to Consider

Beyond MAME and TeknoParrot, many arcade racing games are emulated by standalone or specialized emulators:

| Emulator | Hardware Covered | Notes |
|----------|-----------------|-------|
| **Supermodel** | Sega Model 3 (Daytona USA 2, Scud Race, Sega Rally 2, etc.) | High-quality Model 3 emulation |
| **Model 2 Emulator** | Sega Model 2 (Daytona USA, Sega Rally, etc.) | Overlaps with MAME but often preferred |
| **Flycast / Demul** | Sega Naomi/Naomi 2, Atomiswave | Initial D Arcade Stage 1-3, F355 Challenge |
| **Cxbx-Reloaded** | Sega Chihiro (Xbox-based) | OutRun 2, House of the Dead III |
| **Dolphin** | Triforce (GameCube-based) | F-Zero AX, Mario Kart Arcade GP |
| **RPCS3** | Namco System 357 (PS3-based) | Some newer arcade titles |
| **PCSX2** | Namco System 246/256 (PS2-based) | Ridge Racer V, Wangan Midnight |

A game like Daytona USA could be run on MAME, Model 2 Emulator, or even Supermodel (for the Model 3 sequel) - the physical cabinet's wheel rotation is the same regardless of which emulator runs it. The unified model captures this correctly.

---

## Repository Structure

```
wheel-rotation-db/
├── CLAUDE.md                    # This file - AI assistant instructions
├── README.md                    # Project documentation for humans
├── LICENSE                      # License file (recommend MIT or CC0)
├── data/
│   ├── wheel-rotation.json      # Unified database (one entry per game)
│   ├── wheel-rotation.csv       # CSV export for easy viewing
│   ├── wheel-rotation.xml       # XML export for MAME ecosystem compatibility
│   └── schema/
│       └── wheel-rotation.schema.json  # JSON Schema for validation
├── scripts/
│   ├── Setup-Dependencies.ps1   # Downloads MAME, controls.dat, catver.ini, etc.
│   ├── Get-MameGames.ps1        # Filters MAME games to racing/driving with wheel controls
│   ├── Get-TeknoparrotGames.ps1 # Extracts wheel games from TeknoParrot installation
│   ├── Research-WheelRotation.ps1  # Autonomous research script
│   ├── Update-Database.ps1      # Merges research findings into database
│   ├── Export-Formats.ps1       # Generates CSV, XML from JSON master
│   └── Validate-Database.ps1    # Validates against schema
├── sources/
│   ├── downloads/               # Downloaded dependencies (gitignored)
│   └── cache/                   # Cached research results (gitignored)
└── docs/
    ├── CONTRIBUTING.md          # How to contribute manual entries
    ├── DATA-SOURCES.md          # Documents where data comes from
    └── INTEGRATION.md           # How to use this data in frontends/emulators
```

---

## Data Schema

### Primary Database Format (JSON)

The database uses a **unified game-centric model**. Each entry represents a unique physical arcade game/cabinet. Emulator-specific identifiers are stored in an `emulators` map so a single game's rotation data is never duplicated.

```json
{
  "version": "1.0.0",
  "generated": "2026-01-31T00:00:00Z",
  "games": {
    "outrun": {
      "title": "Out Run",
      "manufacturer": "Sega",
      "year": "1986",
      "rotation_degrees": 270,
      "rotation_type": "mechanical_stop",
      "confidence": "high",
      "sources": [
        {
          "type": "manual",
          "description": "Sega Out Run Operator's Manual",
          "url": null,
          "date_accessed": "2026-01-31"
        }
      ],
      "notes": "Uses mechanical stops at 135 degrees each direction from center. Sega Super Scaler hardware.",
      "emulators": {
        "mame": {
          "romname": "outrun",
          "clones_inherit": true
        }
      }
    },
    "outrun2_sp_sdx": {
      "title": "OutRun 2 SP SDX",
      "manufacturer": "Sega",
      "year": "2006",
      "rotation_degrees": 270,
      "rotation_type": "mechanical_stop",
      "confidence": "verified",
      "sources": [
        {
          "type": "other",
          "description": "TeknoParrot Metadata - wheel_rotation field",
          "url": null,
          "date_accessed": "2026-01-31"
        }
      ],
      "notes": "Sega Lindbergh Yellow hardware.",
      "emulators": {
        "teknoparrot": {
          "profile": "or2spdlx"
        }
      }
    },
    "polepos": {
      "title": "Pole Position",
      "manufacturer": "Namco",
      "year": "1982",
      "rotation_degrees": -1,
      "rotation_type": "optical_encoder",
      "confidence": "high",
      "sources": [
        {
          "type": "manual",
          "description": "Namco/Atari Pole Position uses optical encoder wheel with infinite rotation",
          "url": null,
          "date_accessed": "2026-01-31"
        }
      ],
      "notes": "Infinite rotation optical encoder (spinner). Maps better to spinner/mouse input than modern wheel.",
      "emulators": {
        "mame": {
          "romname": "polepos",
          "clones_inherit": true
        }
      }
    }
  }
}
```

### Game Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Full display title of the game |
| `manufacturer` | string | No | Cabinet manufacturer (Sega, Namco, Midway, etc.) |
| `year` | string | No | Release year |
| `rotation_degrees` | number or null | Yes | Total rotation in degrees (e.g., 270 means ±135° from center). Use `-1` for infinite rotation (optical encoder/spinner). Use `null` if unknown/not yet researched. |
| `rotation_type` | enum | Yes | `mechanical_stop`, `optical_encoder`, `potentiometer`, `unknown` |
| `confidence` | enum | Yes | `verified` (manual/official), `high` (multiple sources), `medium` (single reliable source), `low` (inference/guess), `unknown` |
| `sources` | array | Yes | At least one source documenting where the data came from |
| `notes` | string | No | Additional context about the control setup |
| `emulators` | object | Yes | Map of emulator platform IDs to platform-specific metadata |

### Emulator Sub-Entry Fields

Each key in `emulators` is a platform identifier. Known platforms:

| Platform Key | Emulator | Identifier Field | Description |
|-------------|----------|-----------------|-------------|
| `mame` | MAME | `romname` | MAME ROM set name. `clones_inherit`: whether clone ROMs share this value. |
| `teknoparrot` | TeknoParrot | `profile` | GameProfile XML filename (without `.xml`) |
| `supermodel` | Supermodel | `romname` | Sega Model 3 ROM name |
| `m2emulator` | Model 2 Emulator | `romname` | Sega Model 2 ROM name |
| `flycast` | Flycast/Demul | `romname` | Naomi/Atomiswave ROM name |
| `dolphin` | Dolphin | `game_id` | Triforce/GameCube game ID |

Additional platform keys can be added as needed. The `emulators` map allows a single game to be linked to multiple emulation platforms.

### Rotation Types Explained

- **mechanical_stop**: Wheel has physical stops limiting rotation (most common)
- **optical_encoder**: Infinite rotation, relative positioning (like Pole Position)
- **potentiometer**: Absolute position sensing with physical limits
- **unknown**: Rotation type not determined

---

## Dependencies

### Required Downloads

The setup script should download and cache these:

1. **MAME Executable** (for `-listxml` output)
   - Source: https://www.mamedev.org/release.html
   - We only need the executable, not ROMs

2. **controls.dat / controls.xml**
   - Source: http://controls.arcadecontrols.com or GitHub mirrors
   - Provides control type information per game

3. **catver.ini**
   - Source: https://www.progettosnaps.net/catver/
   - Provides game categories to filter racing/driving games

4. **Category.ini**
   - Source: https://www.progettosnaps.net/renameset/
   - Alternative categorization

5. **nplayers.ini** (optional)
   - Source: http://nplayers.arcadebelgium.be/
   - Player count information

### PowerShell Requirements

- PowerShell 7+ recommended (cross-platform)
- Modules: None required (use native cmdlets)

---

## Script Specifications

### Implemented Scripts

#### Setup-Dependencies.ps1
Downloads/copies MAME data dependencies. Checks local LaunchBox installations first (R:\LaunchBox), falls back to GitHub downloads. Outputs to `sources/downloads/`.
- **catver.ini** - From local LaunchBox or [GitHub (AntoPISA/MAME_SupportFiles)](https://github.com/AntoPISA/MAME_SupportFiles)
- **controls.xml** - From [GitHub (benbaker76/ControlsDat)](https://github.com/benbaker76/ControlsDat)
- **nplayers.ini** - From local LaunchBox (optional)
- **mame-listxml.xml** - Generated from local MAME executable (~237MB)

Parameters: `-DownloadPath`, `-MameExePath`, `-Force`, `-SkipListXml`

#### Get-MameGames.ps1
Parses three MAME data sources to inventory all racing/driving games with wheel controls. Uses streaming XmlReader for the large listxml file. Outputs to `sources/cache/mame-games.json`.
- Phase 1: Parse catver.ini for Driving/Racing categories
- Phase 2: Stream-parse MAME listxml for paddle/dial/ad_stick controls
- Phase 3: Parse controls.xml for wheel/steering/paddle mentions (note: uses capitalized XML tags like `<Game RomName="...">`)
- Phase 4-6: Merge sources, cross-reference database, output JSON

Results: 1,488 total games, 484 with wheel controls, 1,040 parent ROMs, 63 from controls.xml with verified rotation values.

#### Get-TeknoparrotGames.ps1
Scans local TeknoParrot installation for wheel-equipped games. Reads GameProfiles XML for `<AnalogType>Wheel</AnalogType>`, enriches from Metadata JSON. Outputs to `sources/cache/teknoparrot-games.json`.

Results: 487 profiles scanned, 98 wheel-equipped, 25 with metadata rotation values.

### Planned Scripts

#### Export-Formats.ps1
Generate CSV and XML exports from the JSON master database.
- `data/wheel-rotation.csv` - Flat format for spreadsheets
- `data/wheel-rotation.xml` - MAME ecosystem compatible format

#### Validate-Database.ps1
Validate database against JSON schema and check for issues:
- JSON schema compliance
- No duplicate entries or conflicting emulator mappings
- All required fields present
- Rotation values are -1 (infinite), null (unknown), or within range (45-1080)
- Confidence levels are valid enum values

---

## Research Guidelines for Claude

When researching wheel rotation values, follow these guidelines:

### Reliable Sources (High Confidence)

1. **Official Operator/Service Manuals** - Definitive source
2. **Arcade Museum (KLOV)** - Community-verified specifications
3. **Original cabinet photos showing wheel mechanism** - Physical evidence
4. **BYOAC forum posts from cabinet owners** - First-hand experience

### Moderate Sources (Medium Confidence)

1. **Forum discussions with consensus** - Multiple agreeing users
2. **YouTube cabinet tours** - Visual confirmation
3. **Game-specific wikis** - May be accurate but verify

### Weak Sources (Low Confidence)

1. **Single forum post without verification**
2. **Blog posts without cited sources**
3. **Reddit comments**

### Inference Rules

When no direct information is available:

1. **Same hardware platform** - Games on same arcade board often share controls
   - Example: All Sega Super Scaler games likely share similar wheel specs
   
2. **Same manufacturer/era** - Manufacturers reused cabinet designs
   - Example: Sega Model 2 racing games likely similar
   
3. **Game series** - Sequels usually maintain control schemes
   - Example: OutRun → Turbo OutRun → OutRunners

4. **Control type hints** - 
   - "Spinner" or "dial" = likely optical encoder (infinite rotation)
   - "Paddle" = likely potentiometer with stops (180-270°)
   - "Steering wheel" = could be either, need more info

### Search Strategies

```
# Primary searches
"{game_title}" arcade steering wheel rotation degrees
"{game_title}" cabinet specifications steering
"{game_title}" MAME analog wheel setup

# Platform-specific
site:forum.arcadecontrols.com "{game_title}" wheel
site:forums.arcade-museum.com "{game_title}" steering
site:shmups.system11.org "{game_title}" wheel

# Manual searches
"{game_title}" operator manual PDF
"{game_title}" service manual steering

# Video evidence
"{game_title}" arcade cabinet tour
"{game_title}" original arcade gameplay
```

---

## Workflow for Autonomous Research Session

When starting a research session, Claude should:

1. **Setup Check**
   ```powershell
   .\scripts\Setup-Dependencies.ps1       # Download/copy MAME data files
   .\scripts\Get-MameGames.ps1            # Generate MAME inventory
   .\scripts\Get-TeknoparrotGames.ps1     # Generate TeknoParrot inventory
   ```

2. **Identify Research Targets**
   ```powershell
   # Load inventories
   $mame = Get-Content ./sources/cache/mame-games.json | ConvertFrom-Json
   $tp = Get-Content ./sources/cache/teknoparrot-games.json | ConvertFrom-Json

   # MAME: prioritize parent ROMs with wheel controls not yet in database
   $mamePending = $mame.games | Where-Object { -not $_.is_clone -and $_.input_types.Count -gt 0 -and -not $_.already_in_database }

   # TeknoParrot: games with wheel axis but no rotation data
   $tpPending = $tp.games | Where-Object { $_.has_wheel -and -not $_.in_database }
   ```

3. **Research Loop**
   - Group games by manufacturer/platform for batch research
   - For each game, perform web searches for rotation specs
   - Extract and validate rotation values against known manufacturer patterns
   - Document sources thoroughly with confidence levels
   - Update `data/wheel-rotation.json` directly (no intermediate merge step needed)

4. **Validate & Export**
   ```powershell
   .\scripts\Validate-Database.ps1        # Verify integrity
   .\scripts\Export-Formats.ps1           # Generate CSV/XML
   ```

5. **Commit Changes**
   - Stage updated data files
   - Write descriptive commit message listing games added
   - Note any games that couldn't be researched

---

## Known Wheel Rotation Values (Seed Data)

To bootstrap the database, here are some verified/commonly cited values:

| Game | Rotation | Type | Confidence | Notes |
|------|----------|------|------------|-------|
| Out Run | 270° | mechanical_stop | high | ±135° from center |
| Pole Position | -1 | optical_encoder | high | Infinite rotation spinner |
| Hard Drivin' | variable | potentiometer | medium | Calibration-dependent |
| Daytona USA | 270° | mechanical_stop | medium | Common Sega spec |
| Ridge Racer | 270° | mechanical_stop | medium | Namco standard |
| Cruis'n USA | 270° | mechanical_stop | medium | Midway standard |
| Virtua Racing | 270° | mechanical_stop | high | Sega Model 1 |
| Sega Rally | 270° | mechanical_stop | high | Sega Model 2 |
| F-Zero AX | 150° | mechanical_stop | medium | Triforce hardware, community-measured ~150° |

---

## Teknoparrot Integration

### Local Installation

A local TeknoParrot installation is available at:
```
R:\LaunchBox\Launchbox-Racing\LaunchBox\LaunchBox\Emulators\Coinops NEXT - TeknoParrot\emulators\TeknoParrot
```

### Data Sources in TeknoParrot

TeknoParrot has **two** relevant directories:

1. **`GameProfiles/*.xml`** (~487 files, ~98 with `<AnalogType>Wheel</AnalogType>`)
   - Defines axis mappings (which analog input is wheel, gas, brake)
   - Raw axis ranges (byte values like 0-255, not physical degrees)
   - Keyboard sensitivity sliders
   - Used to **identify which games have wheel controls** (inventory source)

2. **`Metadata/*.json`** (~485 files, **25 with `wheel_rotation` values**)
   - Contains `game_name`, `game_genre`, `platform`, `release_year`, `wheel_rotation`
   - **This is the primary source for rotation degree data**
   - All 25 games with rotation values are genre "Racing"
   - Two values observed: **270** (19 games) and **540** (6 games)

The remaining ~73 wheel-equipped games (from GameProfiles) that lack Metadata rotation values need research.

### Key Fields in GameProfiles XML

- `<EmulationProfile>` - Identifies the emulation backend (e.g., `SegaInitialD`, `Outrun2SPX`)
- `<EmulatorType>` - The emulation type (`TeknoParrot`, `Lindbergh`, `Dolphin`)
- Filename itself serves as the game identifier (e.g., `ID8.xml`, `WMMT6.xml`)
- `<AnalogType>Wheel</AnalogType>` in `<JoystickButtons>` indicates steering wheel input

### Metadata JSON Format

```json
{
  "game_name": "Initial D: Arcade Stage 8 Infinity",
  "game_genre": "Racing",
  "icon_name": "ID8.png",
  "platform": "SEGA RingEdge",
  "release_year": "2014",
  "wheel_rotation": "540"
}
```

### Known TeknoParrot Wheel Rotation Values (from Metadata)

| Profile | Game | Rotation | Platform | Year |
|---------|------|----------|----------|------|
| BattleGear4 | Battle Gear 4 | 540 | Taito Type X+ | 2005 |
| BattleGear4Tuned | Battle Gear 4 Tuned | 540 | Taito Type X+ | 2006 |
| ID4Exp / ID4Jap | Initial D: Arcade Stage 4 | 540 | SEGA Lindbergh Yellow | 2007 |
| ID5 | Initial D: Arcade Stage 5 | 540 | SEGA Lindbergh Yellow | 2009 |
| ID6 | Initial D: Arcade Stage 6 | 540 | SEGA RingEdge | 2011 |
| ID7 | Initial D: Arcade Stage 7 | 540 | SEGA RingEdge | 2012 |
| ID8 | Initial D: Arcade Stage 8 Infinity | 540 | SEGA RingEdge | 2014 |
| IDZ / IDZv2 (+TP variants) | Initial D: Arcade Stage Zero | 270 | SEGA Nu | 2017 |
| IDTA / IDTAS5 | Initial D: The Arcade | 270 | SEGA ALLS | 2021-2025 |
| or2spdlx | OutRun 2 SP SDX | 270 | SEGA Lindbergh Yellow | 2006 |
| SR3 | SEGA Rally 3 | 270 | SEGA Europa-R | 2008 |
| SWDC | Sega World Drivers Championship | 270 | SEGA ALLS | 2018 |
| WackyRaces | Wacky Races | 270 | Taito Type X2 | 2009 |
| WMMT3-6RR | Wangan Midnight Maximum Tune 3-6RR | 270 | Namco N2/ES3B | 2007-2021 |

Note: Initial D series switched from 540 to 270 starting with Arcade Stage Zero (2017).

### Script: Get-TeknoparrotGames.ps1

Parses the local TeknoParrot installation to extract all wheel-equipped games:
```powershell
param(
    [string]$TeknoParrotPath = "R:\LaunchBox\Launchbox-Racing\LaunchBox\LaunchBox\Emulators\Coinops NEXT - TeknoParrot\emulators\TeknoParrot",
    [string]$OutputPath = "./sources/cache/teknoparrot-games.json"
)

# For each XML in GameProfiles/:
#   1. Check if any JoystickButton has <AnalogType>Wheel</AnalogType>
#   2. Extract EmulationProfile, EmulatorType, filename
# For each matching game, load Metadata/{filename}.json:
#   3. Extract game_name, game_genre, platform, release_year, wheel_rotation
#   4. Output combined inventory list
```

### Notable Teknoparrot Racing Game Families

| Series | Profiles | Notes |
|--------|----------|-------|
| Initial D | ID4Exp, ID4Jap, ID5, ID6, ID7, ID8, IDZ, IDZv2, IDTA, IDTAS5 | Sega ring-edge hardware |
| Wangan Midnight MT | WMMT3, WMMT3DXP, WMMT5, WMMT5DX, WMMT5DXPlus, WMMT6, WMMT6R, WMMT6RR | Namco System ES series |
| Mario Kart GP | MarioKartGP, MarioKartGP2, MKDX (+variants) | Triforce/Namco BNA |
| Fast & Furious | FNF, FNFDrift, FNFSB, FNFSB2, FNFSC | Raw Thrills |
| Sega Rally | SR3, SRC, SRG | Sega Europa-R/Lindbergh |
| Daytona | Daytona3, Daytona3NSE | Sega RingEdge 2 |
| Battle Gear | batlgr3, batlgr3t, BattleGear4, BattleGear4Tuned | Taito Type X |
| OutRun 2 | or2spdlx | Sega Lindbergh |
| Cruis'n | CruisnBlast | Raw Thrills |

---

## Contributing

### Manual Contributions Welcome!

If you have verified information about a game's wheel rotation:

1. Fork the repository
2. Edit `data/wheel-rotation.json`
3. Add your entry with source documentation
4. Submit a pull request

### Entry Template

```json
"romname": {
  "title": "Game Title",
  "rotation_degrees": 270,
  "rotation_type": "mechanical_stop",
  "confidence": "verified",
  "sources": [
    {
      "type": "manual",
      "description": "Your source description",
      "url": "https://...",
      "date_accessed": "2025-01-31"
    }
  ],
  "notes": "Any additional context"
}
```

---

## License

This project should use a permissive license (MIT or CC0) to encourage:
- Integration into emulator frontends
- Community contributions
- Derivative works

---

## Contact & Community

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General questions and research coordination
- Pull Requests: Data contributions and corrections

---

## Appendix: Common Manufacturer Patterns

### Sega
- **Super Scaler games** (Out Run, Super Hang-On, etc.): 270° typical
- **Model 1/2/3**: 270° standard
- **Naomi/Chihiro**: 270° typical

### Namco
- **System 21/22**: 270° typical (Ridge Racer, Rave Racer)
- **System 246/256**: 270° typical

### Atari/Midway
- **Hard Drivin' series**: Potentiometer-based, variable
- **Cruis'n series**: 270° typical
- **San Francisco Rush**: 270° typical

### Taito
- **Chase H.Q. series**: 270° typical
- **Battle Gear series**: 270° typical

### Konami
- **GTI Club**: 270° typical
- **Winding Heat**: 270° typical

### Early Games (Pre-1985)
- Often used optical encoders (infinite rotation)
- Examples: Pole Position, Turbo, Monaco GP
- These map better to spinner/mouse input than modern wheel
