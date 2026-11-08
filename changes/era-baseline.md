---
section: forge
---
- With Forever client tables loaded, `forge data build` no longer copies
  Classic Era zones or factions into `zones.json` or `factions.json`. Era
  `UiMap`, `UiMapAssignment` and `AreaTable` stay the pfQuest coordinate
  baseline (`map-frames.json` `era`). `forge data sources --only era --build
  1.15.9.70003` fetches that cache and not the `wow_classic_beta` tables.
