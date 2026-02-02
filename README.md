# wheel-rotation-db

A community database of steering wheel rotation degrees for arcade racing/driving games. This metadata helps emulator users (MAME, TeknoParrot, etc.) configure their USB racing wheels to match the original arcade cabinet's wheel rotation for an authentic gameplay experience.

## Why This Exists

Modern USB racing wheels support 270-1080 degrees of rotation, but original arcade cabinets varied widely -- 270 degrees was common for arcade racers, some used 360 degrees, early games used infinite-rotation optical encoders, and motorcycle games used as little as 45 degrees. Without this data, players must guess or manually research each game.

## Database

The primary database is `data/wheel-rotation.json` -- a unified, game-centric JSON file where each entry represents a unique physical arcade game. Emulator-specific identifiers (MAME ROM names, TeknoParrot profiles, etc.) are stored as sub-entries so a game's rotation data is never duplicated across platforms.

### Current Stats (v1.4.0)

| Metric | Count |
|--------|-------|
| Total game entries | 636 |
| With MAME mapping | 556 |
| With TeknoParrot mapping | 81 |
| With known rotation value | 182 |
| Unknown (needs research) | 454 |

**Known rotation values:** 270 (123 games), 360 (27), 540 (9), 45 (9), infinite (6), 60 (3), 1080 (2), 150 (2), 90 (1)

**Confidence levels (known entries):** verified (19), high (72), medium (72), low (28)

The 454 unknown entries are primarily catver.ini-classified driving/racing games where MAME does not list wheel/paddle/dial controls — most likely joystick-controlled. They are included so the community can identify and correct any that actually use steering wheels.

### Special Values

- **`-1`** = Infinite rotation (optical encoder / spinner, no physical stops)
- **`null`** = Unknown, needs research

## Scripts

All scripts are PowerShell 7+ and located in `scripts/`.

| Script | Status | Description |
|--------|--------|-------------|
| `Setup-Dependencies.ps1` | Done | Downloads catver.ini, controls.xml, nplayers.ini; generates MAME listxml from local MAME install |
| `Get-TeknoparrotGames.ps1` | Done | Scans local TeknoParrot installation for wheel-equipped games (98 found, 25 with rotation metadata) |
| `Get-MameGames.ps1` | Done | Parses catver.ini + MAME listxml + controls.xml to inventory all MAME racing/driving games (1,488 found) |
| `Export-Formats.ps1` | Done | Generates CSV and XML exports from JSON master into `dist/` |
| `Validate-Database.ps1` | Not started | Validate database against JSON schema |

## Dependencies

Run `Setup-Dependencies.ps1` to gather data files. It checks local LaunchBox installations first, then downloads from:

- **catver.ini** -- [progettosnaps.net](https://www.progettosnaps.net/catver/) or [GitHub mirror](https://github.com/AntoPISA/MAME_SupportFiles)
- **controls.xml** -- [GitHub (ControlsDat)](https://github.com/benbaker76/ControlsDat)
- **MAME listxml** -- Generated from a local MAME executable

All downloaded files go to `sources/downloads/` (gitignored).

## Roadmap

### Completed

- [x] Project structure, JSON schema, and seed data (9 games)
- [x] Unified game-centric data model (one entry per game, multi-emulator mappings)
- [x] TeknoParrot inventory script -- found 98 wheel games, extracted 25 rotation values from metadata
- [x] TeknoParrot research phase -- researched 72 games, added 64 new entries from web sources
- [x] MAME inventory script -- found 1,488 racing/driving games across catver.ini, MAME listxml, and controls.xml
- [x] Setup-Dependencies script -- automates gathering catver.ini, controls.xml, nplayers.ini, MAME listxml
- [x] Fixed controls.xml parsing (capitalized XML tags) and imported 40 verified rotation values
- [x] MAME research phase (batch 1) -- researched 65 driving/racing parent games across Sega, Namco, Taito, Atari, Midway, Konami, SNK, and others. Added 63 new entries with rotation values from service manuals, parts catalogs, emulator communities, and forum sources
- [x] MAME research phase (batch 2) -- triaged remaining 118 parent MAME games with paddle/dial controls. Only 1 was a real steering wheel game (Ace Driver: Victory Lap). The other 117 are paddle/breakout games (Arkanoid, Pong), spinners (Tempest, 720°), periscopes (Sea Wolf), music games (beatmania turntable), home computers (Atari 400/800), and other non-steering controls
- [x] Catver driving game import -- added 443 catver.ini driving/racing games as unknown entries (rotation null) so the community can identify any that actually use steering wheels. Excluded horse racing/gambling/plug-and-play categories
- [x] Export-Formats.ps1 -- generates MAME CSV and XML lookup files from the JSON database
- [x] GitHub Actions release workflow -- auto-creates versioned GitHub releases with JSON, CSV, and XML assets when the database version changes

### Next Up
- [ ] **Cross-mapping** -- Link TeknoParrot-only entries to MAME ROM names where the same game exists in both
- [ ] **Validate-Database.ps1** -- Schema validation, duplicate detection, range checks
- [ ] **Other emulator mappings** -- Add Supermodel, Model 2 Emulator, Flycast, Dolphin identifiers to existing entries

### Future

- [ ] Community contributions via pull requests
- [ ] Integration guides for emulator frontends (LaunchBox, RetroArch, etc.)
- [ ] Paddle/dial games research (Arkanoid, etc. -- different use case from steering wheels)

## Repository Structure

```
wheel-rotation-db/
  data/
    wheel-rotation.json          # Primary database (636 games)
    schema/
      wheel-rotation.schema.json # JSON Schema for validation
  scripts/
    Setup-Dependencies.ps1       # Download/copy data dependencies
    Get-MameGames.ps1            # MAME wheel game inventory
    Get-TeknoparrotGames.ps1     # TeknoParrot wheel game inventory
    Export-Formats.ps1           # Generate CSV/XML exports into dist/
  .github/
    workflows/
      release.yml                # Auto-release on database version change
  sources/
    downloads/                   # catver.ini, controls.xml, etc. (gitignored)
    cache/                       # Generated inventories (gitignored)
  dist/                          # Build artifacts (gitignored, attached to releases)
```

## Consuming the Data

Each [GitHub Release](../../releases) includes three artifacts:

| File | Format | Description |
|------|--------|-------------|
| `wheel-rotation.json` | JSON | Full database with all metadata, sources, and multi-emulator mappings |
| `mame-wheel-rotation.csv` | CSV | Flat MAME ROM-to-rotation lookup (games with known values only) |
| `mame-wheel-rotation.xml` | XML | Same MAME lookup data in XML format |

**Quick access** (latest release, once the repo is public):
```
https://github.com/{owner}/wheel-rotation-db/releases/latest/download/wheel-rotation.json
https://github.com/{owner}/wheel-rotation-db/releases/latest/download/mame-wheel-rotation.csv
https://github.com/{owner}/wheel-rotation-db/releases/latest/download/mame-wheel-rotation.xml
```

## Contributing

If you have verified information about an arcade game's wheel rotation:

1. Fork the repository
2. Edit `data/wheel-rotation.json`
3. Add your entry following the schema (see `data/schema/wheel-rotation.schema.json`)
4. Include at least one source documenting where the data came from
5. Submit a pull request

## License

[MIT](LICENSE)
