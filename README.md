# wheel-rotation-db

A community database of steering wheel rotation degrees for arcade racing/driving games. This metadata helps emulator users (MAME, TeknoParrot, etc.) configure their USB racing wheels to match the original arcade cabinet's wheel rotation for an authentic gameplay experience.

## Why This Exists

Modern USB racing wheels support 270-1080 degrees of rotation, but original arcade cabinets varied widely -- 270 degrees was common for arcade racers, some used 360 degrees, early games used infinite-rotation optical encoders, and motorcycle games used as little as 45 degrees. Without this data, players must guess or manually research each game.

## Database

The primary database is `data/wheel-rotation.json` -- a unified, game-centric JSON file where each entry represents a unique physical arcade game. Emulator-specific identifiers (MAME ROM names, TeknoParrot profiles, etc.) are stored as sub-entries so a game's rotation data is never duplicated across platforms.

### Current Stats (v1.2.0)

| Metric | Count |
|--------|-------|
| Total game entries | 129 |
| With MAME mapping | 49 |
| With TeknoParrot mapping | 81 |
| Confidence: verified | 17 |
| Confidence: high | 56 |
| Confidence: medium | 43 |
| Confidence: low | 13 |

**Rotation values:** 270 (79 games), 360 (26), 540 (9), 45 (8), 60 (3), 150 (2), 90 (1), infinite (1)

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
| `Export-Formats.ps1` | Not started | Generate CSV and XML exports from JSON master |
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

### Next Up

- [ ] **MAME research phase** -- ~167 parent MAME games with wheel/paddle/dial controls need rotation values. Many of the remaining ~812 catver-only "driving" games use joysticks, not wheels.
- [ ] **Cross-mapping** -- Link TeknoParrot-only entries to MAME ROM names where the same game exists in both
- [ ] **Validate-Database.ps1** -- Schema validation, duplicate detection, range checks
- [ ] **Export-Formats.ps1** -- CSV and XML exports for frontend/emulator integration
- [ ] **Other emulator mappings** -- Add Supermodel, Model 2 Emulator, Flycast, Dolphin identifiers to existing entries

### Future

- [ ] Community contributions via pull requests
- [ ] Integration guides for emulator frontends (LaunchBox, RetroArch, etc.)
- [ ] MAME ctrlr file generation for automatic wheel configuration
- [ ] Paddle/dial games research (Arkanoid, etc. -- different use case from steering wheels)

## Repository Structure

```
wheel-rotation-db/
  data/
    wheel-rotation.json          # Primary database (129 games)
    schema/
      wheel-rotation.schema.json # JSON Schema for validation
  scripts/
    Setup-Dependencies.ps1       # Download/copy data dependencies
    Get-MameGames.ps1            # MAME wheel game inventory
    Get-TeknoparrotGames.ps1     # TeknoParrot wheel game inventory
  sources/
    downloads/                   # catver.ini, controls.xml, etc. (gitignored)
    cache/                       # Generated inventories (gitignored)
  docs/                          # Future documentation
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
